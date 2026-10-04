class_name SettingsPanel
extends PanelContainer
signal closed
var waiting: String = ""
var notice := Label.new()
var rows := VBoxContainer.new()
var sliders: Dictionary = {}
var toggles: Dictionary = {}
var binding_buttons: Dictionary = {}
var waiting_button: Button

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	theme = GameTheme.get_theme()
	GameSettings.settings_changed.connect(_refresh_values)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	offset_left = 32; offset_top = 24; offset_right = -32; offset_bottom = -24
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(rows)
	var title := Label.new()
	title.text = "PRESENTATION & CONTROLS"
	rows.add_child(title)
	notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rows.add_child(notice)
	for key: String in ["Master", "Effects", "Ambience", "Music", "shake", "ui_scale"]:
		var label := Label.new()
		label.text = "Screen Shake intensity" if key == "shake" else key.replace("_", " ").capitalize()
		rows.add_child(label)
		var slider := HSlider.new()
		slider.min_value = 0.75 if key == "ui_scale" else 0.0
		slider.max_value = 1.5 if key == "ui_scale" else 1.0
		slider.step = 0.05
		slider.value = float(GameSettings.values[key])
		slider.value_changed.connect(func(value: float) -> void: GameSettings.change(key, value))
		sliders[key] = slider
		rows.add_child(slider)
	for key: String in ["reduced_effects", "blood", "vibration"]:
		var toggle := CheckButton.new()
		toggle.text = key.replace("_", " ").capitalize()
		toggle.button_pressed = bool(GameSettings.values[key])
		toggle.toggled.connect(func(value: bool) -> void: GameSettings.change(key, value))
		toggles[key] = toggle
		rows.add_child(toggle)
	for action: String in GameSettings.REBINDABLE:
		if not InputMap.has_action(action): continue
		var button := Button.new()
		button.text = action.replace("_", " ").capitalize() + " — " + GameSettings.prompt(action)
		button.pressed.connect(func() -> void:
			waiting = action
			waiting_button = button
			notice.text = "Press the new input for " + action.replace("_", " ") + ". Escape cancels."
			button.release_focus())
		binding_buttons[action] = button
		rows.add_child(button)
	var reset := Button.new()
	reset.text = "Reset Defaults"
	reset.pressed.connect(func() -> void: GameSettings.reset_defaults(); notice.text = "Defaults restored.")
	rows.add_child(reset)
	var back := Button.new()
	back.text = "Back"
	back.pressed.connect(_close)
	rows.add_child(back)
	back.grab_focus()
	_refresh_values()

func _refresh_values() -> void:
	for key: String in sliders:
		(sliders[key] as HSlider).set_value_no_signal(float(GameSettings.values[key]))
	for key: String in toggles:
		(toggles[key] as CheckButton).set_pressed_no_signal(bool(GameSettings.values[key]))
	for action: String in binding_buttons:
		var button: Button = binding_buttons[action]
		button.text = action.replace("_", " ").capitalize() + " — " + GameSettings.prompt(action) + " / " + GameSettings.prompt(action, true)

func _finish_binding() -> void:
	waiting = ""
	if is_instance_valid(waiting_button): waiting_button.grab_focus()
	waiting_button = null

func _input(event: InputEvent) -> void:
	if not visible: return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):
		if not waiting.is_empty(): _finish_binding(); notice.text = "Rebinding cancelled."
		else: _close()
		get_viewport().set_input_as_handled()
		return
	if waiting.is_empty(): return
	if event is InputEventMouseMotion: return
	if event is InputEventJoypadMotion and absf(event.axis_value) < 0.7: return
	if not event.is_pressed() and not event is InputEventJoypadMotion: return
	notice.text = GameSettings.rebind(waiting, event)
	_finish_binding()
	get_viewport().set_input_as_handled()

func _close() -> void:
	GameSettings.flush()
	closed.emit()
	queue_free()
