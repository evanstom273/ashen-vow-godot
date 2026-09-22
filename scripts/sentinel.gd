@tool
extends CharacterBody2D
signal health_changed(value: int, maximum: int)
signal died
enum State { IDLE, APPROACH, WINDUP, STRIKE, RECOVERY, HURT, DEAD }
@export var definition: EnemyDefinition = preload("res://data/enemies/court_sentinel.tres")
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
    get: return definition.approach_speed
var detection_radius: float:
    get: return definition.detection_radius
var health: int = 4
var state: State = State.IDLE
var clock: float = 0.0
var phase: float = 0.0
var direction := Vector2.DOWN
var home := Vector2.ZERO
var locked: bool = false
var flash: float = 0.0
var hit_stop: float = 0.0
var struck: bool = false
var player: PlayerController
var art: Node2D
var flash_material: ShaderMaterial

func _ready() -> void:
    if definition == null: definition = load("res://data/enemies/court_sentinel.tres")
    equipped_weapon = definition.weapon
    if equipped_weapon == null or equipped_weapon.light_attack == null:
        equipped_weapon = load("res://data/weapons/sentinel_blade.tres")
    attributes = definition.attributes.duplicate(true) as AttributeStats if definition.attributes != null else AttributeStats.new()
    vitals = definition.vitals if definition.vitals != null else VitalStats.new()
    max_health = vitals.max_health(attributes)
    health = max_health
    poise_remaining = vitals.poise
    add_to_group("targetable")
    add_to_group("enemy")
    add_to_group("sentinel")
    collision_layer = 2
    collision_mask = 1
    motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
    home = position
    player = get_tree().get_first_node_in_group("player")
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
    if not is_instance_valid(player): return
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
    var offset: Vector2 = player.global_position - global_position
    var distance: float = offset.length()
    velocity = Vector2.ZERO
    if player.health <= 0 and state != State.DEAD: _state(State.IDLE)
    match state:
        State.IDLE:
            if distance < detection_radius and player.health > 0: _state(State.APPROACH)
        State.APPROACH:
            direction = offset.normalized()
            velocity = direction * approach_speed
            if distance < definition.attack_distance:
                _state(State.WINDUP)
                Feedback.play(String(definition.windup_sound), global_position)
            elif distance > definition.disengage_radius: _state(State.IDLE)
        State.WINDUP:
            direction = offset.normalized()
            if clock >= attack.windup:
                _state(State.STRIKE)
                struck = false
                Feedback.play(String(attack.swing_sound), global_position, 2)
        State.STRIKE:
            velocity = direction * attack.lunge_speed
            if not struck and distance < attack.reach and direction.dot(offset.normalized()) > cos(deg_to_rad(attack.arc_degrees * 0.5)):
                struck = true
                player.receive_hit(attack, attributes, self)
            if clock >= attack.active:
                _state(State.RECOVERY)
                Feedback.burst(global_position + direction * 50, "dust", direction)
                player.shake = maxf(player.shake, 1.5 if distance < 160 else 0.0)
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
    move_and_slide()
    if state != State.DEAD:
        art.position.y = -absf(sin(phase * 8)) * (1.5 if state == State.APPROACH else 0.3)
        art.rotation = lerp_angle(art.rotation, -0.12 if state == State.WINDUP else (0.16 if state == State.RECOVERY else 0.0), delta * 10)
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
        if state == State.STRIKE: draw_arc(Vector2.ZERO, attack.reach*0.73, angle-0.5, angle, 15, attack.slash_color, 4, true)

func _state(next: State) -> void:
    state = next
    clock = 0

func is_targetable() -> bool: return health > 0
func get_target_point() -> Vector2: return global_position
func set_lock_on(value: bool) -> void: locked = value
func in_combat() -> bool: return state not in [State.IDLE, State.DEAD]

func get_display_name() -> String: return definition.display_name

func receive_hit(incoming: AttackDefinition, attacker_stats: AttributeStats, source: Node) -> void:
    _apply_damage(incoming.health_damage(attacker_stats, vitals.defence), source, incoming.poise_damage, incoming.knockback, incoming.hit_stop)

func take_damage(amount: int, source: Node) -> void:
    _apply_damage(maxi(0, amount), source, vitals.poise, 180.0, 0.04)

func _apply_damage(amount: int, source: Node, poise_damage: float, knockback: float, freeze: float) -> void:
    if health <= 0 or _protection > 0: return
    _protection = vitals.damage_invulnerability
    poise_remaining -= poise_damage
    _poise_delay = vitals.poise_regeneration_delay
    health = maxi(0, health - amount)
    flash = 1
    hit_stop = freeze
    Feedback.play(String(definition.hit_sound), global_position)
    health_changed.emit(health, max_health)
    if health == 0:
        _state(State.DEAD)
        locked = false
        set_deferred("collision_layer", 0)
        _deliver_currency()
        Feedback.burst(global_position, "dust")
        Feedback.play("death", global_position)
        died.emit()

    else:
        if poise_remaining <= 0:
            poise_remaining = vitals.poise
            if state == State.STRIKE and attack.uninterruptible_while_active: return
            _recoil_speed = definition.stagger_recoil_speed * knockback / 180.0
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
    drop.position = global_position
    drop.amount = amount
    drop.definition = definition.currency_drop
    get_parent().add_child(drop)

func reset_encounter() -> void:
    position = home
    health = max_health
    poise_remaining = vitals.poise
    _poise_delay = 0.0
    _protection = 0.0
    hit_stop = 0.0
    art.rotation = 0
    art.modulate = Color.WHITE
    collision_layer = 2
    locked = false
    _state(State.IDLE)
