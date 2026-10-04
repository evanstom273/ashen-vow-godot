@tool
extends CharacterBody2D
signal health_changed(value: int, maximum: int)
signal died
enum State { IDLE, APPROACH, WINDUP, STRIKE, RECOVERY, HURT, DEAD }
@export var definition: EnemyDefinition = preload("res://data/enemies/court_sentinel.tres")
## Placement-level label; never mutate the shared EnemyDefinition to rename a guard.
@export var display_name_override: String = ""
## Zero derives authored AI/melee distances from the actor's actual world scale.
## A positive value is an explicit override for unusually proportioned enemies.
@export var world_spatial_scale: float = 0.0
var spatial_scale: float:
	get: return world_spatial_scale if world_spatial_scale > 0.0 else WorldScale.actor_scale(self)
@export var use_world_navigation: bool = false
var navigation_cooldown: float = 0.0
var navigation_route := PackedVector2Array()
## Accepted damage provokes pursuit independently of passive detection/leash range.
## Store identity, not a strong object reference that can outlive the attacker.
var _provoked_by_id: int = 0
var attributes: AttributeStats
var vitals: VitalStats
var equipped_weapon: WeaponDefinition
var max_health: int = 4
var poise_remaining: float = 1.0
var _poise_delay: float = 0.0
var _protection: float = 0.0
var _recoil_speed: float = 100.0
var attack: AttackDefinition:
	get: return equipped_weapon.light_attack
var approach_speed: float:
	get: return definition.approach_speed * spatial_scale
var detection_radius: float:
	get: return definition.detection_radius * spatial_scale
var health: int = 4
var state: State = State.IDLE
var clock: float = 0.0
var phase: float = 0.0
var direction := Vector2.DOWN
var home := Vector2.ZERO
var home_elevation: int = 0
var locked: bool = false
var flash: float = 0.0
var hit_stop: float = 0.0
var struck: bool = false
var player: PlayerController
var art: Node2D
var flash_material: ShaderMaterial
var melee_ribbon: MeleeTrail
var windup_glint: PhysicalVFX

func _clear_strike(victim: Node2D) -> bool:
	if not Elevation.compatible(self, victim): return false
	if not use_world_navigation: return true
	var query := PhysicsRayQueryParameters2D.create(global_position, victim.global_position, 1)
	var excluded: Array[RID] = [get_rid()]
	if victim is CollisionObject2D: excluded.append(victim.get_rid())
	query.exclude = excluded
	return Elevation.ray(self, query, Elevation.level(self)).is_empty()

func _ready() -> void:
	if definition == null: definition = load("res://data/enemies/court_sentinel.tres")
	equipped_weapon = definition.weapon
	if equipped_weapon == null or equipped_weapon.light_attack == null:
		equipped_weapon = load("res://data/weapons/sentinel_blade.tres")
	attributes = definition.attributes.duplicate(true) as AttributeStats if definition.attributes != null else AttributeStats.new()
	if not Engine.is_editor_hint():
		melee_ribbon = MeleeTrail.new()
		melee_ribbon.set_meta("fx_owner", get_instance_id())
		add_child(melee_ribbon)
	vitals = definition.vitals if definition.vitals != null else VitalStats.new()
	max_health = vitals.max_health(attributes)
	health = max_health
	poise_remaining = vitals.poise
	add_to_group("targetable")
	add_to_group("enemy")
	add_to_group("sentinel")
	collision_layer = 2
	collision_mask = 1
	if not Engine.is_editor_hint(): Elevation.register_body(self)
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	home = position
	home_elevation = Elevation.level(self)
	if not Engine.is_editor_hint(): player = get_tree().get_first_node_in_group("player")
	else: set_physics_process(false)
	var collider := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 15
	collider.shape = circle
	add_child(collider)
	art = Node2D.new()
	add_child(art)
	flash_material = ShaderMaterial.new()
	flash_material.shader = load("res://shaders/flash.gdshader")
	art.material = flash_material
	_poly([Vector2(-15,0), Vector2(-18,-22), Vector2(-10,-37), Vector2(12,-37), Vector2(21,-19), Vector2(15,5)], Color("414b50"))
	_poly([Vector2(-13,-29), Vector2(-17,-17), Vector2(0,-12), Vector2(18,-19), Vector2(11,-30)], Color("69716b"))
	_poly([Vector2(-10,-38), Vector2(-8,-51), Vector2(8,-51), Vector2(12,-39), Vector2(6,-30), Vector2(-7,-30)], Color("899084"))
	_poly([Vector2(-7,-40), Vector2(8,-40), Vector2(7,-37), Vector2(-6,-37)], Color("e6b66e"))
	_poly([Vector2(-13,0), Vector2(-3,0), Vector2(-3,12), Vector2(-16,12)], Color("262e33"))
	_poly([Vector2(4,0), Vector2(14,0), Vector2(17,12), Vector2(4,12)], Color("262e33"))

func _poly(points: Array, color: Color) -> void:
	var polygon := Polygon2D.new()
	polygon.polygon = PackedVector2Array(points)
	polygon.color = color
	polygon.use_parent_material = true
	art.add_child(polygon)

func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint(): return
	if not is_instance_valid(player):
		_clear_provocation()
		velocity = Vector2.ZERO
		return
	_protection = maxf(0, _protection - delta)
	_poise_delay = maxf(0, _poise_delay - delta)
	if _poise_delay <= 0: poise_remaining = minf(vitals.poise, poise_remaining + vitals.poise_regeneration * delta)
	phase += delta
	flash = move_toward(flash, 0, delta * 7)
	flash_material.set_shader_parameter("flash", flash)
	if hit_stop > 0:
		hit_stop -= delta
		return
	clock += delta
	navigation_cooldown -= delta
	var provoker: Node2D = _provoked_attacker()
	var victim: Node2D = provoker
	if victim == null:
		victim = player if player.health > 0 and Elevation.compatible(self, player) else null
		for ally: Node in get_tree().get_nodes_in_group("spell_ally"):
			if SpellDeliveryService.alive(ally) and Elevation.compatible(self, ally) and (victim == null or global_position.distance_to(ally.global_position) < global_position.distance_to(victim.global_position)):
				victim = ally
	if player.health <= 0 and state != State.DEAD:
		_clear_provocation()
		provoker = null
		victim = null
		_state(State.IDLE)
	var offset: Vector2 = victim.global_position - global_position if victim != null else Vector2.ZERO
	var distance: float = offset.length() if victim != null else INF
	velocity = Vector2.ZERO
	if victim == null and state not in [State.IDLE, State.HURT, State.DEAD]:
		navigation_route.clear()
		_state(State.IDLE)
	match state:
		State.IDLE:
			if (provoker != null or distance < detection_radius) and player.health > 0: _state(State.APPROACH)
		State.APPROACH:
			direction = offset.normalized()
			velocity = direction * approach_speed
			if use_world_navigation:
				if navigation_cooldown <= 0:
					navigation_route = SpellNavigation.of(self).path(self, victim.global_position, provoker != null)
					navigation_cooldown = 0.6
				while not navigation_route.is_empty() and global_position.distance_to(navigation_route[0]) < 48: navigation_route.remove_at(0)
				velocity = (navigation_route[0]-global_position).normalized()*approach_speed if not navigation_route.is_empty() else Vector2.ZERO
			if distance < definition.attack_distance * spatial_scale and _clear_strike(victim):
				_state(State.WINDUP)
				Feedback.play(String(definition.windup_sound), global_position)
			elif provoker == null and distance > definition.disengage_radius * spatial_scale: _state(State.IDLE)
		State.WINDUP:
			direction = offset.normalized()
			if clock >= attack.windup:
				_state(State.STRIKE)
				struck = false
				Feedback.play(String(attack.swing_sound), global_position, 2)
		State.STRIKE:
			velocity = direction * attack.lunge_speed * spatial_scale
			if not struck and distance < attack.reach * spatial_scale and _clear_strike(victim) and direction.dot(offset.normalized()) > cos(deg_to_rad(attack.arc_degrees * 0.5)):
				struck = true
				victim.receive_hit(attack, attributes, self)
			if clock >= attack.active:
				_state(State.RECOVERY)
				Feedback.burst(global_position + direction * 50 * spatial_scale, "dust", direction, null, get_instance_id())
				player.shake = maxf(player.shake, 1.5 if distance < 160 * spatial_scale else 0.0)
		State.RECOVERY:
			if clock >= attack.recovery: _state(State.APPROACH)
		State.HURT:
			velocity = -direction * maxf(0, _recoil_speed * (1 - clock / vitals.stagger_duration))
			if clock >= vitals.stagger_duration: _state(State.APPROACH)
		State.DEAD:
			art.rotation = lerp_angle(art.rotation, 1.5, delta * 8)
			art.modulate.a = 0.5
			if definition.auto_restore_delay > 0 and clock >= definition.auto_restore_delay:
				reset_encounter()
	velocity *= SpellEffects.movement(self)
	Elevation.slide(self, delta)
	if state != State.DEAD:
		art.position.y = -absf(sin(phase * 8)) * (1.5 if state == State.APPROACH else 0.3)
		art.rotation = lerp_angle(art.rotation, -0.12 if state == State.WINDUP else (0.16 if state == State.RECOVERY else 0.0), delta * 10)
	var blade_angle: float = direction.angle() - (0.9 if state == State.WINDUP else 0.0)
	if state == State.STRIKE: blade_angle += lerpf(-0.9, 0.9, clampf(clock / attack.active, 0, 1))
	var grip: Vector2 = to_global(Vector2(9, -14))
	var tip: Vector2 = to_global(Vector2(9, -14) + Vector2.RIGHT.rotated(blade_angle) * attack.reach * 0.58)
	if state == State.STRIKE and is_instance_valid(melee_ribbon):
		melee_ribbon.sample(grip, tip, attack.melee_vfx)
	if is_instance_valid(windup_glint): windup_glint.global_position = tip
	queue_redraw()

func _draw() -> void:
	if equipped_weapon == null or equipped_weapon.light_attack == null: return
	draw_set_transform(Vector2(0, 9), 0, Vector2(1, 0.35))
	draw_circle(Vector2.ZERO, 24, Color(0.015,0.02,0.025,0.5))
	draw_set_transform(Vector2.ZERO)
	if locked and health > 0:
		draw_arc(Vector2.ZERO, 25 + sin(phase * 3), 0, TAU, 40, Color("edd09a"), 1.4, true)
		draw_circle(Vector2(0,-63), 3, Color("edd09a"))
	if state == State.WINDUP:
		var p: float = clampf(clock / attack.windup, 0, 1)
		draw_arc(Vector2.ZERO, attack.reach, direction.angle()-deg_to_rad(attack.arc_degrees*0.5), direction.angle()+deg_to_rad(attack.arc_degrees*0.5), 24, Color(1,0.45,0.23,0.25+p*0.5), 2+p*2, true)
	if state != State.DEAD:
		var angle: float = direction.angle() - (0.9 if state == State.WINDUP else 0.0)
		if state == State.STRIKE: angle += lerpf(-0.9,0.9,clampf(clock/attack.active,0,1))
		draw_line(Vector2(9,-14), Vector2(9,-14) + Vector2.RIGHT.rotated(angle)*attack.reach*0.58, equipped_weapon.blade_color, 5, true)
		if state == State.STRIKE and attack.melee_vfx == null: draw_arc(Vector2.ZERO, attack.reach*0.73, angle-0.5, angle, 15, attack.slash_color, 4, true)

func _state(next: State) -> void:
	if next == State.DEAD: _clear_provocation()
	if is_instance_valid(windup_glint): windup_glint.queue_free()
	windup_glint = null
	if next in [State.HURT, State.DEAD, State.IDLE] and is_instance_valid(melee_ribbon): melee_ribbon.clear()
	state = next
	clock = 0
	if next == State.WINDUP and definition.windup_vfx != null:
		windup_glint = Feedback.physical_effect(global_position, definition.windup_vfx, &"glint", Vector2.UP, 1, self, true)

func _alert_to_attacker(source: Node) -> void:
	if not is_instance_valid(source) or not source is Node2D: return
	if not source.is_in_group("player") and not source.is_in_group("spell_ally"): return
	if not SpellDeliveryService.alive(source) or source.is_queued_for_deletion(): return
	if not Elevation.compatible(self, source): return
	if _provoked_by_id != source.get_instance_id():
		_provoked_by_id = source.get_instance_id()
		navigation_route.clear()
		navigation_cooldown = 0.0
	# Damage need not break poise to alert an idle enemy. Do not cancel an attack,
	# recovery or stagger already in progress, including repeated damage-over-time.
	if state == State.IDLE: _state(State.APPROACH)

func _provoked_attacker() -> Node2D:
	if _provoked_by_id == 0: return null
	var candidate: Object = instance_from_id(_provoked_by_id)
	if not is_instance_valid(candidate) or not candidate is Node2D:
		_clear_provocation()
		return null
	var actor := candidate as Node2D
	if not SpellDeliveryService.alive(actor) or actor.is_queued_for_deletion() or not Elevation.compatible(self, actor):
		_clear_provocation()
		return null
	return actor

func _clear_provocation() -> void:
	_provoked_by_id = 0
	navigation_route.clear()
	navigation_cooldown = 0.0

func is_targetable() -> bool: return health > 0
func get_target_point() -> Vector2: return global_position
func set_lock_on(value: bool) -> void: locked = value
func in_combat() -> bool: return state not in [State.IDLE, State.DEAD]
func is_engaged_with(actor: Node) -> bool:
	# This enemy's AI pursues its player or that player's allied summons.
	return is_instance_valid(player) and player == actor and Elevation.compatible(self, actor) and health > 0 and in_combat()

func get_display_name() -> String: return display_name_override if not display_name_override.is_empty() else definition.display_name

func receive_hit(incoming: AttackDefinition, attacker_stats: AttributeStats, source: Node) -> void:
	_apply_damage(incoming.health_damage(attacker_stats, SpellEffects.defence(self, vitals.defence)), source, incoming.poise_damage, incoming.knockback, incoming.hit_stop, incoming, attacker_stats)

func take_damage(amount: int, source: Node) -> void:
	_apply_damage(maxi(0, amount), source, vitals.poise, 180.0, 0.04)

func _apply_damage(amount: int, source: Node, poise_damage: float, knockback: float, freeze: float, incoming: AttackDefinition = null, attacker_stats: AttributeStats = null) -> void:
	if not Elevation.accepts_hit(self, source, incoming): return
	if health <= 0 or _protection > 0: return
	if amount > 0 and is_instance_valid(source) and source.has_method("note_combat_damage"):
		source.call("note_combat_damage", self)
	if health > amount: SpellEffects.apply_attack(self, incoming, attacker_stats, source)
	if amount == 0 and incoming != null and incoming.max_health_drain != null: return
	if incoming != null and incoming.feedback != null and not incoming.recurring_feedback: freeze = incoming.feedback.hit_stop
	Feedback.damage_number(self, mini(amount, health))
	if amount > 0: Feedback.hit_effect(global_position, source, definition.hit_surface, incoming, amount, self)
	if incoming == null or not incoming.periodic_damage: _protection = vitals.damage_invulnerability
	poise_remaining -= poise_damage
	_poise_delay = vitals.poise_regeneration_delay
	health = maxi(0, health - amount)
	if incoming == null or not incoming.periodic_damage:
		flash = 1
		hit_stop = freeze
		Feedback.play(String(definition.hit_sound), global_position)
	health_changed.emit(health, max_health)
	if health == 0:
		_state(State.DEAD)
		locked = false
		call_deferred("_disable_corpse_collision")
		_deliver_currency()
		Feedback.burst(global_position, "death", Vector2.UP, null, get_instance_id())
		Feedback.play("death", global_position)
		died.emit()

	else:
		if amount > 0: _alert_to_attacker(source)
		if poise_remaining <= 0:
			poise_remaining = vitals.poise
			if state == State.STRIKE and attack.uninterruptible_while_active: return
			_recoil_speed = definition.stagger_recoil_speed * spatial_scale * knockback / 180.0
			if is_instance_valid(source) and source is Node2D:
				direction = (source.global_position - global_position).normalized()
			_state(State.HURT)

func _deliver_currency() -> void:
	if not definition.drop_currency_on_death or definition.currency_drop == null: return
	var amount: int = definition.currency_drop.roll_amount()
	if amount <= 0: return
	if definition.currency_drop.delivery_mode == CurrencyDropDefinition.DeliveryMode.IMMEDIATE:
		if is_instance_valid(player): player.add_currency(amount, "+" + str(amount) + " " + definition.currency_drop.display_name)
		return
	var drop: Node2D = load("res://scenes/currency_drop.tscn").instantiate()
	drop.amount = amount
	drop.definition = definition.currency_drop
	drop.set_meta(&"elevation_level", Elevation.level(self))
	WorldScale.attach_art(drop, get_parent(), global_position, 1.0)

func _disable_corpse_collision() -> void:
	if health <= 0: Elevation.set_masks(self, 0, 1)

func on_elevation_changed(_previous: int, _current: int) -> void:
	_clear_provocation()
	if state != State.DEAD: _state(State.IDLE)

func reset_encounter() -> void:
	_clear_provocation()
	SpellEffects.of(self).clear()
	position = home
	Elevation.set_level(self, home_elevation)
	health = max_health
	poise_remaining = vitals.poise
	_poise_delay = 0.0
	_protection = 0.0
	hit_stop = 0.0
	art.rotation = 0
	art.modulate = Color.WHITE
	Elevation.set_masks(self, 2, 1)
	locked = false
	_state(State.IDLE)
