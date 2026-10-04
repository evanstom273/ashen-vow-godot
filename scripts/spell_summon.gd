class_name SpellSummon
extends CharacterBody2D
signal health_changed(value: int, maximum: int)
var definition: SummonDefinition
var context: SpellCastContext
var health: int
var max_health: int
var remaining: float
var cooldown: float = 0.0
var path_timer: float = 0.0
var route := PackedVector2Array()
var target: Node2D
var protection: float = 0.0
var spell_visual: Node2D

func configure(resource: SummonDefinition, cast_context: SpellCastContext, lifetime: float) -> void:
	definition = resource
	context = cast_context
	context.from_summon = true
	set_meta(&"elevation_level", context.elevation)
	remaining = lifetime
	max_health = definition.health
	health = max_health

func _ready() -> void:
	add_to_group("spell_ally")
	collision_layer = 4
	collision_mask = 1
	Elevation.register_body(self)
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	var collider := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 10
	collider.shape = shape
	add_child(collider)
	z_index = 1
	call_deferred("_start_visual")

func _visual_snapshot() -> Dictionary:
	return {"kind": &"summon", "origin": global_position, "direction": aim_direction(), "owner_id": context.attribution.get_instance_id(), "elevation": Elevation.level(self)}

func _start_visual() -> void:
	if not is_inside_tree() or is_queued_for_deletion(): return
	spell_visual = Feedback.spell_visual(context.profile, _visual_snapshot(), self)

func is_targetable() -> bool: return health > 0

func aim_direction() -> Vector2:
	return (target.global_position - global_position).normalized() if SpellDeliveryService.alive(target) else context.direction

func receive_hit(attack: AttackDefinition, stats: AttributeStats, source: Node) -> void:
	if not Elevation.accepts_hit(self, source, attack): return
	if health <= 0 or protection > 0: return
	var amount: int = attack.health_damage(stats, SpellEffects.defence(self, definition.defence))
	if amount > 0 and context != null and is_instance_valid(context.attribution) and context.attribution.has_method("note_combat_damage"):
		context.attribution.call("note_combat_damage", source)
	if health > amount: SpellEffects.apply_attack(self, attack, stats, source)
	if amount == 0 and attack.max_health_drain != null: return
	Feedback.damage_number(self, mini(amount, health))
	health = maxi(0, health - amount)
	if not attack.periodic_damage: protection = 0.15
	health_changed.emit(health, max_health)
	if amount > 0: Feedback.hit_effect(global_position, source, EnemyDefinition.HitSurface.METAL, attack, amount, self)
	if health <= 0:
		SpellDeliveryService.clear_owned(self)
		queue_free()

func _exit_tree() -> void:
	# Attached presentation is freed with the ally; detached projectiles retain attribution.
	if is_instance_valid(spell_visual): spell_visual.queue_free()
	for instance: Node in get_tree().get_nodes_in_group("spell_delivery"):
		if instance.get("context").caster == self: instance.call("cancel")

func _physics_process(delta: float) -> void:
	remaining -= delta
	protection = maxf(0, protection - delta)
	if remaining <= 0 or not SpellDeliveryService.alive(context.attribution):
		queue_free()
		return
	cooldown -= delta
	path_timer -= delta
	var original_target: Variant = context.attribution.get("locked_target")
	var acquisition: SpellCastContext = context.branch()
	acquisition.caster = self
	acquisition.elevation = Elevation.level(self)
	var choices: Array[Node2D] = SpellDeliveryService.targets(acquisition)
	choices.sort_custom(func(a: Node2D, b: Node2D) -> bool: return global_position.distance_squared_to(a.global_position) < global_position.distance_squared_to(b.global_position))
	target = null
	if SpellDeliveryService.alive(original_target) and Elevation.compatible(self, original_target) and global_position.distance_to(original_target.global_position) <= definition.acquisition_range:
		if not definition.mobile or not SpellNavigation.of(self).path(self, original_target.global_position).is_empty(): target = original_target
	if target == null:
		for actor: Node2D in choices:
			if global_position.distance_to(actor.global_position) <= definition.acquisition_range:
				if not definition.mobile or not SpellNavigation.of(self).path(self, actor.global_position).is_empty():
					target = actor
					break
	var destination: Vector2 = target.global_position if target != null else context.attribution.global_position
	var in_range: bool = target != null and global_position.distance_to(destination) <= definition.attack_range and SpellDeliveryService.visible(acquisition, global_position, destination)
	velocity = Vector2.ZERO
	if definition.mobile and (target != null or Elevation.compatible(self, context.attribution)) and not in_range and global_position.distance_to(destination) > (WorldScale.art_distance(10.0) if target != null else definition.follow_distance):
		if path_timer <= 0:
			route = SpellNavigation.of(self).path(self, destination)
			path_timer = 0.5
		while not route.is_empty() and global_position.distance_to(route[0]) < WorldScale.art_distance(10): route.remove_at(0)
		if not route.is_empty(): velocity = (route[0] - global_position).normalized() * definition.speed * SpellEffects.movement(self)
	Elevation.slide(self, delta)
	if in_range and cooldown <= 0 and acquisition.elevation == Elevation.level(self) and SpellDeliveryService.on_plane(acquisition, target):
		acquisition.target = target
		acquisition.origin = global_position
		acquisition.point = target.global_position
		acquisition.direction = aim_direction()
		acquisition.ownership = &"summon_attack"
		SpellDeliveryService.launch(definition.delivery, acquisition)
		cooldown = definition.attack_interval
	if is_instance_valid(spell_visual) and spell_visual.has_method("update_visual"):
		spell_visual.call("update_visual", _visual_snapshot())
	queue_redraw()

func on_elevation_changed(_previous: int, _current: int) -> void:
	route.clear()
	path_timer = 0.0
	target = null

func _draw() -> void:
	if not is_instance_valid(spell_visual):
		draw_colored_polygon(PackedVector2Array([Vector2(0, -26), Vector2(13, -5), Vector2(9, 8), Vector2(-9, 8), Vector2(-13, -5)]), Color(0.45, 0.75, 0.85, 0.8))
		draw_circle(Vector2(0, -13), 4, Color("e5fcff"))
	draw_line(Vector2(-12, 13), Vector2(-12 + 24.0 * health / maxi(1, max_health), 13), Color("95ddb4"), 2)
