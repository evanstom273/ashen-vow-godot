class_name PlayerController
extends CharacterBody2D

signal health_changed(value: int, maximum: int)
signal stamina_changed(value: float)
signal currency_changed(value: int)
signal loadout_changed(kind: StringName, index: int)
signal charge_changed(hand: StringName, progress: float)
signal damaged
signal died
signal target_changed(target: Node2D)
signal interaction_changed(prompt: String)
enum PlayerState { NORMAL, ATTACK_HOLD, CHARGING, ATTACKING, DODGING, HURT, DEAD, CASTING }
@export_group("Definitions")
@export var character_class: ClassDefinition = preload("res://data/classes/ashen_wanderer.tres")
## Leave empty to use the class starting weapon.
@export var weapon_override: WeaponDefinition
var attributes: AttributeStats
var vitals: VitalStats
var movement: MovementDefinition
var equipped_weapon: WeaponDefinition
var left_hand_weapons: Array[WeaponDefinition] = []
var right_hand_weapons: Array[WeaponDefinition] = []
var spells: Array[SpellDefinition] = []
var spell_charges: Array[int] = []
var utilities: Array[UtilityDefinition] = []
var utility_charges: Array[int] = []
var left_hand_index: int = 0
var right_hand_index: int = 0
var spell_index: int = 0
var utility_index: int = 0
var currency_definition: CurrencyDefinition
var current_currency: int = 0
var max_health: int = 5
var max_stamina: float = 100.0
var max_equip_load: float = 40.0
var poise_remaining: float = 1.0
var _poise_delay: float = 0.0
var attack: AttackDefinition:
    get: return _active_attack if _active_attack != null else (equipped_weapon.light_attack if equipped_weapon != null else null)
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
    get: return attack.duration() if attack != null else 0.0
var attack_damage: int:
    get: return attack.health_damage(attributes)
var lock_on_radius: float:
    get: return movement.lock_on_radius
var interaction_radius: float:
    get: return movement.interaction_radius
var attack_cost: float:
    get: return attack.stamina_cost if attack != null else 0.0
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
var _left_held: bool = false
var _attack_candidate_hand: StringName = &""
var _active_hand: StringName = &"right"
var _active_attack: AttackDefinition
var _active_spell: SpellDefinition
var _spell_launched: bool = false
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
var _utility_cooldown: float = 0.0
var _mobile_controls_active: bool = false
var _mobile_movement := Vector2.ZERO
var _mobile_aim := Vector2.RIGHT

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
    currency_definition = character_class.currency_definition
    left_hand_weapons.clear()
    right_hand_weapons.clear()
    spells.clear()
    utilities.clear()
    if character_class.left_hand_loadout != null:
        for item: WeaponDefinition in character_class.left_hand_loadout.weapons: left_hand_weapons.append(item)
    if character_class.right_hand_loadout != null:
        for item: WeaponDefinition in character_class.right_hand_loadout.weapons: right_hand_weapons.append(item)
    equipped_weapon = weapon_override if weapon_override != null else character_class.starting_weapon
    if equipped_weapon != null and not right_hand_weapons.has(equipped_weapon): right_hand_weapons.push_front(equipped_weapon)
    if equipped_weapon == null or equipped_weapon.light_attack == null:
        equipped_weapon = load("res://data/weapons/wanderer_sword.tres")
    if right_hand_weapons.is_empty(): right_hand_weapons.append(equipped_weapon)
    if character_class.spell_loadout != null:
        for item: SpellDefinition in character_class.spell_loadout.spells:
            if item != null: spells.append(item)
    for item: SpellDefinition in character_class.starting_spells:
        if item != null and not spells.has(item): spells.append(item)
    if character_class.utility_loadout != null:
        for item: UtilityDefinition in character_class.utility_loadout.utilities: utilities.append(item)
    utility_charges.clear()
    for item: UtilityDefinition in utilities: utility_charges.append(item.starting_charges())
    spell_charges.clear()
    for item: SpellDefinition in spells: spell_charges.append(item.starting_charges())
    max_health = vitals.max_health(attributes)
    max_stamina = vitals.max_stamina(attributes)
    max_equip_load = vitals.max_load(attributes)
    health = max_health
    stamina = max_stamina
    current_currency = character_class.starting_currency
    poise_remaining = vitals.poise

func get_selected_weapon(hand: StringName) -> WeaponDefinition:
    var loadout: Array[WeaponDefinition] = right_hand_weapons if hand == &"right" else left_hand_weapons
    var index: int = right_hand_index if hand == &"right" else left_hand_index
    return loadout[index] if not loadout.is_empty() and index >= 0 and index < loadout.size() else null

func cycle_weapon(hand: StringName, direction: int = 1) -> void:
    if state in [PlayerState.ATTACKING, PlayerState.CASTING, PlayerState.DODGING, PlayerState.HURT, PlayerState.DEAD]: return
    var loadout: Array[WeaponDefinition] = right_hand_weapons if hand == &"right" else left_hand_weapons
    if loadout.is_empty(): return
    var selected: int = right_hand_index if hand == &"right" else left_hand_index
    for _step in loadout.size():
        selected = posmod(selected + direction, loadout.size())
        var item: WeaponDefinition = loadout[selected]
        if item == null: continue
        if hand == &"right" and not item.usable_in_right_hand: continue
        if hand == &"left" and not item.usable_in_left_hand: continue
        if hand == &"right":
            right_hand_index = selected
            equipped_weapon = item
        else: left_hand_index = selected
        loadout_changed.emit(hand, selected)
        return

func cycle_spell(direction: int = 1) -> void:
    if not spells.is_empty():
        spell_index = posmod(spell_index + direction, spells.size())
        loadout_changed.emit(&"spell", spell_index)

func cycle_utility(direction: int = 1) -> void:
    if not utilities.is_empty():
        utility_index = posmod(utility_index + direction, utilities.size())
        loadout_changed.emit(&"utility", utility_index)

func get_spell_catalyst(spell: SpellDefinition = null) -> WeaponDefinition:
    var school: String = spell.school if spell != null else ""
    for hand: StringName in [&"right", &"left"]:
        var weapon: WeaponDefinition = get_selected_weapon(hand)
        if weapon == null or not weapon.is_spell_catalyst: continue
        if hand == &"left" and not weapon.usable_in_left_hand: continue
        if hand == &"right" and not weapon.usable_in_right_hand: continue
        if not attributes.meets(weapon.requirements): continue
        if not weapon.catalyst_schools.is_empty() and not weapon.catalyst_schools.has(school): continue
        return weapon
    return null

func begin_hand_action(hand: StringName) -> void:
    if state != PlayerState.NORMAL: return
    var weapon: WeaponDefinition = get_selected_weapon(hand)
    if weapon != null and weapon.is_spell_catalyst:
        use_selected_spell(hand)
        return
    if weapon == null or weapon.light_attack == null: return
    if not attributes.meets(weapon.requirements):
        show_message("Weapon requirements not met")
        return
    _attack_candidate_hand = hand
    _active_hand = hand
    _hold_time = 0.0
    _active_attack = weapon.light_attack
    action_time = 0.0
    state = PlayerState.ATTACK_HOLD

func release_hand_action(hand: StringName) -> void:
    if _attack_candidate_hand != hand: return
    if state == PlayerState.ATTACK_HOLD:
        commit_light_attack(hand)
    else:
        if state == PlayerState.CHARGING:
            commit_charged_attack(hand)
        else:
            _cancel_attack_candidate()

func commit_light_attack(hand: StringName) -> void:
    var weapon: WeaponDefinition = get_selected_weapon(hand)
    _start_attack(hand, weapon.light_attack if weapon != null else null)

func commit_charged_attack(hand: StringName) -> void:
    var weapon: WeaponDefinition = get_selected_weapon(hand)
    _start_attack(hand, weapon.charged_attack if weapon != null and weapon.charged_attack != null else (weapon.light_attack if weapon != null else null))

func _cancel_attack_candidate() -> void:
    if state not in [PlayerState.ATTACK_HOLD, PlayerState.CHARGING]: return
    _attack_candidate_hand = &""
    _hold_time = 0.0
    _active_attack = null
    if state in [PlayerState.ATTACK_HOLD, PlayerState.CHARGING]: state = PlayerState.NORMAL
    charge_changed.emit(_active_hand, 0.0)

func get_charge_progress(hand: StringName) -> float:
    if hand != _active_hand: return 0.0
    if state == PlayerState.CHARGING: return 1.0
    if state != PlayerState.ATTACK_HOLD or _active_attack == null: return 0.0
    return clampf(_hold_time / maxf(0.01, _active_attack.charge_threshold), 0.0, 1.0)

func _start_attack(hand: StringName, definition: AttackDefinition) -> void:
    if definition == null: _cancel_attack_candidate(); return
    if not state in [PlayerState.NORMAL, PlayerState.ATTACK_HOLD, PlayerState.CHARGING]: return
    if stamina < definition.stamina_cost:
        show_message("Catch your breath", 0.7)
        _cancel_attack_candidate()
        return
    stamina -= definition.stamina_cost
    stamina_changed.emit(stamina)
    _active_hand = hand
    _active_attack = definition
    _spell_launched = false
    _attack_candidate_hand = &""
    action_time = 0.0
    sprinting = false
    aim = aim_direction()
    if absf(aim.x) > 0.05: facing = signf(aim.x)
    state = PlayerState.ATTACKING
    aim = Vector2.RIGHT.rotated(snappedf(aim.angle(), PI / 4.0))
    _hits.clear()
    Feedback.play(String(definition.swing_sound), global_position)
    visuals.begin("attack")

func get_display_name() -> String: return character_class.display_name

func set_mobile_controls_active(value: bool) -> void:
    _mobile_controls_active = value
    if not value:
        _mobile_movement = Vector2.ZERO

func set_mobile_movement(value: Vector2) -> void:
    _mobile_movement = value.limit_length(1.0)
    if _mobile_movement.length() > 0.12:
        _mobile_aim = _mobile_movement.normalized()

func begin_dodge_sprint_hold() -> void:
    if state == PlayerState.DEAD: return
    _right_held = true
    _hold_time = 0.0
    _sprint_exhausted = false

func release_dodge_sprint_hold() -> void:
    if _right_held and _hold_time < movement.sprint_hold_threshold:
        request_action("dodge")
    _right_held = false

func _notification(what: int) -> void:
    if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
        _right_held = false
        _left_held = false
        _mobile_movement = Vector2.ZERO
        _hold_time = 0.0
        _buffer = ""
        _cancel_attack_candidate()

func _unhandled_input(event: InputEvent) -> void:
    # Touch can be emulated as mouse input by Android. The dedicated mobile
    # controls call the player API directly, so ignore those synthetic clicks.
    if _mobile_controls_active and event is InputEventMouseButton: return
    if event.is_action_pressed("cycle_right"): cycle_weapon(&"right")
    if event.is_action_pressed("cycle_left"): cycle_weapon(&"left")
    if event.is_action_pressed("cycle_spell"): cycle_spell()
    if event.is_action_pressed("cycle_utility"): cycle_utility()
    if state == PlayerState.DEAD: return
    if event.is_action_pressed("attack"): begin_hand_action(&"right")
    if event.is_action_pressed("left_attack"): begin_hand_action(&"left")
    if event.is_action_released("attack"): release_hand_action(&"right")
    if event.is_action_released("left_attack"): release_hand_action(&"left")
    if event.is_action_pressed("dodge"): begin_dodge_sprint_hold()
    if event.is_action_released("dodge"): release_dodge_sprint_hold()
    if event.is_action_pressed("cast_spell"): use_selected_spell()
    if event.is_action_pressed("use_utility"): use_selected_utility()
    if event.is_action_pressed("lock_on"): toggle_lock()
    if event.is_action_pressed("target_next"): cycle_target(1)
    if event.is_action_pressed("target_previous"): cycle_target(-1)
    if event.is_action_pressed("interact"): interact_nearby()

func movement_input() -> Vector2:
    var physical := Input.get_vector("move_left", "move_right", "move_up", "move_down")
    if _mobile_controls_active and _mobile_movement.length_squared() > physical.length_squared():
        return _mobile_movement
    return physical

func aim_direction() -> Vector2:
    if valid_target(locked_target):
        var locked_vector: Vector2 = target_point(locked_target) - global_position
        if locked_vector.length() > 4.0: return locked_vector.normalized()
    if _mobile_controls_active:
        if _mobile_aim.length() > 0.12: return _mobile_aim.normalized()
        return Vector2(facing, 0)
    var point: Vector2 = get_global_mouse_position()
    var vector: Vector2 = point - global_position
    return vector.normalized() if vector.length() > 4.0 else Vector2(facing, 0)

func request_action(action: String) -> void:
    if state == PlayerState.DEAD: return
    if state in [PlayerState.ATTACK_HOLD, PlayerState.CHARGING] and action == "dodge":
        _cancel_attack_candidate()
    if state != PlayerState.NORMAL:
        var duration: float = dodge_duration if state == PlayerState.DODGING else attack_duration
        if state in [PlayerState.ATTACKING, PlayerState.DODGING] and duration - action_time <= movement.input_buffer:
            _buffer = action
            _buffer_time = movement.input_buffer
        return
    if action != "dodge" or _cooldown > 0.0: return
    if stamina < dodge_cost:
        if _denied_timer <= 0.0:
            show_message("Catch your breath", 0.7)
            _denied_timer = 0.7
        return
    stamina -= dodge_cost
    stamina_changed.emit(stamina)
    _regen_delay = vitals.stamina_regeneration_delay
    action_time = 0.0
    sprinting = false
    aim = aim_direction()
    if absf(aim.x) > 0.05: facing = signf(aim.x)
    state = PlayerState.DODGING
    dodge_direction = movement_input()
    if dodge_direction.is_zero_approx(): dodge_direction = aim
    _cooldown = dodge_cooldown
    _roll_trail_time = 0.0
    Feedback.burst(global_position + Vector2(0, 10), "dust", -dodge_direction)
    Feedback.play("roll", global_position)
    visuals.begin("roll")

func _physics_process(delta: float) -> void:
    _poise_delay = maxf(0, _poise_delay - delta)
    if _poise_delay <= 0: poise_remaining = minf(vitals.poise, poise_remaining + vitals.poise_regeneration * delta)
    _cooldown = maxf(0, _cooldown - delta)
    _protection = maxf(0, _protection - delta)
    _denied_timer = maxf(0, _denied_timer - delta)
    _utility_cooldown = maxf(0, _utility_cooldown - delta)
    message_time = maxf(0, message_time - delta)
    if is_instance_valid(locked_target) and not valid_target(locked_target): set_target(null)
    if not is_instance_valid(locked_target): locked_target = null
    if _right_held or not _attack_candidate_hand.is_empty(): _hold_time += delta
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
        PlayerState.ATTACK_HOLD:
            velocity = Vector2.ZERO
            if not movement_input().is_zero_approx():
                _cancel_attack_candidate()
            elif _active_attack != null and _hold_time >= _active_attack.charge_threshold:
                state = PlayerState.CHARGING
                charge_changed.emit(_active_hand, 1.0)
            elif _active_attack != null:
                charge_changed.emit(_active_hand, get_charge_progress(_active_hand))
        PlayerState.CHARGING:
            velocity = Vector2.ZERO
            if not movement_input().is_zero_approx(): _cancel_attack_candidate()
            else: charge_changed.emit(_active_hand, 1.0)
        PlayerState.ATTACKING:
            velocity = movement_input() * speed * attack.movement_multiplier
            move_and_slide()
            if action_time >= attack.windup and action_time - delta < attack.active_end(): _attack_hits()
            if action_time >= attack_duration: _finish_action()
        PlayerState.CASTING:
            velocity = movement_input() * speed * _active_attack.movement_multiplier
            move_and_slide()
            if not _spell_launched and action_time >= _active_attack.windup:
                _cast_active_spell()
            if action_time >= _active_attack.duration(): _finish_action()
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
    _active_attack = null
    _active_spell = null
    charge_changed.emit(_active_hand, 0.0)
    visuals.begin("RESET")
    if not _buffer.is_empty() and _buffer_time > 0:
        var next: String = _buffer
        _buffer = ""
        request_action(next)

func _attack_hits() -> void:
    if _active_spell != null:
        _cast_active_spell()
        return
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

func use_selected_spell(hand: StringName = &"") -> void:
    if state != PlayerState.NORMAL: return
    if spells.is_empty():
        show_message("No spells equipped")
        return
    var spell: SpellDefinition = spells[spell_index]
    if spell == null or spell.cast == null: return
    if spell_charges.size() <= spell_index or spell_charges[spell_index] <= 0:
        show_message("No uses remaining")
        return
    var catalyst: WeaponDefinition = get_spell_catalyst(spell) if hand.is_empty() else get_selected_weapon(hand)
    if catalyst == null or not catalyst.is_spell_catalyst:
        show_message("Select a " + spell.school + " catalyst with Q/R (Wand casts all)")
        return
    if not attributes.meets(catalyst.requirements) or (not catalyst.catalyst_schools.is_empty() and not catalyst.catalyst_schools.has(spell.school)):
        show_message("This catalyst cannot cast " + spell.school)
        return
    if hand == &"left" and not catalyst.usable_in_left_hand: return
    if hand == &"right" and not catalyst.usable_in_right_hand: return
    if spell.delivery == "Projectile" and spell.projectile_scene == null:
        show_message("Spell has no projectile scene")
        return
    if not attributes.meets(spell.requirements):
        show_message("Spell requirements not met")
        return
    if stamina < spell.cast.stamina_cost:
        show_message("Catch your breath", 0.7)
        return
    spell_charges[spell_index] -= 1
    _active_spell = spell
    _active_attack = spell.cast
    _active_hand = hand if not hand.is_empty() else (&"right" if get_selected_weapon(&"right") == catalyst else &"left")
    _spell_launched = false
    _attack_candidate_hand = &""
    stamina -= spell.cast.stamina_cost
    _regen_delay = vitals.stamina_regeneration_delay
    stamina_changed.emit(stamina)
    loadout_changed.emit(&"spell", spell_index)
    aim = aim_direction()
    if absf(aim.x) > 0.05: facing = signf(aim.x)
    action_time = 0.0
    sprinting = false
    state = PlayerState.CASTING
    visuals.begin("RESET")
    show_message(spell.display_name, spell.cast.duration())

func _cast_active_spell() -> void:
    if _active_spell == null or _spell_launched: return
    _spell_launched = true
    if _active_spell.health_restore > 0:
        health = mini(max_health, health + _active_spell.health_restore)
        health_changed.emit(health, max_health)
    if _active_spell.stamina_restore > 0:
        stamina = minf(max_stamina, stamina + _active_spell.stamina_restore)
        stamina_changed.emit(stamina)
    if _active_spell.delivery == "Self":
        _spell_burst(global_position, 42.0)
        return
    if _active_spell.delivery == "Projectile":
        var projectile_scene: PackedScene = _active_spell.projectile_scene if _active_spell.projectile_scene != null else load("res://scenes/spell_projectile.tscn")
        var projectile: SpellProjectile = projectile_scene.instantiate() as SpellProjectile
        if projectile == null:
            push_error("Projectile scene must use SpellProjectile: " + _active_spell.display_name)
            return
        projectile.direction = aim
        projectile.speed = _active_spell.projectile_speed
        projectile.lifetime = _active_spell.lifetime
        projectile.attack = _active_spell.cast
        projectile.attacker_stats = attributes
        projectile.source = self
        projectile.tint = _active_spell.cast.slash_color
        projectile.radius = _active_spell.projectile_radius
        get_tree().current_scene.add_child(projectile)
        projectile.global_position = global_position
        Feedback.play(String(_active_spell.cast.swing_sound), global_position)
        return
    _spell_area_hit()

func _spell_area_hit() -> void:
    var radius: float = maxf(24.0, _active_spell.area_radius)
    var shape := CircleShape2D.new()
    shape.radius = radius
    var query := PhysicsShapeQueryParameters2D.new()
    query.shape = shape
    var center: Vector2 = global_position
    if _active_spell.delivery == "Target":
        center = global_position + aim * _active_attack.reach
        if valid_target(locked_target): center = target_point(locked_target)
    query.transform = Transform2D(0, center)
    query.collision_mask = 2
    _spell_burst(center, radius)
    var hit_targets: Dictionary = {}
    for result: Dictionary in get_world_2d().direct_space_state.intersect_shape(query):
        var target: Node = result.collider
        if hit_targets.has(target.get_instance_id()): continue
        hit_targets[target.get_instance_id()] = true
        if target.has_method("receive_hit") and target.has_method("is_targetable") and target.is_targetable():
            target.receive_hit(_active_spell.cast, attributes, self)

func _spell_burst(at: Vector2, radius: float) -> void:
    var effect := Node2D.new()
    effect.set_script(preload("res://scripts/spell_burst.gd"))
    effect.set("radius", radius)
    effect.set("tint", _active_spell.cast.slash_color)
    get_tree().current_scene.add_child(effect)
    effect.global_position = at
    Feedback.play(String(_active_spell.cast.swing_sound), at)

func use_selected_utility() -> void:
    if state != PlayerState.NORMAL or utilities.is_empty() or _utility_cooldown > 0.0: return
    var utility: UtilityDefinition = utilities[utility_index]
    if utility == null or utility_charges[utility_index] <= 0:
        show_message("No charges remaining")
        return
    utility_charges[utility_index] -= 1
    health = mini(max_health, health + utility.health_restore)
    stamina = minf(max_stamina, stamina + utility.stamina_restore)
    _utility_cooldown = utility.recovery_time
    health_changed.emit(health, max_health)
    stamina_changed.emit(stamina)
    show_message(utility.display_name)
    Feedback.play(String(utility.sound_key), global_position)

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
        _spawn_currency_drop()
        set_target(null)
        visuals.begin("death")
        Feedback.burst(global_position + Vector2(0, 10), "dust")
        Feedback.play("death", global_position)
        died.emit()
    elif staggered:
        state = PlayerState.HURT
        visuals.begin("hurt")

func restore(restore_health: bool = true, restore_stamina: bool = true, _unused: bool = true) -> void:
    if restore_health: health = max_health
    if restore_stamina: stamina = max_stamina
    for i in utilities.size(): utility_charges[i] = utilities[i].maximum_charges
    for i in spells.size(): spell_charges[i] = spells[i].maximum_charges
    poise_remaining = vitals.poise
    _poise_delay = 0.0
    _protection = 0
    health_changed.emit(health, max_health)
    stamina_changed.emit(stamina)

func add_currency(amount: int, feedback_message: String = "") -> void:
    current_currency = maxi(0, current_currency + amount)
    currency_changed.emit(current_currency)
    if not feedback_message.is_empty(): show_message(feedback_message)

func _spawn_currency_drop() -> void:
    if current_currency <= 0 or not character_class.lose_currency_on_death: return
    for old: Node in get_tree().get_nodes_in_group("currency_drop"): old.queue_free()
    var drop: Node2D = load("res://scenes/currency_drop.tscn").instantiate()
    drop.position = global_position
    drop.amount = current_currency
    drop.definition = character_class.death_drop.duplicate(true) as CurrencyDropDefinition if character_class.death_drop != null else CurrencyDropDefinition.new()
    drop.definition.delivery_mode = CurrencyDropDefinition.DeliveryMode.PICKUP
    drop.definition.fixed_amount = current_currency
    drop.definition.display_name = currency_definition.display_name if currency_definition != null else "Embers"
    drop.definition.color = currency_definition.color if currency_definition != null else Color("e6b968")
    get_parent().add_child(drop)
    current_currency = 0
    currency_changed.emit(current_currency)

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
    return target.is_in_group("enemy") and target.has_method("is_targetable") and target.is_targetable()

func candidates() -> Array[Node2D]:
    var result: Array[Node2D] = []
    for target: Node in get_tree().get_nodes_in_group("enemy"):
        if target is Node2D and valid_target(target):
            # Range limits acquisition, never retention of an existing lock.
            if target == locked_target or global_position.distance_to(target_point(target)) <= lock_on_radius:
                result.append(target)
    return result

func set_target(target: Node2D) -> void:
    if target != null and (state == PlayerState.DEAD or not valid_target(target)): return
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
    if state == PlayerState.DEAD: return
    var options: Array[Node2D] = candidates()
    options.sort_custom(func(a: Node2D, b: Node2D) -> bool: return (target_point(a) - global_position).angle() < (target_point(b) - global_position).angle())
    if options.is_empty():
        return
    set_target(options[posmod(options.find(locked_target) + step, options.size())])

func nearby_interactable() -> Node2D:
    if state == PlayerState.DEAD:
        for target: Node in get_tree().get_nodes_in_group("currency_drop"):
            if target is Node2D and _eligible(target) and global_position.distance_to(target_point(target)) <= interaction_radius: return target
        return null
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
    var target: Node2D = nearby_interactable()
    if state != PlayerState.NORMAL and not (state == PlayerState.DEAD and target != null and target.is_in_group("currency_drop")): return
    if target != null: target.interact(self)

func show_message(text: String, duration: float = 1.8) -> void:
    message = text
    message_time = duration
