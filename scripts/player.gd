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
signal shrine_menu_requested
enum PlayerState { NORMAL, ATTACK_HOLD, CHARGING, ATTACKING, DODGING, HURT, DEAD, CASTING, USING_UTILITY }
var _active_utility: UtilityDefinition
var _utility_released: bool = false
var _spell_use_pool: Dictionary = {}
var _session_ready: bool = false
@export_group("Definitions")
@export var character_class: ClassDefinition = preload("res://data/classes/ashen_wanderer.tres")
## Leave empty to use the class starting weapon.
@export var weapon_override: WeaponDefinition
var transformation: PlayerTransformation
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
## Progression-owned bonus. Future memory-stone equivalents increase this value.
var spell_slot_bonus: int = 0
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
	get: return movement.walk_speed * SpellEffects.movement(self)
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
var _combat_time: float = 0.0
var _right_held: bool = false
var _hold_time: float = 0.0
var _left_held: bool = false
var _attack_candidate_hand: StringName = &""
var _active_hand: StringName = &"right"
var _active_attack: AttackDefinition
var _active_spell: SpellDefinition
var _spell_launched: bool = false
var _spell_delivery_ended_at: float = -1.0
var _cast_vfx: Node2D
var _delivery_context: SpellCastContext
var _delivery_runtime: Node2D
var _channel_input: StringName = &""
var _weapon_tokens: Dictionary = {}
var _next_weapon_token: int = 1

func weapon_token(hand: StringName) -> int:
	var items: Array[WeaponDefinition] = right_hand_weapons if hand == &"right" else left_hand_weapons
	if not _weapon_tokens.has(hand):
		var tokens: Array[int] = []
		for _item in items:
			tokens.append(_next_weapon_token)
			_next_weapon_token += 1
		_weapon_tokens[hand] = tokens
	var index: int = right_hand_index if hand == &"right" else left_hand_index
	return _weapon_tokens[hand][index] if index < _weapon_tokens[hand].size() else 0

func _transfer_weapon_tokens(hand: StringName, replacement: Array[WeaponDefinition]) -> void:
	weapon_token(hand)
	var old: Array[WeaponDefinition] = right_hand_weapons if hand == &"right" else left_hand_weapons
	var used: Dictionary = {}
	var next_tokens: Array[int] = []
	for item: WeaponDefinition in replacement:
		var token: int = 0
		for i in old.size():
			if item != null and old[i] == item and not used.has(i):
				token = _weapon_tokens[hand][i]
				used[i] = true
				break
		if token == 0:
			token = _next_weapon_token
			_next_weapon_token += 1
		next_tokens.append(token)
	for token: int in _weapon_tokens[hand]:
		if not next_tokens.has(token): SpellEffects.of(self).imbues.erase(token)
	_weapon_tokens[hand] = next_tokens

func release_spell_input(input: StringName = &"cast") -> void:
	if _channel_input == input:
		cancel_spell_channel()

func cancel_spell_channel() -> void:
	if _channel_input.is_empty(): return
	_channel_input = &""
	if is_instance_valid(_delivery_runtime): _delivery_runtime.call("cancel")
	_delivery_runtime = null
	_clear_cast_vfx()
	if state == PlayerState.CASTING: _finish_action()

func delivery_channel_active(instance: Node) -> bool:
	return state == PlayerState.CASTING and not _channel_input.is_empty() and _delivery_runtime == instance

func delivery_movement_active(instance: Node) -> bool:
	return state == PlayerState.CASTING and _delivery_runtime == instance

func command_orbiters() -> void:
	if not form_allows("spells"): return
	for instance: Node in get_tree().get_nodes_in_group("spell_delivery"):
		if instance.get("context").caster == self: instance.call("command")

func delivery_status() -> String:
	var count: int = 0
	for instance: Node in get_tree().get_nodes_in_group("spell_delivery"):
		if instance.get("context").caster == self and instance.get("definition") is OrbitingDelivery:
			count += int(instance.get("remaining"))
	var text: String = "Orbiters: %d  [B Command]" % count if count > 0 else ""
	if not _channel_input.is_empty() and is_instance_valid(_delivery_runtime):
		text = "Channel: %.1fs  " % maxf(0, float(_delivery_runtime.get("runtime_duration")) - float(_delivery_runtime.get("elapsed"))) + text
	return text
var _buffer: String = ""
var _buffer_time: float = 0.0
var _hits: Dictionary = {}
var _camera_bias := Vector2.ZERO
var _base_camera_zoom := Vector2.ONE
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
var gamepad_active: bool = false
var _gamepad_device: int = -1
var _stick_aim := Vector2.RIGHT
var _target_flick_ready: bool = true
var _attack_hold_time: float = 0.0

func reset_control_holds() -> void:
	_buffer = ""
	_right_held = false
	sprinting = false
	_hold_time = 0.0
	_mobile_movement = Vector2.ZERO
	_cancel_attack_candidate()
	cancel_spell_channel()

func _input(event: InputEvent) -> void:
	if event is InputEventJoypadButton or (event is InputEventJoypadMotion and absf(event.axis_value) > 0.25):
		gamepad_active = true
		_gamepad_device = event.device
	elif event is InputEventKey or event is InputEventMouseButton or (event is InputEventMouseMotion and event.relative.length() > 2.0):
		gamepad_active = false

func _update_gamepad_aim() -> void:
	if not gamepad_active: return
	if not Input.get_connected_joypads().has(_gamepad_device):
		reset_control_holds()
		gamepad_active = false
		return
	var stick := Vector2(Input.get_joy_axis(_gamepad_device, JOY_AXIS_RIGHT_X), Input.get_joy_axis(_gamepad_device, JOY_AXIS_RIGHT_Y))
	if stick.length() < 0.3: _target_flick_ready = true
	if valid_target(locked_target):
		if stick.length() > 0.7 and _target_flick_ready:
			_target_flick_ready = false
			var best: Node2D
			var best_score: float = -INF
			for target: Node2D in candidates():
				if target == locked_target: continue
				var offset: Vector2 = target_point(target) - target_point(locked_target)
				var alignment: float = stick.normalized().dot(offset.normalized())
				var score: float = alignment - offset.length() / WorldScale.art_distance(2000.0)
				if alignment > 0.35 and score > best_score:
					best = target
					best_score = score
			if best != null: set_target(best)
	elif stick.length() > 0.25:
		_stick_aim = stick.normalized()
	elif movement_input().length() > 0.1:
		_stick_aim = movement_input().normalized()

func request_light_attack(hand: StringName) -> void:
	if not form_allows("melee") and not form_allows("spells"): return
	if state != PlayerState.NORMAL:
		request_action("light_" + String(hand))
		return
	var selected: WeaponDefinition = get_selected_weapon(hand)
	if selected == null or not attributes.meets(selected.requirements): return
	if selected.is_spell_catalyst: use_selected_spell(hand)
	else: commit_light_attack(hand)

func _clear_cast_vfx() -> void:
	if is_instance_valid(_cast_vfx):
		_cast_vfx.queue_free()
	_cast_vfx = null

func _exit_tree() -> void:
	SpellDeliveryService.clear_owned(self)
	_clear_cast_vfx()

func _ready() -> void:
	transformation = PlayerTransformation.new()
	add_child(transformation)
	if not InputMap.has_action("spell_command"):
		InputMap.add_action("spell_command")
		var command_key := InputEventKey.new()
		command_key.physical_keycode = KEY_B
		InputMap.action_add_event("spell_command", command_key)
	add_to_group("player")
	ActorRegistry.register(self)
	apply_definitions()
	collision_layer = 1
	collision_mask = 51
	Elevation.register_body(self)
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	z_index = 0
	$HUD.queue_free()
	$AttackPivot.queue_free()
	visuals = Node2D.new()
	visuals.set_script(load("res://scripts/player_visuals.gd"))
	add_child(visuals)
	camera.enabled = true
	$AudioListener2D.make_current()
	_base_camera_zoom = camera.zoom
	camera.limit_left = -820
	camera.limit_right = 820
	camera.limit_top = -520
	camera.limit_bottom = 520
	GameSession.call_deferred("attach_player", self)

## Rebuild derived stats on spawn or after an explicit equipment/attribute change.
func apply_definitions() -> void:
	_weapon_tokens.clear()
	if character_class == null: character_class = load("res://data/classes/ashen_wanderer.tres")
	attributes = character_class.attributes.duplicate(true) as AttributeStats if character_class.attributes != null else AttributeStats.new()
	vitals = character_class.vitals if character_class.vitals != null else VitalStats.new()
	movement = character_class.movement if character_class.movement != null else MovementDefinition.new()
	currency_definition = character_class.currency_definition
	left_hand_weapons.clear()
	right_hand_weapons.clear()
	spells.clear()
	utilities.clear()

	var left_capacity: int = get_weapon_slot_capacity(&"left")
	var right_capacity: int = get_weapon_slot_capacity(&"right")
	var spell_capacity: int = get_spell_slot_capacity()

	if character_class.left_hand_loadout != null:
		for i in mini(left_capacity, character_class.left_hand_loadout.weapons.size()):
			left_hand_weapons.append(character_class.left_hand_loadout.weapons[i])
	while left_hand_weapons.size() < left_capacity: left_hand_weapons.append(null)

	if character_class.right_hand_loadout != null:
		for i in mini(right_capacity, character_class.right_hand_loadout.weapons.size()):
			right_hand_weapons.append(character_class.right_hand_loadout.weapons[i])
	while right_hand_weapons.size() < right_capacity: right_hand_weapons.append(null)

	equipped_weapon = weapon_override if weapon_override != null else character_class.starting_weapon
	if equipped_weapon == null or equipped_weapon.light_attack == null:
		equipped_weapon = load("res://data/weapons/wanderer_sword.tres")
	if weapon_override != null and not right_hand_weapons.is_empty():
		right_hand_weapons[0] = weapon_override
	elif not right_hand_weapons.has(equipped_weapon) and not right_hand_weapons.is_empty():
		right_hand_weapons[0] = equipped_weapon
	if right_hand_weapons.is_empty():
		right_hand_weapons.append(equipped_weapon)
	right_hand_index = _first_filled_weapon_index(right_hand_weapons)
	left_hand_index = _first_filled_weapon_index(left_hand_weapons)
	equipped_weapon = get_selected_weapon(&"right")

	if character_class.spell_loadout != null:
		for i in mini(spell_capacity, character_class.spell_loadout.spells.size()):
			var prepared: SpellDefinition = character_class.spell_loadout.spells[i]
			if prepared != null and spell_memory_used(spells) + prepared.memory_slots > spell_capacity:
				push_warning("Starting spell loadout exceeds memory: " + prepared.display_name)
				spells.append(null)
			else: spells.append(prepared)
	for item: SpellDefinition in character_class.starting_spells:
		if item != null and not spells.has(item) and spells.size() < spell_capacity and spell_memory_used(spells) + item.memory_slots <= spell_capacity: spells.append(item)
	while spells.size() < spell_capacity: spells.append(null)
	spell_index = _first_filled_spell_index(spells)

	if character_class.utility_loadout != null:
		for item: UtilityDefinition in character_class.utility_loadout.utilities: utilities.append(item)
	utility_charges.clear()
	for item: UtilityDefinition in utilities: utility_charges.append(item.starting_charges() if item != null else 0)
	_rebuild_spell_charges()
	PlayerSpellbook.refresh(self)
	max_health = vitals.max_health(attributes)
	max_stamina = vitals.max_stamina(attributes)
	max_equip_load = vitals.max_load(attributes)
	health = max_health
	stamina = max_stamina
	_combat_time = 0.0
	current_currency = character_class.starting_currency
	poise_remaining = vitals.poise

func get_weapon_slot_capacity(hand: StringName) -> int:
	var definition: WeaponLoadoutDefinition = character_class.right_hand_loadout if hand == &"right" else character_class.left_hand_loadout
	return maxi(1, definition.max_slots) if definition != null else 2

func get_spell_slot_capacity() -> int:
	var definition: SpellLoadoutDefinition = character_class.spell_loadout
	if definition == null: return 3 + maxi(0, spell_slot_bonus)
	return clampi(definition.base_slots + maxi(0, spell_slot_bonus), 1, definition.maximum_slots)

func unlock_spell_slots(amount: int = 1) -> void:
	if amount <= 0: return
	var before: int = get_spell_slot_capacity()
	spell_slot_bonus += amount
	var after: int = get_spell_slot_capacity()
	if after <= before: return
	while spells.size() < after:
		spells.append(null)
		spell_charges.append(0)
	loadout_changed.emit(&"spell", spell_index)

func set_weapon_loadout(hand: StringName, items: Array[WeaponDefinition]) -> void:
	if state != PlayerState.NORMAL: return
	if hand != &"right" and hand != &"left": return
	var capacity: int = get_weapon_slot_capacity(hand)
	var previous: WeaponDefinition = get_selected_weapon(hand)
	var next: Array[WeaponDefinition] = []
	for i in capacity:
		var item: WeaponDefinition = items[i] if i < items.size() else null
		if item != null:
			if hand == &"right" and not item.usable_in_right_hand: item = null
			if hand == &"left" and not item.usable_in_left_hand: item = null
		next.append(item)

	_transfer_weapon_tokens(hand, next)
	if hand == &"right":
		right_hand_weapons = next
		right_hand_index = next.find(previous) if previous != null and next.has(previous) else _first_filled_weapon_index(next)
		equipped_weapon = get_selected_weapon(&"right")
		loadout_changed.emit(&"right", right_hand_index)
	else:
		left_hand_weapons = next
		left_hand_index = next.find(previous) if previous != null and next.has(previous) else _first_filled_weapon_index(next)
		loadout_changed.emit(&"left", left_hand_index)
	PlayerSpellbook.refresh(self)

func set_spell_loadout(items: Array[SpellDefinition]) -> void:
	if state != PlayerState.NORMAL: return
	for item: SpellDefinition in items:
		if item != null and item.is_basic():
			show_message("Basic magic is supplied by your catalyst")
			return
	if spell_memory_used(items) > get_spell_slot_capacity():
		show_message("Not enough spell memory")
		return
	var capacity: int = get_spell_slot_capacity()
	var previous: SpellDefinition = get_selected_spell()
	PlayerSpellbook.remember(self)
	spells.clear()
	for i in capacity:
		spells.append(items[i] if i < items.size() else null)
	spell_index = spells.find(previous) if previous != null and spells.has(previous) else _first_filled_spell_index(spells)
	_rebuild_spell_charges()
	for i in spells.size():
		if spells[i] != null and _spell_use_pool.has(spells[i].id):
			spell_charges[i] = clampi(int(_spell_use_pool[spells[i].id]), 0, spells[i].maximum_charges)
	PlayerSpellbook.refresh(self)

func spell_memory_used(items: Array[SpellDefinition]) -> int:
	var used: int = 0
	for spell: SpellDefinition in items:
		if spell != null and not spell.is_basic(): used += spell.memory_slots
	return used

func get_selected_spell() -> SpellDefinition:
	return spells[spell_index] if not spells.is_empty() and spell_index >= 0 and spell_index < spells.size() else null

func request_shrine_menu() -> void:
	if not form_allows("interaction"): return
	if state == PlayerState.DEAD: return
	_right_held = false
	_cancel_attack_candidate()
	shrine_menu_requested.emit()

func _first_filled_weapon_index(items: Array[WeaponDefinition]) -> int:
	for i in items.size():
		if items[i] != null: return i
	return 0

func _first_filled_spell_index(items: Array[SpellDefinition]) -> int:
	for i in items.size():
		if items[i] != null: return i
	return 0

func _rebuild_spell_charges() -> void:
	spell_charges.clear()
	for item: SpellDefinition in spells:
		spell_charges.append(item.starting_charges() if item != null else 0)

func get_selected_weapon(hand: StringName) -> WeaponDefinition:
	var loadout: Array[WeaponDefinition] = right_hand_weapons if hand == &"right" else left_hand_weapons
	var index: int = right_hand_index if hand == &"right" else left_hand_index
	return loadout[index] if not loadout.is_empty() and index >= 0 and index < loadout.size() else null

func cycle_weapon(hand: StringName, direction: int = 1) -> void:
	if not form_allows("cycling"): return
	if state in [PlayerState.ATTACKING, PlayerState.CASTING, PlayerState.DODGING, PlayerState.HURT, PlayerState.DEAD, PlayerState.USING_UTILITY]: return
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
		PlayerSpellbook.refresh(self)
		return

func cycle_spell(direction: int = 1) -> void:
	if not form_allows("cycling"): return
	if state != PlayerState.NORMAL: return
	if spells.is_empty(): return
	var selected: int = spell_index
	for _step in spells.size():
		selected = posmod(selected + direction, spells.size())
		if spells[selected] == null: continue
		spell_index = selected
		loadout_changed.emit(&"spell", spell_index)
		return

func cycle_utility(direction: int = 1) -> void:
	if not form_allows("cycling"): return
	if state != PlayerState.NORMAL: return
	for _step in utilities.size():
		utility_index = posmod(utility_index + direction, utilities.size())
		if utilities[utility_index] == null: continue
		loadout_changed.emit(&"utility", utility_index)
		return

func get_spell_catalyst(spell: SpellDefinition = null) -> WeaponDefinition:
	var school: String = spell.school if spell != null else ""
	for hand: StringName in [&"right", &"left"]:
		var weapon: WeaponDefinition = get_selected_weapon(hand)
		if weapon == null or not weapon.is_spell_catalyst: continue
		if spell != null and spell.is_basic() and weapon.basic_spell != spell: continue
		if hand == &"left" and not weapon.usable_in_left_hand: continue
		if hand == &"right" and not weapon.usable_in_right_hand: continue
		if not attributes.meets(weapon.requirements): continue
		if not weapon.catalyst_schools.is_empty() and not weapon.catalyst_schools.has(school): continue
		return weapon
	return null

func begin_hand_action(hand: StringName) -> void:
	if not form_allows("melee") and not form_allows("spells"): return
	if state != PlayerState.NORMAL: return
	var weapon: WeaponDefinition = get_selected_weapon(hand)
	if weapon != null and weapon.is_spell_catalyst:
		use_selected_spell(hand)
		return
	if not form_allows("melee"): return
	if weapon == null or weapon.light_attack == null: return
	if not attributes.meets(weapon.requirements):
		show_message("Weapon requirements not met")
		return
	_attack_candidate_hand = hand
	_active_hand = hand
	_attack_hold_time = 0.0
	_active_attack = weapon.light_attack
	action_time = 0.0
	sprinting = false
	state = PlayerState.ATTACK_HOLD

func release_hand_action(hand: StringName) -> void:
	release_spell_input(hand)
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
	_attack_hold_time = 0.0
	_active_attack = null
	if state in [PlayerState.ATTACK_HOLD, PlayerState.CHARGING]: state = PlayerState.NORMAL
	charge_changed.emit(_active_hand, 0.0)

func get_charge_progress(hand: StringName) -> float:
	if hand != _active_hand: return 0.0
	if state == PlayerState.CHARGING: return 1.0
	if state != PlayerState.ATTACK_HOLD or _active_attack == null: return 0.0
	return clampf(_attack_hold_time / maxf(0.01, _active_attack.charge_threshold), 0.0, 1.0)

func _start_attack(hand: StringName, definition: AttackDefinition) -> void:
	if not form_allows("melee"): return
	if definition == null: _cancel_attack_candidate(); return
	if not state in [PlayerState.NORMAL, PlayerState.ATTACK_HOLD, PlayerState.CHARGING]: return
	if not _can_spend_stamina(definition.stamina_cost):
		show_message("Catch your breath", 0.7)
		_cancel_attack_candidate()
		return
	_spend_stamina(definition.stamina_cost, false)
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
	Feedback.play(String(definition.swing_sound), global_position, 0.0, self)
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
	if not form_allows("dodge") and (transformation.definition == null or not transformation.definition.allow_sprint): return
	cancel_spell_channel()
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
		reset_control_holds()
		cancel_spell_channel()
		_right_held = false
		_left_held = false
		_mobile_movement = Vector2.ZERO
		_hold_time = 0.0
		_buffer = ""
		_cancel_attack_candidate()

func _unhandled_input(event: InputEvent) -> void:
	if not _session_ready: return
	if is_instance_valid(transformation) and transformation.handle_zoom_input(event):
		get_viewport().set_input_as_handled()
		return
	# Touch can be emulated as mouse input by Android. The dedicated mobile
	# controls call the player API directly, so ignore those synthetic clicks.
	if _mobile_controls_active and event is InputEventMouseButton: return
	if event.is_action_pressed("cycle_right"): cycle_weapon(&"right")
	if event.is_action_pressed("cycle_left"): cycle_weapon(&"left")
	if event.is_action_pressed("cycle_spell"): cycle_spell()
	if event.is_action_pressed("cycle_utility"): cycle_utility()
	if state == PlayerState.DEAD: return
	if event.is_action_pressed("light_right"): request_light_attack(&"right")
	if event.is_action_pressed("light_left"): request_light_attack(&"left")
	if event.is_action_released("light_right"): release_spell_input(&"right")
	if event.is_action_released("light_left"): release_spell_input(&"left")
	if event.is_action_pressed("attack"): begin_hand_action(&"right")
	if event.is_action_pressed("left_attack"): begin_hand_action(&"left")
	if event.is_action_released("attack"): release_hand_action(&"right")
	if event.is_action_released("left_attack"): release_hand_action(&"left")
	if event.is_action_pressed("dodge"): begin_dodge_sprint_hold()
	if event.is_action_released("dodge"): release_dodge_sprint_hold()
	if event.is_action_pressed("cast_spell"): use_selected_spell()
	if event.is_action_released("cast_spell"): release_spell_input()
	if event.is_action_pressed("spell_command"): command_orbiters()
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

func form_allows(permission: String) -> bool:
	if not _session_ready: return false
	return not is_instance_valid(transformation) or transformation.allows(permission)

var _engagement_frame: int = -1
var _engagement_cached: bool = false

func in_combat() -> bool:
	if state == PlayerState.DEAD or health <= 0: return false
	# Lock-on alone is not aggression, and an enemy fighting another actor must not
	# charge this player's stamina. Enemies expose their engagement explicitly.
	var frame: int = Engine.get_physics_frames()
	if frame != _engagement_frame:
		_engagement_frame = frame
		_engagement_cached = false
		for enemy: Node2D in ActorRegistry.registered():
			if enemy.is_queued_for_deletion() or not enemy.is_in_group("enemy"): continue
			if enemy.has_method("is_engaged_with") and enemy.call("is_engaged_with", self):
				_engagement_cached = true
				break
	if _engagement_cached:
		_combat_time = movement.combat_exit_delay
		return true
	return _combat_time > 0.0

func note_combat_damage(opponent: Node) -> void:
	# Called by receivers only after accepted damage; misses/dummies do not count.
	if state == PlayerState.DEAD or not is_instance_valid(opponent): return
	if opponent.is_in_group("enemy"):
		_combat_time = maxf(_combat_time, movement.combat_exit_delay)

func _can_spend_stamina(cost: float) -> bool:
	return not in_combat() or stamina >= maxf(0.0, cost)

func _spend_stamina(cost: float, delay_regeneration: bool = true) -> void:
	if cost <= 0.0 or not in_combat(): return
	stamina = maxf(0.0, stamina - cost)
	if delay_regeneration: _regen_delay = vitals.stamina_regeneration_delay
	stamina_changed.emit(stamina)

func uses_ground_locomotion() -> bool:
	if state not in [PlayerState.NORMAL, PlayerState.ATTACK_HOLD, PlayerState.CHARGING, PlayerState.ATTACKING, PlayerState.CASTING, PlayerState.USING_UTILITY]: return false
	# A movement spell owns its displacement; it is not a walking animation.
	return _active_spell == null or not _active_spell.delivery_definition is DashDelivery

func _move_attack_candidate() -> void:
	var multiplier: float = _active_attack.movement_multiplier if _active_attack != null else 1.0
	_move_action_velocity(multiplier, get_physics_process_delta_time())
	var look: Vector2 = aim_direction()
	if absf(look.x) > 0.04: facing = signf(look.x)
	Elevation.slide(self, get_physics_process_delta_time())

func _move_action_velocity(multiplier: float, delta: float) -> void:
	var desired: Vector2 = movement_input() * speed * multiplier
	var braking: bool = desired.length_squared() < velocity.length_squared() or velocity.dot(desired) < 0.0
	velocity = velocity.move_toward(desired, (movement.deceleration if braking else movement.acceleration) * delta)

func aim_direction() -> Vector2:
	if valid_target(locked_target):
		var locked_vector: Vector2 = target_point(locked_target) - global_position
		if locked_vector.length() > 4.0: return locked_vector.normalized()
	if _mobile_controls_active:
		if _mobile_aim.length() > 0.12: return _mobile_aim.normalized()
		return Vector2(facing, 0)
	if gamepad_active: return _stick_aim
	var point: Vector2 = get_global_mouse_position()
	var vector: Vector2 = point - global_position
	return vector.normalized() if vector.length() > 4.0 else Vector2(facing, 0)

func request_action(action: String) -> void:
	if action == "dodge" and not form_allows("dodge"): return
	if action == "dodge":
		cancel_spell_channel()
	if state == PlayerState.DEAD: return
	if state in [PlayerState.ATTACK_HOLD, PlayerState.CHARGING] and action == "dodge":
		_cancel_attack_candidate()
	if state != PlayerState.NORMAL:
		var duration: float = dodge_duration if state == PlayerState.DODGING else attack_duration
		if state in [PlayerState.ATTACKING, PlayerState.DODGING] and duration - action_time <= movement.input_buffer:
			_buffer = action
			_buffer_time = movement.input_buffer
		return
	if action.begins_with("light_"):
		request_light_attack(StringName(action.trim_prefix("light_")))
		return
	if action != "dodge" or _cooldown > 0.0: return
	if not _can_spend_stamina(dodge_cost):
		if _denied_timer <= 0.0:
			show_message("Catch your breath", 0.7)
			_denied_timer = 0.7
		return
	_spend_stamina(dodge_cost)
	action_time = 0.0
	sprinting = false
	aim = aim_direction()
	if absf(aim.x) > 0.05: facing = signf(aim.x)
	state = PlayerState.DODGING
	dodge_direction = movement_input()
	if dodge_direction.is_zero_approx(): dodge_direction = -aim if gamepad_active else aim
	dodge_direction = dodge_direction.normalized()
	_cooldown = dodge_cooldown
	_roll_trail_time = 0.0
	visuals.movement_effect("dodge", to_global(Vector2(0, 10)), -dodge_direction)
	Feedback.play("roll", global_position, 0.0, self)
	visuals.begin("roll")

func _physics_process(delta: float) -> void:
	if not _session_ready: return
	_combat_time = maxf(0.0, _combat_time - delta)
	var combat_active: bool = in_combat()
	if not combat_active: _sprint_exhausted = false
	transformation.tick(delta)
	_update_gamepad_aim()
	if state != PlayerState.CASTING: _clear_cast_vfx()
	if is_instance_valid(_cast_vfx) and is_instance_valid(visuals):
		var catalyst_model: Node2D = visuals.get_hand_model(_active_hand)
		if is_instance_valid(catalyst_model): _cast_vfx.global_position = visuals.cast_socket(_active_hand)
	_poise_delay = maxf(0, _poise_delay - delta)
	if _poise_delay <= 0: poise_remaining = minf(vitals.poise, poise_remaining + vitals.poise_regeneration * delta)
	_cooldown = maxf(0, _cooldown - delta)
	_protection = maxf(0, _protection - delta)
	_denied_timer = maxf(0, _denied_timer - delta)
	_utility_cooldown = maxf(0, _utility_cooldown - delta)
	message_time = maxf(0, message_time - delta)
	if is_instance_valid(locked_target) and not valid_target(locked_target): set_target(null)
	if not is_instance_valid(locked_target): locked_target = null
	if _right_held: _hold_time += delta
	if not _attack_candidate_hand.is_empty(): _attack_hold_time += delta
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
			var form: TransformationDefinition = transformation.definition
			if form != null and not form.preserve_transition_movement and transformation.phase in [PlayerTransformation.Phase.ENTERING, PlayerTransformation.Phase.REVERTING]: move = Vector2.ZERO
			var locomotion: MovementDefinition = form.movement if form != null else movement
			sprinting = _right_held and _hold_time >= locomotion.sprint_hold_threshold and not move.is_zero_approx() and not _sprint_exhausted
			if form != null and not form.allow_sprint: sprinting = false
			if sprinting and combat_active:
				_spend_stamina(locomotion.sprint_stamina_per_second * delta)
				if stamina <= 0:
					_sprint_exhausted = true
					sprinting = false
			var target_speed: float = locomotion.walk_speed
			if sprinting: target_speed = form.sprint_speed if form != null else locomotion.walk_speed * locomotion.sprint_multiplier
			var desired_velocity: Vector2 = move * target_speed * SpellEffects.movement(self)
			var braking: bool = desired_velocity.length_squared() < velocity.length_squared() or velocity.dot(desired_velocity) < 0.0
			var rate: float = locomotion.deceleration if braking else locomotion.acceleration
			velocity = velocity.move_toward(desired_velocity, rate * delta)
			var look: Vector2 = aim_direction()
			if absf(look.x) > 0.04: facing = signf(look.x)
			Elevation.slide(self, get_physics_process_delta_time())
		PlayerState.ATTACK_HOLD:
			_move_attack_candidate()
			if _active_attack != null and _attack_hold_time >= _active_attack.charge_threshold:
				state = PlayerState.CHARGING
				charge_changed.emit(_active_hand, 1.0)
			elif _active_attack != null:
				charge_changed.emit(_active_hand, get_charge_progress(_active_hand))
		PlayerState.CHARGING:
			_move_attack_candidate()
			charge_changed.emit(_active_hand, 1.0)
		PlayerState.ATTACKING:
			_move_action_velocity(attack.movement_multiplier, delta)
			Elevation.slide(self, get_physics_process_delta_time())
			if action_time >= attack.windup and action_time - delta < attack.active_end(): _attack_hits()
			if action_time >= attack_duration: _finish_action()
		PlayerState.CASTING:
			var delivery: SpellDeliveryDefinition = _active_spell.delivery_definition
			var multiplier: float = float(delivery.get("movement_multiplier")) if delivery != null and delivery.is_channel() else _active_attack.movement_multiplier
			_move_action_velocity(multiplier, delta)
			if not delivery is DashDelivery: Elevation.slide(self, get_physics_process_delta_time())
			if not _spell_launched and action_time >= _active_attack.windup:
				_cast_active_spell()
			if delivery != null and (delivery.is_channel() or delivery is DashDelivery):
				if _spell_launched and (not is_instance_valid(_delivery_runtime) or _delivery_runtime.is_queued_for_deletion()):
					if _spell_delivery_ended_at < 0:
						_spell_delivery_ended_at = action_time
						_channel_input = &""
					if action_time - _spell_delivery_ended_at >= _active_attack.recovery: _finish_action()
			elif action_time >= _active_attack.duration(): _finish_action()
		PlayerState.USING_UTILITY:
			if _active_utility == null:
				_finish_action()
				return
			_move_action_velocity(_active_utility.movement_multiplier, delta)
			Elevation.slide(self, delta)
			if not _utility_released and action_time >= _active_utility.use_time: _release_utility()
			if action_time >= _active_utility.use_time + _active_utility.recovery_time: _finish_action()
		PlayerState.DODGING:
			var p: float = clampf(action_time / dodge_duration, 0, 1)
			velocity = dodge_direction * dodge_distance / dodge_duration * (1.45 - 0.9 * p)
			Elevation.slide(self, get_physics_process_delta_time())
			_roll_trail_time += delta
			if _roll_trail_time >= 0.13 and not Feedback.reduced_effects:
				_roll_trail_time = 0.0
				visuals.movement_effect("wake", to_global(Vector2(0, 10)), -dodge_direction)
			if action_time >= dodge_duration:
				visuals.movement_effect("settle", to_global(Vector2(0, 10)), -dodge_direction)
				Feedback.play("step", global_position, -3, self)
				_finish_action()
		PlayerState.HURT:
			velocity = velocity.move_toward(Vector2.ZERO, delta * vitals.knockback_deceleration * WorldScale.actor_scale(self))
			Elevation.slide(self, get_physics_process_delta_time())
			if action_time >= vitals.stagger_duration: _finish_action()
		PlayerState.DEAD:
			velocity = Vector2.ZERO
	var distance: float = global_position.distance_to(previous)
	if uses_ground_locomotion() and transformation.phase == PlayerTransformation.Phase.HUMAN:
		travel += distance
		_step_distance += distance
		var step_spacing: float = visuals.current_step_distance()
		if _step_distance > step_spacing:
			_step_distance = fmod(_step_distance, step_spacing)
			Feedback.play("step", global_position, -8, self)
			visuals.movement_effect("sprint" if sprinting else "footstep", to_global(Vector2(0, 13)), -velocity.normalized())
	# Exploration can regenerate while moving/acting, without resetting the bar or
	# consuming stamina. Combat retains its normal idle/walking regeneration rules.
	if state != PlayerState.DEAD and _regen_delay <= 0 and (not in_combat() or (state == PlayerState.NORMAL and not sprinting)):
		stamina = minf(max_stamina, stamina + vitals.stamina_regeneration * delta)
	stamina_changed.emit(stamina)
	var nearby: Node2D = nearby_interactable()
	interaction_changed.emit(("Y / Triangle   " if gamepad_active else "E   ") + str(nearby.get_interaction_prompt()) if nearby != null else "")

func _finish_action() -> void:
	var keep_movement: bool = uses_ground_locomotion()
	_channel_input = &""
	_clear_cast_vfx()
	state = PlayerState.NORMAL
	action_time = 0.0
	if not keep_movement: velocity = Vector2.ZERO
	_active_attack = null
	_active_spell = null
	_active_utility = null
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
	# Melee resources describe a unit-scale actor. Physics queries are world-space
	# and do not inherit the player's scene scale, unlike its body and equipment.
	# Convert once here for every weapon, either hand and light/charged attacks.
	# Basis lengths include parent scale and remain positive when mirrored; the
	# larger axis keeps the circular query conservative for non-uniform scaling.
	var spatial_scale: float = WorldScale.actor_scale(self)
	var world_reach: float = attack.reach * spatial_scale
	var shape := CircleShape2D.new()
	shape.radius = minf(attack.hit_radius, attack.reach) * spatial_scale
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(0, global_position + aim * maxf(0.0, world_reach - shape.radius))
	query.collision_mask = 2
	for result: Dictionary in Elevation.shapes(self, query, Elevation.level(self), 32, attack.cross_elevations):
		var target: Node = result.collider
		if _hits.has(target.get_instance_id()) or not target.has_method("take_damage") or not target.has_method("is_targetable"): continue
		if not target.is_targetable(): continue
		var offset: Vector2 = (target as Node2D).global_position - global_position
		if not offset.is_zero_approx() and aim.dot(offset.normalized()) < cos(deg_to_rad(attack.arc_degrees * 0.5)): continue
		_hits[target.get_instance_id()] = true
		var outcome: HitResult = HitRequest.deliver(target as Node2D, SpellEffects.of(self).imbue_attack(CharacterProgression.attack(attack, self, _active_hand), weapon_token(_active_hand)), attributes, self, true)
		if outcome.accepted and attack.feedback == null:
			hit_stop = attack.hit_stop
			shake = attack.camera_shake

func use_selected_spell(hand: StringName = &"") -> void:
	if not form_allows("spells"): return
	if state != PlayerState.NORMAL: return
	if spells.is_empty():
		show_message("No spells equipped")
		return
	var spell: SpellDefinition = get_selected_spell()
	if spell == null or spell.cast == null:
		show_message("No spell equipped")
		return
	if not spell.is_basic() and (spell_charges.size() <= spell_index or spell_charges[spell_index] <= 0):
		show_message("No uses remaining")
		return
	var catalyst: WeaponDefinition = get_spell_catalyst(spell) if hand.is_empty() else get_selected_weapon(hand)
	if catalyst == null or not catalyst.is_spell_catalyst:
		show_message("Select a " + spell.school + " catalyst with Q/R (Wand casts all)")
		return
	if spell.is_basic() and catalyst.basic_spell != spell:
		show_message("This basic spell belongs to the other catalyst")
		return
	if not attributes.meets(catalyst.requirements) or (not catalyst.catalyst_schools.is_empty() and not catalyst.catalyst_schools.has(spell.school)):
		show_message("This catalyst cannot cast " + spell.school)
		return
	if hand == &"left" and not catalyst.usable_in_left_hand: return
	if hand == &"right" and not catalyst.usable_in_right_hand: return
	if spell.delivery_definition == null:
		show_message("Choose a spell delivery definition")
		return
	if not attributes.meets(spell.requirements):
		show_message("Spell requirements not met")
		return
	if not _can_spend_stamina(spell.cast.stamina_cost):
		show_message("Catch your breath", 0.7)
		return
	_delivery_context = null
	if spell.delivery_definition != null:
		var error: String = SpellDeliveryService.validated(spell.delivery_definition)
		if not error.is_empty():
			show_message(error)
			return
		_delivery_context = SpellCastContext.new()
		_delivery_context.caster = self
		_delivery_context.elevation = Elevation.level(self)
		_delivery_context.cross_elevations = spell.delivery_definition.cross_elevations
		_delivery_context.attribution = self
		_delivery_context.target = locked_target
		_delivery_context.direction = aim_direction()
		_delivery_context.hand = hand if not hand.is_empty() else (&"right" if get_selected_weapon(&"right") == catalyst else &"left")
		_delivery_context.attributes = attributes.duplicate(true) as AttributeStats
		_delivery_context.attack = CharacterProgression.attack(spell.cast, self, _delivery_context.hand)
		_delivery_context.upgrade_multiplier = CharacterProgression.multiplier(self, _delivery_context.hand)
		_delivery_context.profile = spell.delivery_definition.vfx
		_delivery_context.ownership = spell.id
		var delivery: SpellDeliveryDefinition = spell.delivery_definition
		var desired: Vector2 = get_global_mouse_position() if not (_mobile_controls_active or gamepad_active) else global_position + aim_direction() * delivery.placement_distance
		if valid_target(locked_target): desired = locked_target.global_position
		desired = global_position + (desired - global_position).limit_length(delivery.cast_range)
		_delivery_context.point = SpellDeliveryService.wall_end(_delivery_context, global_position, desired)
		_delivery_context.point -= (desired - global_position).normalized() * minf(WorldScale.art_distance(14), global_position.distance_to(_delivery_context.point))
		if delivery is ZoneDelivery or delivery is TrapDelivery or delivery is BarrageDelivery or delivery is SummonDelivery:
			if not SpellDeliveryService.placement_clear(_delivery_context, _delivery_context.point):
				show_message("No clear spell placement")
				return
		if delivery is TargetDelivery or delivery is ChainDelivery or delivery is TetherDelivery:
			var needs_sight: bool = bool(delivery.get("require_line_of_sight")) if not delivery is TetherDelivery else true
			var target_range: float = minf(delivery.cast_range, delivery.break_range) if delivery is TetherDelivery else delivery.cast_range
			if not valid_target(locked_target) or global_position.distance_to(locked_target.global_position) > target_range or (needs_sight and not SpellDeliveryService.visible(_delivery_context, global_position, locked_target.global_position)):
				show_message("A visible target in cast range is required")
				return
		if delivery is TetherDelivery and delivery.drain_definition() != null:
			if locked_target.get("max_health") == null or float(locked_target.get("max_health")) <= 0 or not locked_target.has_method("receive_hit"):
				show_message("Target cannot receive maximum-health damage")
				return
		if delivery is ImbueDelivery:
			var recipient: StringName = StringName(delivery.recipient)
			if recipient == &"opposite": recipient = &"left" if _delivery_context.hand == &"right" else &"right"
			var enchanted: WeaponDefinition = get_selected_weapon(recipient)
			if enchanted == null or enchanted.is_spell_catalyst:
				show_message("Equip a weapon in the imbue's recipient hand")
				return
			_delivery_context.weapon_token = weapon_token(recipient)
		_channel_input = (hand if not hand.is_empty() else &"cast") if delivery.is_channel() else &""
	if not spell.is_basic():
		spell_charges[spell_index] -= 1
		_spell_use_pool[spell.id] = spell_charges[spell_index]
	_active_spell = spell
	_active_attack = CharacterProgression.attack(spell.cast, self, _delivery_context.hand)
	_active_hand = hand if not hand.is_empty() else (&"right" if get_selected_weapon(&"right") == catalyst else &"left")
	_spell_launched = false
	_spell_delivery_ended_at = -1.0
	_attack_candidate_hand = &""
	_spend_stamina(spell.cast.stamina_cost)
	loadout_changed.emit(&"spell", spell_index)
	aim = aim_direction()
	if absf(aim.x) > 0.05: facing = signf(aim.x)
	action_time = 0.0
	sprinting = false
	state = PlayerState.CASTING
	visuals.begin("RESET")
	var catalyst_model: Node2D = visuals.get_hand_model(_active_hand)
	var cast_origin: Vector2 = visuals.cast_socket(_active_hand)
	_cast_vfx = Feedback.spell_effect(cast_origin, spell.delivery_definition.vfx, &"cast", catalyst_model if is_instance_valid(catalyst_model) else self, WorldScale.art_distance(20), spell.cast.windup, get_instance_id())
	show_message(spell.display_name, spell.cast.duration())

func spell_visual_origin(hand: StringName) -> Vector2:
	if not is_instance_valid(visuals): return global_position
	var model: Node2D = visuals.get_hand_model(hand)
	return visuals.socket_position(model, &"Cast")

func _cast_active_spell() -> void:
	if _active_spell == null or _spell_launched: return
	_spell_launched = true
	_clear_cast_vfx()
	if _active_spell.delivery_definition == null or _delivery_context == null: return
	# A windup accepted on a different floor cannot release through its ceiling.
	if _delivery_context.elevation != Elevation.level(self): return
	if _active_spell.health_restore > 0:
		health = mini(max_health, health + _active_spell.health_restore)
		health_changed.emit(health, max_health)
	if _active_spell.stamina_restore > 0:
		stamina = minf(max_stamina, stamina + _active_spell.stamina_restore)
		stamina_changed.emit(stamina)
	_delivery_context.origin = global_position
	_delivery_runtime = SpellDeliveryService.launch(_active_spell.delivery_definition, _delivery_context)
	var profile: VFXDefinition = _active_spell.delivery_definition.vfx
	if profile != null: Feedback.present(profile.release_feedback, global_position, aim_direction(), self)
	Feedback.play(String(_active_spell.cast.swing_sound), global_position, 0.0, self)

func use_selected_utility() -> void:
	# Always permit this button to attempt reversion, even if the form forbids items.
	if transformation.phase != PlayerTransformation.Phase.HUMAN:
		transformation.toggle(transformation.definition)
		return
	if not form_allows("utilities"): return
	if state != PlayerState.NORMAL or utilities.is_empty() or _utility_cooldown > 0.0: return
	var utility: UtilityDefinition = utilities[utility_index]
	if utility != null and utility.transformation != null:
		transformation.toggle(utility.transformation)
		return
	if utility == null or utility_charges[utility_index] <= 0:
		show_message("No charges remaining")
		return
	utility_charges[utility_index] -= 1
	_active_utility = utility
	_utility_released = false
	action_time = 0.0
	sprinting = false
	state = PlayerState.USING_UTILITY
	visuals.begin("RESET")
	loadout_changed.emit(&"utility", utility_index)

func _release_utility() -> void:
	if _active_utility == null or _utility_released or state != PlayerState.USING_UTILITY: return
	_utility_released = true
	health = mini(max_health, health + _active_utility.health_restore)
	stamina = minf(max_stamina, stamina + _active_utility.stamina_restore)
	health_changed.emit(health, max_health)
	stamina_changed.emit(stamina)
	show_message(_active_utility.display_name)
	Feedback.play(String(_active_utility.sound_key), global_position, 0.0, self)
	if _active_utility.vfx != null:
		var effect: Node2D = Feedback.custom_effect(_active_utility.vfx, global_position, 5.0, 1.0)
		if is_instance_valid(effect):
			effect.set_meta("spell_owner", get_instance_id())
			effect.add_to_group("spell_visuals")
			Elevation.register_visual(effect, self)

func receive_hit(incoming: AttackDefinition, attacker_stats: AttributeStats, source: Node) -> HitResult:
	if incoming == null: return HitResult.reject(&"missing_attack")
	var rejected: StringName = hit_rejection(source, incoming)
	if not rejected.is_empty(): return HitResult.reject(rejected)
	return _apply_damage(incoming.health_damage(attacker_stats, SpellEffects.defence(self, vitals.defence)), source, incoming.poise_damage, incoming.knockback, incoming.hit_stop, incoming.camera_shake, incoming, attacker_stats)

## Compatibility entry point: direct, unmitigated damage.
func take_damage(amount: int, source: Node) -> void:
	_apply_damage(maxi(0, amount), source, vitals.poise, 180.0, 0.04, 5.0)

func hit_rejection(source: Node, incoming: AttackDefinition = null) -> StringName:
	if not _session_ready: return &"restoring_session"
	if not Elevation.accepts_hit(self, source, incoming): return &"elevation"
	if state == PlayerState.DEAD or health <= 0: return &"dead"
	if _protection > 0 and (incoming == null or not incoming.accepted_contact_child): return &"invulnerable"
	if is_instance_valid(_delivery_runtime) and not _delivery_runtime.is_queued_for_deletion() and _delivery_runtime.get("definition") is DashDelivery:
		var dash: DashDelivery = _delivery_runtime.get("definition")
		var fraction: float = float(_delivery_runtime.get("elapsed")) / dash.duration
		if dash.invulnerable and fraction >= dash.invulnerability_start and fraction <= dash.invulnerability_end: return &"invulnerable"
	if state == PlayerState.DODGING and action_time >= dodge_duration * movement.invulnerability_start and action_time <= dodge_duration * maxf(movement.invulnerability_start, movement.invulnerability_end): return &"invulnerable"
	return &""

func _apply_damage(amount: int, source: Node, poise_damage: float, knockback: float, freeze: float, camera_kick: float, incoming: AttackDefinition = null, attacker_stats: AttributeStats = null) -> HitResult:
	var rejected: StringName = hit_rejection(source, incoming)
	if not rejected.is_empty(): return HitResult.reject(rejected)
	var outcome := HitResult.accept(mini(amount, health))
	if amount <= 0 and (incoming == null or incoming.max_health_drain == null): return HitResult.reject(&"no_damage")
	if amount > 0: note_combat_damage(source)
	if health > amount and SpellEffects.apply_attack(self, incoming, attacker_stats, source):
		outcome.applied_effects.append(incoming.max_health_drain.id)
	if amount == 0: return outcome if not outcome.applied_effects.is_empty() else HitResult.reject(&"no_effect")
	if incoming != null and incoming.feedback != null and not incoming.recurring_feedback:
		freeze = incoming.feedback.hit_stop
		camera_kick = 0.0
	Feedback.damage_number(self, mini(amount, health))
	health = maxi(0, health - amount)
	health_changed.emit(health, max_health)
	damaged.emit()
	if incoming == null or not incoming.periodic_damage: _protection = vitals.damage_invulnerability
	poise_remaining -= poise_damage
	_poise_delay = vitals.poise_regeneration_delay
	var staggered: bool = poise_remaining <= 0.0
	if staggered: poise_remaining = vitals.poise
	if state == PlayerState.ATTACKING and action_time >= attack.windup and action_time <= attack.active_end() and attack.uninterruptible_while_active:
		staggered = false
	if incoming == null or not incoming.periodic_damage:
		shake = camera_kick
		hit_stop = freeze
	if staggered:
		_buffer = ""
		action_time = 0
		var origin: Vector2 = (source as Node2D).global_position if is_instance_valid(source) and source is Node2D else global_position - Vector2.RIGHT
		velocity = (global_position - origin).normalized() * knockback * WorldScale.actor_scale(self)
	if incoming == null or not incoming.periodic_damage: Feedback.play("hurt", global_position, 0.0, self)
	if health == 0: Feedback.clear_physical_effects(get_instance_id())
	if amount > 0: Feedback.hit_effect(global_position, source, EnemyDefinition.HitSurface.FLESH, incoming, amount, self)
	if incoming == null or not incoming.periodic_damage: visuals.flash = 1.0
	if health == 0:
		_active_utility = null
		_combat_time = 0.0
		transformation.clear()
		state = PlayerState.DEAD
		cancel_spell_channel()
		if is_instance_valid(Feedback.presentation): Feedback.presentation.clear()
		SpellDeliveryService.clear_owned(self)
		SpellEffects.of(self).clear()
		_clear_cast_vfx()
		state = PlayerState.DEAD
		_spawn_currency_drop()
		set_target(null)
		visuals.begin("death")
		visuals.movement_effect("death", to_global(Vector2(0, 10)), Vector2.UP)
		Feedback.play("death", global_position, 0.0, self)
		died.emit()
	elif staggered:
		_active_utility = null
		state = PlayerState.HURT
		cancel_spell_channel()
		_clear_cast_vfx()
		state = PlayerState.HURT
		visuals.begin("hurt")
	outcome.staggered = staggered
	outcome.killed = health == 0
	return outcome

func restore(restore_health: bool = true, restore_stamina: bool = true, _unused: bool = true) -> void:
	if transformation.phase != PlayerTransformation.Phase.HUMAN:
		if not transformation.can_land():
			show_message("Find clear ground before resting")
			return
		transformation.clear()
	Feedback.clear_physical_effects(get_instance_id())
	cancel_spell_channel()
	SpellDeliveryService.clear_owned(self)
	for actor: Node in get_tree().get_nodes_in_group("targetable"):
		var effects := actor.get_node_or_null("SpellEffects") as SpellEffects
		if effects != null: effects.clear()
		var statuses := actor.get_node_or_null("ActorStatuses") as ActorStatuses
		if statuses != null: statuses.clear()
	SpellEffects.of(self).clear()
	if restore_health: health = max_health
	if restore_stamina: stamina = max_stamina
	_combat_time = 0.0
	_sprint_exhausted = false
	_active_utility = null
	for i in utilities.size(): utility_charges[i] = utilities[i].maximum_charges if utilities[i] != null else 0
	if GameSession.character != null:
		for identity: String in GameSession.character.known_utilities:
			var utility := GameSession.definition(&"utilities", StringName(identity)) as UtilityDefinition
			if utility != null: GameSession.character.utility_pool[identity] = utility.maximum_charges
	for key: Variant in _spell_use_pool:
		var rested_spell := GameSession.definition(&"spells", StringName(key)) as SpellDefinition
		if rested_spell != null: _spell_use_pool[key] = rested_spell.maximum_charges
	for i in spells.size():
		spell_charges[i] = (-1 if spells[i].is_basic() else spells[i].maximum_charges) if spells[i] != null else 0
		if spells[i] != null and not spells[i].is_basic(): _spell_use_pool[spells[i].id] = spell_charges[i]
	poise_remaining = vitals.poise
	_poise_delay = 0.0
	_protection = 0
	health_changed.emit(health, max_health)
	stamina_changed.emit(stamina)

func add_currency(amount: int, feedback_message: String = "") -> void:
	current_currency = maxi(0, current_currency + amount)
	currency_changed.emit(current_currency)
	if not feedback_message.is_empty(): show_message(feedback_message)
	GameSession.queue_save()

func _spawn_currency_drop() -> void:
	GameSession.record_death()

func clear_camera_feedback() -> void:
	shake = 0.0
	if is_instance_valid(camera):
		camera.zoom = _base_camera_zoom * (transformation.zoom_factor if is_instance_valid(transformation) else 1.0)
		camera.offset = _camera_bias

func _process(delta: float) -> void:
	if not is_instance_valid(transformation): return
	transformation.update_camera_zoom(delta)
	_update_camera(delta)

func _update_camera(delta: float) -> void:
	var desired: Vector2 = aim_direction() * 16.0 + velocity * 0.025
	if valid_target(locked_target): desired = (target_point(locked_target) - global_position).limit_length(65) * 0.45
	if transformation.definition != null:
		desired = velocity * transformation.definition.camera_lead * (transformation.definition.sprint_camera_lead_multiplier if sprinting else 1.0)
	_camera_bias = _camera_bias.lerp(desired, 1.0 - exp(-delta * 4))
	shake = move_toward(shake, 0, delta * 24)
	var legacy_strength: float = shake * Feedback.shake_strength * (0.2 if Feedback.reduced_effects else 1.0)
	camera.offset = _camera_bias + Vector2(sin(Feedback.effect_clock * 90), cos(Feedback.effect_clock * 120)) * legacy_strength
	camera.zoom = _base_camera_zoom * transformation.zoom_factor
	if is_instance_valid(Feedback.presentation):
		camera.offset += Feedback.presentation.offset
		camera.zoom *= Feedback.presentation.zoom_factor

func target_point(target: Node2D) -> Vector2:
	return target.get_target_point() if target.has_method("get_target_point") else target.global_position

func valid_target(target: Node2D) -> bool:
	if not is_instance_valid(target) or not target.is_inside_tree(): return false
	if not Elevation.compatible(self, target): return false
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
	if state == PlayerState.DEAD: return
	if valid_target(locked_target):
		set_target(null)
		return
	var options: Array[Node2D] = candidates()
	if options.is_empty():
		show_message("No enemy within lock-on range", 1.0)
		return
	options.sort_custom(func(a: Node2D, b: Node2D) -> bool: return global_position.distance_squared_to(target_point(a)) < global_position.distance_squared_to(target_point(b)))
	set_target(options[0])

func cycle_target(step: int) -> void:
	if state == PlayerState.DEAD: return
	var options: Array[Node2D] = candidates()
	options.sort_custom(func(a: Node2D, b: Node2D) -> bool: return (target_point(a) - global_position).angle() < (target_point(b) - global_position).angle())
	if options.is_empty():
		return
	set_target(options[posmod(options.find(locked_target) + step, options.size())])

func nearby_interactable() -> Node2D:
	if not form_allows("interaction"): return null
	if state != PlayerState.NORMAL: return null
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
	return Elevation.compatible(self, target) and target.is_in_group("interactable") and global_position.distance_to(target_point(target)) <= interaction_radius and target.has_method("can_interact") and target.can_interact(self)

func has_traversal_tag(tag: StringName) -> bool:
	return is_instance_valid(transformation) and transformation.definition != null and transformation.definition.traversal_tags.has(tag)

func on_elevation_changed(_previous: int, _current: int) -> void:
	if not valid_target(locked_target): set_target(null)
	if state == PlayerState.CASTING:
		cancel_spell_channel()
		if state == PlayerState.CASTING: _finish_action()

func can_world_interact() -> bool:
	return is_inside_tree() and not get_tree().paused and health > 0 and state == PlayerState.NORMAL and form_allows("interaction")

func interact_nearby() -> void:
	if not can_world_interact(): return
	var target: Node2D = nearby_interactable()
	if target != null: target.interact(self)

func show_message(text: String, duration: float = 1.8) -> void:
	message = text
	message_time = duration
