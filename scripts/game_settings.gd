extends Node
## Persistent presentation preferences. Runtime Resources remain untouched.
const PATH: String = "user://settings.json"
# Keep Feedback's existing -15 dB ambience mix on a fresh installation.
const DEFAULTS: Dictionary = {"Master": 1.0, "Effects": 1.0, "Ambience": 0.177827941,
	"Music": 0.6, "ui_scale": 1.0, "reduced_effects": false, "blood": true, "shake": 1.0, "vibration": true}
signal settings_changed
var bindings: Dictionary = {}
var default_events: Dictionary = {}
const REBINDABLE: Array[String] = ["move_left", "move_right", "move_up", "move_down", "attack", "left_attack", "light_right", "light_left", "dodge", "cycle_right", "cycle_left", "cycle_spell", "cycle_utility", "cast_spell", "use_utility", "interact", "lock_on", "target_previous", "target_next", "spell_command", "world_map", "help"]
var values: Dictionary = DEFAULTS.duplicate(true)
var _dirty: bool = false
var _save_delay: float = 0.0
var _can_save: bool = true

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if InputMap.has_action("world_map"):
		var map_button := InputEventJoypadButton.new()
		map_button.button_index = JOY_BUTTON_BACK
		InputMap.action_add_event("world_map", map_button)
	for action: String in REBINDABLE:
		if InputMap.has_action(action): default_events[action] = InputMap.action_get_events(action)
	var saved: Dictionary = SaveStore.read_document(PATH, _valid_settings)
	_can_save = not saved.is_empty() or SaveStore.last_error.is_empty()
	for key: String in DEFAULTS:
		if saved.has(key): values[key] = saved[key]
	bindings = saved.get("bindings", {}).duplicate(true)
	_apply_bindings()
	apply()

static func _valid_settings(record: Dictionary) -> bool:
	for key: String in DEFAULTS:
		if not record.has(key): continue # Older settings gain new defaults, not corruption.
		var value: Variant = record[key]
		if DEFAULTS[key] is bool:
			if not value is bool: return false
		elif not (value is int or value is float) or not is_finite(float(value)): return false
	var saved_bindings: Variant = record.get("bindings", {})
	if not saved_bindings is Dictionary or saved_bindings.size() > 64: return false
	for action: Variant in saved_bindings:
		if not action is String or action not in REBINDABLE or not saved_bindings[action] is Array: return false
		if saved_bindings[action].size() > 16: return false
		for event: Variant in saved_bindings[action]:
			if not event is Dictionary or event.get("kind", "") not in ["key", "mouse", "button", "axis"]: return false
			if not event.get("code") is float and not event.get("code") is int: return false
			if not is_finite(float(event.code)) or float(event.code) < 0 or float(event.code) > 100000000: return false
			if float(event.code) != floorf(float(event.code)): return false
			if event.kind == "axis":
				var direction: Variant = event.get("sign", 1.0)
				if not (direction is int or direction is float) or absf(float(direction)) != 1.0: return false
				if int(event.code) >= JOY_AXIS_MAX: return false
			elif event.kind == "button" and int(event.code) >= JOY_BUTTON_MAX: return false
			elif event.kind == "mouse" and (int(event.code) < 1 or int(event.code) > MOUSE_BUTTON_XBUTTON2): return false
	return true

func change(key: String, value: Variant) -> void:
	if not DEFAULTS.has(key): return
	if DEFAULTS[key] is bool and not value is bool: return
	if DEFAULTS[key] is float:
		if not (value is float or value is int) or not is_finite(float(value)): return
		value = clampf(float(value), 0.75, 1.5) if key == "ui_scale" else clampf(float(value), 0.0, 1.0)
	values[key] = value
	apply()
	_dirty = true
	_save_delay = 0.5

func reset_defaults() -> void:
	values = DEFAULTS.duplicate(true)
	bindings.clear()
	for action: String in default_events:
		InputMap.action_erase_events(action)
		for event: InputEvent in default_events[action]: InputMap.action_add_event(action, event)
	apply()
	# Reset is explicit user intent; SaveStore still refuses a newer schema.
	_can_save = true
	_dirty = true
	flush()

func _process(delta: float) -> void:
	if not _dirty: return
	_save_delay -= delta
	if _save_delay <= 0.0: flush()

func flush() -> void:
	if not _dirty: return
	_dirty = false
	var record: Dictionary = values.duplicate(true)
	record["bindings"] = bindings
	if _can_save: SaveStore.write_document(PATH, record, _valid_settings)

func apply() -> void:
	for bus: String in ["Master", "Effects", "Ambience", "Music"]:
		var index: int = AudioServer.get_bus_index(bus)
		if index >= 0: AudioServer.set_bus_volume_db(index, linear_to_db(clampf(float(values[bus]), 0.0001, 1.0)))
	Feedback.reduced_effects = bool(values.reduced_effects)
	Feedback.blood_enabled = bool(values.blood)
	if not Feedback.blood_enabled: Feedback.clear_blood()
	Feedback.shake_strength = clampf(float(values.shake), 0.0, 1.0)
	if not bool(values.vibration):
		for device: int in Input.get_connected_joypads(): Input.stop_joy_vibration(device)
	settings_changed.emit()

func rebind(action: String, event: InputEvent) -> String:
	if action not in REBINDABLE or not InputMap.has_action(action): return "Unsupported action."
	var encoded: Dictionary = _encode(event)
	if encoded.is_empty(): return "Choose a key, mouse button, controller button or trigger."
	var gamepad: bool = event is InputEventJoypadButton or event is InputEventJoypadMotion
	for other: String in REBINDABLE:
		if other == action or not InputMap.has_action(other): continue
		if InputMap.action_has_event(other, event): return "Already assigned to " + other.replace("_", " ") + ". Rebind that action first."
	var kept: Array[Dictionary] = []
	for old: InputEvent in InputMap.action_get_events(action):
		var old_gamepad: bool = old is InputEventJoypadButton or old is InputEventJoypadMotion
		if old_gamepad != gamepad: kept.append(_encode(old))
	kept.append(encoded)
	bindings[action] = kept
	_apply_bindings()
	_dirty = true
	_save_delay = 0.2
	settings_changed.emit()
	return action.capitalize() + " assigned."

func _encode(event: InputEvent) -> Dictionary:
	if event is InputEventKey: return {"kind": "key", "code": event.physical_keycode if event.physical_keycode != 0 else event.keycode}
	if event is InputEventMouseButton: return {"kind": "mouse", "code": event.button_index}
	if event is InputEventJoypadButton: return {"kind": "button", "code": event.button_index}
	if event is InputEventJoypadMotion: return {"kind": "axis", "code": event.axis, "sign": 1.0 if event.axis_value > 0 else -1.0}
	return {}

func _apply_bindings() -> void:
	for action: String in bindings:
		if not InputMap.has_action(action): continue
		InputMap.action_erase_events(action)
		for record: Dictionary in bindings[action]:
			var event: InputEvent
			match str(record.kind):
				"key":
					var key := InputEventKey.new()
					key.physical_keycode = int(record.code) as Key
					event = key
				"mouse":
					var mouse := InputEventMouseButton.new()
					mouse.button_index = int(record.code) as MouseButton
					event = mouse
				"button":
					var button := InputEventJoypadButton.new()
					button.button_index = int(record.code) as JoyButton
					event = button
				"axis":
					var axis := InputEventJoypadMotion.new()
					axis.axis = int(record.code) as JoyAxis
					axis.axis_value = signf(float(record.get("sign", 1.0)))
					event = axis
			if event != null: InputMap.action_add_event(action, event)

func prompt(action: String, controller: bool = false) -> String:
	if not InputMap.has_action(action): return action
	for event: InputEvent in InputMap.action_get_events(action):
		if (event is InputEventJoypadButton or event is InputEventJoypadMotion) == controller: return event.as_text()
	return action.replace("_", " ")
