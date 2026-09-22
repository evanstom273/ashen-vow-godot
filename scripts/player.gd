class_name PlayerController
extends CharacterBody2D

signal health_changed(value: int, maximum: int)
signal stamina_changed(value: float)
signal damaged
signal died
signal target_changed(target: Node2D)
signal interaction_changed(prompt: String)
enum PlayerState { NORMAL, ATTACKING, DODGING, HURT, DEAD }
@export_group("Definitions")
@export var character_class: ClassDefinition = preload("res://data/classes/ashen_wanderer.tres")
## Leave empty to use the class starting weapon.
@export var weapon_override: WeaponDefinition
var attributes: AttributeStats
var vitals: VitalStats
var movement: MovementDefinition
var equipped_weapon: WeaponDefinition
var max_health: int = 5
var max_stamina: float = 100.0
var max_focus: float = 50.0
var max_equip_load: float = 40.0
var focus: float = 50.0
var poise_remaining: float = 1.0
var _poise_delay: float = 0.0
var attack: AttackDefinition:
    get: return equipped_weapon.light_attack
var speed: float:
    get: return movement.walk_speed
var sprint_multiplier: float:
    get: return movement.sprint_multiplier
var dodge_duration: float:
    get: return movement.dodge_duration
var dodge_distance: float:
    get: return movement.dodge_distance
var dodge_cooldown: float:
    get: return movement.dodge_cooldown
var attack_duration: float:
    get: return attack.duration()
var attack_damage: int:
    get: return attack.health_damage(attributes)
var lock_on_radius: float:
    get: return movement.lock_on_radius
var interaction_radius: float:
    get: return movement.interaction_radius
var attack_cost: float:
    get: return attack.stamina_cost
var dodge_cost: float:
    get: return movement.dodge_cost
@onready var rig: Node2D = $Rig
@onready var camera: Camera2D = $Camera2D
var visuals: Node2D
var state: PlayerState = PlayerState.NORMAL
var health: int = 5
var stamina: float = 100.0
var facing: float = 1.0
var aim := Vector2.RIGHT
var dodge_direction := Vector2.RIGHT
var action_time: float = 0.0
var sprinting: bool = false
var locked_target: Node2D
var travel: float = 0.0
var hit_stop: float = 0.0
var shake: float = 0.0
var _cooldown: float = 0.0
var _protection: float = 0.0
var _regen_delay: float = 0.0
var _right_held: bool = false
var _hold_time: float = 0.0
var _buffer: String = ""
var _buffer_time: float = 0.0
var _hits: Dictionary = {}
var _camera_bias := Vector2.ZERO
var _denied_timer: float = 0.0
var message: String = ""
var message_time: float = 0.0
var _step_distance: float = 0.0
var _sprint_exhausted: bool = false
var _roll_trail_time: float = 0.0

func _ready() -> void:
    add_to_group("player")
    apply_definitions()
    collision_layer = 1
    collision_mask = 3
    motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
    z_index = 0
    $HUD.queue_free()
    $AttackPivot.queue_free()
    visuals = Node2D.new()
    visuals.set_script(load("res://scripts/player_visuals.gd"))
    add_child(visuals)
    camera.enabled = true
    camera.limit_left = -820
    camera.limit_right = 820
    camera.limit_top = -520
    camera.limit_bottom = 520

## Rebuild derived stats on spawn or after an explicit equipment/attribute change.
func apply_definitions() -> void:
    if character_class == null: character_class = load("res://data/classes/ashen_wanderer.tres")
    attributes = character_class.attributes.duplicate(true) as AttributeStats if character_class.attributes != null else AttributeStats.new()
    vitals = character_class.vitals if character_class.vitals != null else VitalStats.new()
    movement = character_class.movement if character_class.movement != null else MovementDefinition.new()
    equipped_weapon = weapon_override if weapon_override != null else character_class.starting_weapon
    if equipped_weapon == null or equipped_weapon.light_attack == null:
        equipped_weapon = load("res://data/weapons/wanderer_sword.tres")
    max_health = vitals.max_health(attributes)
    max_stamina = vitals.max_stamina(attributes)
    max_focus = vitals.max_focus(attributes)
    max_equip_load = vitals.max_load(attributes)
    health = max_health
    stamina = max_stamina
    focus = max_focus
    poise_remaining = vitals.poise

func get_display_name() -> String: return character_class.display_name

func _notification(what: int) -> void:
    if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
        _right_held = false
        _hold_time = 0.0
        _buffer = ""

func _unhandled_input(event: InputEvent) -> void:
    if state == PlayerState.DEAD: return
    if event.is_action_pressed("attack"): request_action("attack")
    if event.is_action_pressed("right_action"):
        _right_held = true
        _hold_time = 0.0
        _sprint_exhausted = false
    if event.is_action_released("right_action"):
        if _right_held and _hold_time < movement.sprint_hold_threshold: request_action("dodge")
        _right_held = false
    if event.is_action_pressed("lock_on"): toggle_lock()
    if event.is_action_pressed("target_next"): cycle_target(1)
    if event.is_action_pressed("target_previous"): cycle_target(-1)
    if event.is_action_pressed("interact"): interact_nearby()

func movement_input() -> Vector2:
    return Input.get_vector("move_left", "move_right", "move_up", "move_down")

func aim_direction() -> Vector2:
    var point: Vector2 = get_global_mouse_position()
    if valid_target(locked_target): point = target_point(locked_target)
    var vector: Vector2 = point - global_position
    return vector.normalized() if vector.length() > 4.0 else Vector2(facing, 0)

func request_action(action: String) -> void:
    if state == PlayerState.DEAD: return
    if state != PlayerState.NORMAL:
        var duration: float = dodge_duration if state == PlayerState.DODGING else attack_duration
        if state in [PlayerState.ATTACKING, PlayerState.DODGING] and duration - action_time <= movement.input_buffer:
            _buffer = action
            _buffer_time = movement.input_buffer
        return
    if action == "dodge" and _cooldown > 0.0: return
    if action == "attack" and not attributes.meets(equipped_weapon.requirements):
        show_message("Weapon requirements not met")
        return
    var cost: float = dodge_cost if action == "dodge" else attack_cost
    if action == "attack" and focus < attack.focus_cost:
        show_message("Not enough focus")
        return
    if stamina < cost:
        if _denied_timer <= 0.0:
            show_message("Catch your breath", 0.7)
            _denied_timer = 0.7
        return
    stamina -= cost
    if action == "attack": focus -= attack.focus_cost
    _regen_delay = vitals.stamina_regeneration_delay
    action_time = 0.0
    sprinting = false
    aim = aim_direction()
    if absf(aim.x) > 0.05: facing = signf(aim.x)
    if action == "dodge":
        state = PlayerState.DODGING
        dodge_direction = movement_input()
        if dodge_direction.is_zero_approx(): dodge_direction = aim
        _cooldown = dodge_cooldown
        _roll_trail_time = 0.0
        Feedback.burst(global_position + Vector2(0, 10), "dust", -dodge_direction)
        Feedback.play("roll", global_position)
        visuals.begin("roll")
    else:
        state = PlayerState.ATTACKING
        aim = Vector2.RIGHT.rotated(snappedf(aim.angle(), PI / 4.0))
        _hits.clear()
        Feedback.play(String(attack.swing_sound), global_position)
        visuals.begin("attack")

func _physics_process(delta: float) -> void:
    _poise_delay = maxf(0, _poise_delay - delta)
    if _poise_delay <= 0: poise_remaining = minf(vitals.poise, poise_remaining + vitals.poise_regeneration * delta)
    _cooldown = maxf(0, _cooldown - delta)
    _protection = maxf(0, _protection - delta)
    _denied_timer = maxf(0, _denied_timer - delta)
    message_time = maxf(0, message_time - delta)
    if is_instance_valid(locked_target) and not valid_target(locked_target): set_target(null)
    if not is_instance_valid(locked_target): locked_target = null
    if _right_held: _hold_time += delta
    _update_camera(delta)
    if hit_stop > 0:
        hit_stop -= delta
        return
    _buffer_time = maxf(0, _buffer_time - delta)
    if _buffer_time == 0: _buffer = ""
    _regen_delay = maxf(0, _regen_delay - delta)
    var previous: Vector2 = global_position
    action_time += delta
    match state:
        PlayerState.NORMAL:
            var move: Vector2 = movement_input()
            sprinting = _right_held and _hold_time >= movement.sprint_hold_threshold and not move.is_zero_approx() and not _sprint_exhausted
            if sprinting:
                stamina = maxf(0, stamina - movement.sprint_stamina_per_second * delta)
                _regen_delay = vitals.stamina_regeneration_delay
                if stamina <= 0:
                    _sprint_exhausted = true
                    sprinting = false
            velocity = move * speed * (sprint_multiplier if sprinting else 1.0)
            var look: Vector2 = aim_direction()
            if absf(look.x) > 0.04: facing = signf(look.x)
            move_and_slide()
            if _regen_delay <= 0 and not sprinting: stamina = minf(max_stamina, stamina + vitals.stamina_regeneration * delta)
        PlayerState.ATTACKING:
            velocity = movement_input() * speed * attack.movement_multiplier
            move_and_slide()
            if action_time >= attack.windup and action_time - delta < attack.active_end(): _attack_hits()
            if action_time >= attack_duration: _finish_action()
        PlayerState.DODGING:
            var p: float = clampf(action_time / dodge_duration, 0, 1)
            velocity = dodge_direction * dodge_distance / dodge_duration * (1.45 - 0.9 * p)
            move_and_slide()
            _roll_trail_time += delta
            if _roll_trail_time >= 0.13 and not Feedback.reduced_effects:
                _roll_trail_time = 0.0
                Feedback.burst(global_position + Vector2(0, 10), "footstep", -dodge_direction)
            if action_time >= dodge_duration:
                Feedback.burst(global_position + Vector2(0, 10), "dust", -dodge_direction)
                Feedback.play("step", global_position, -3)
                _finish_action()
        PlayerState.HURT:
            velocity = velocity.move_toward(Vector2.ZERO, delta * vitals.knockback_deceleration)
            move_and_slide()
            if action_time >= vitals.stagger_duration: _finish_action()
        PlayerState.DEAD:
            velocity = Vector2.ZERO
    var distance: float = global_position.distance_to(previous)
    if state == PlayerState.NORMAL:
        travel += distance
        _step_distance += distance
        if _step_distance > (31.0 if sprinting else 25.0):
            _step_distance = 0
            Feedback.play("step", global_position, -8)
            Feedback.burst(global_position + Vector2(0, 13), "footstep", -velocity.normalized())
    stamina_changed.emit(stamina)
    var nearby: Node2D = nearby_interactable()
    interaction_changed.emit("E   " + str(nearby.get_interaction_prompt()) if nearby != null else "")

func _finish_action() -> void:
    state = PlayerState.NORMAL
    action_time = 0.0
    velocity = Vector2.ZERO
    visuals.begin("RESET")
    if not _buffer.is_empty() and _buffer_time > 0:
        var next: String = _buffer
        _buffer = ""
        request_action(next)

func _attack_hits() -> void:
    var shape := CircleShape2D.new()
    shape.radius = minf(attack.hit_radius, attack.reach)
    var query := PhysicsShapeQueryParameters2D.new()
    query.shape = shape
    query.transform = Transform2D(0, global_position + aim * maxf(0.0, attack.reach - shape.radius))
    query.collision_mask = 2
    for result: Dictionary in get_world_2d().direct_space_state.intersect_shape(query):
        var target: Node = result.collider
        if _hits.has(target.get_instance_id()) or not target.has_method("take_damage") or not target.has_method("is_targetable"): continue
        if not target.is_targetable(): continue
        var offset: Vector2 = (target as Node2D).global_position - global_position
        if not offset.is_zero_approx() and aim.dot(offset.normalized()) < cos(deg_to_rad(attack.arc_degrees * 0.5)): continue
        _hits[target.get_instance_id()] = true
        if target.has_method("receive_hit"):
            target.receive_hit(attack, attributes, self)
        else:
            target.take_damage(attack_damage, self)
        hit_stop = attack.hit_stop
        shake = attack.camera_shake
        Feedback.burst(target.global_position, "impact", aim)

func receive_hit(incoming: AttackDefinition, attacker_stats: AttributeStats, source: Node) -> void:
    _apply_damage(incoming.health_damage(attacker_stats, vitals.defence), source, incoming.poise_damage, incoming.knockback, incoming.hit_stop, incoming.camera_shake)

## Compatibility entry point: direct, unmitigated damage.
func take_damage(amount: int, source: Node) -> void:
    _apply_damage(maxi(0, amount), source, vitals.poise, 180.0, 0.04, 5.0)

func _apply_damage(amount: int, source: Node, poise_damage: float, knockback: float, freeze: float, camera_kick: float) -> void:
    if state == PlayerState.DEAD or _protection > 0: return
    if state == PlayerState.DODGING and action_time >= dodge_duration * movement.invulnerability_start and action_time <= dodge_duration * maxf(movement.invulnerability_start, movement.invulnerability_end): return
    health = maxi(0, health - amount)
    health_changed.emit(health, max_health)
    damaged.emit()
    _protection = vitals.damage_invulnerability
    poise_remaining -= poise_damage
    _poise_delay = vitals.poise_regeneration_delay
    var staggered: bool = poise_remaining <= 0.0
    if staggered: poise_remaining = vitals.poise
    if state == PlayerState.ATTACKING and action_time >= attack.windup and action_time <= attack.active_end() and attack.uninterruptible_while_active:
        staggered = false
    shake = camera_kick
    hit_stop = freeze
    if staggered:
        _buffer = ""
        action_time = 0
        var origin: Vector2 = (source as Node2D).global_position if is_instance_valid(source) and source is Node2D else global_position - Vector2.RIGHT
        velocity = (global_position - origin).normalized() * knockback
    Feedback.play("hurt", global_position)
    Feedback.burst(global_position, "impact", velocity.normalized())
    visuals.flash = 1.0
    if health == 0:
        state = PlayerState.DEAD
        set_target(null)
        visuals.begin("death")
        Feedback.burst(global_position + Vector2(0, 10), "dust")
        Feedback.play("death", global_position)
        died.emit()
    elif staggered:
        state = PlayerState.HURT
        visuals.begin("hurt")

func restore(restore_health: bool = true, restore_stamina: bool = true, restore_focus: bool = true) -> void:
    if restore_health: health = max_health
    if restore_stamina: stamina = max_stamina
    if restore_focus: focus = max_focus
    poise_remaining = vitals.poise
    _poise_delay = 0.0
    _protection = 0
    health_changed.emit(health, max_health)
    stamina_changed.emit(stamina)
    set_target(null)

func _update_camera(delta: float) -> void:
    var desired: Vector2 = aim_direction() * 16.0 + velocity * 0.025
    if valid_target(locked_target): desired = (target_point(locked_target) - global_position).limit_length(65) * 0.45
    _camera_bias = _camera_bias.lerp(desired, 1.0 - exp(-delta * 4))
    shake = move_toward(shake, 0, delta * 24)
    camera.offset = _camera_bias + Vector2(sin(Time.get_ticks_msec() * 0.09), cos(Time.get_ticks_msec() * 0.12)) * shake * Feedback.shake_strength

func target_point(target: Node2D) -> Vector2:
    return target.get_target_point() if target.has_method("get_target_point") else target.global_position

func valid_target(target: Node2D) -> bool:
    if not is_instance_valid(target) or not target.is_inside_tree(): return false
    if global_position.distance_to(target_point(target)) > lock_on_radius: return false
    return (target.has_method("is_targetable") and target.is_targetable()) or target.is_in_group("interactable")

func candidates() -> Array[Node2D]:
    var result: Array[Node2D] = []
    for group: String in ["targetable", "interactable"]:
        for target: Node in get_tree().get_nodes_in_group(group):
            if target is Node2D and valid_target(target) and not result.has(target): result.append(target)
    return result

func set_target(target: Node2D) -> void:
    if is_instance_valid(locked_target) and locked_target.has_method("set_lock_on"): locked_target.set_lock_on(false)
    locked_target = target
    if is_instance_valid(target) and target.has_method("set_lock_on"): target.set_lock_on(true)
    target_changed.emit(target)

func toggle_lock() -> void:
    if valid_target(locked_target):
        set_target(null)
        return
    var options: Array[Node2D] = candidates()
    options.sort_custom(func(a: Node2D, b: Node2D) -> bool: return global_position.distance_squared_to(target_point(a)) < global_position.distance_squared_to(target_point(b)))
    if not options.is_empty(): set_target(options[0])

func cycle_target(step: int) -> void:
    var options: Array[Node2D] = candidates()
    options.sort_custom(func(a: Node2D, b: Node2D) -> bool: return (target_point(a) - global_position).angle() < (target_point(b) - global_position).angle())
    if options.is_empty():
        set_target(null)
        return
    set_target(options[posmod(options.find(locked_target) + step, options.size())])

func nearby_interactable() -> Node2D:
    if state == PlayerState.DEAD: return null
    if is_instance_valid(locked_target) and _eligible(locked_target): return locked_target
    var nearest: Node2D
    var distance: float = interaction_radius
    for target: Node in get_tree().get_nodes_in_group("interactable"):
        if target is Node2D and _eligible(target):
            var d: float = global_position.distance_to(target_point(target))
            if d <= distance:
                nearest = target
                distance = d
    return nearest

func _eligible(target: Node2D) -> bool:
    return target.is_in_group("interactable") and global_position.distance_to(target_point(target)) <= interaction_radius and target.has_method("can_interact") and target.can_interact(self)

func interact_nearby() -> void:
    if state != PlayerState.NORMAL: return
    var target: Node2D = nearby_interactable()
    if target != null: target.interact(self)

func show_message(text: String, duration: float = 1.8) -> void:
    message = text
    message_time = duration
