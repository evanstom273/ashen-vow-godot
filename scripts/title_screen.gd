extends Control
var message := Label.new()
var settings: SettingsPanel
var settings_button: Button

func _ready() -> void:
	theme = GameTheme.get_theme()
	GameSettings.settings_changed.connect(_layout)
	get_viewport().size_changed.connect(_layout)
	_layout()
	var background := ColorRect.new()
	background.color = Color("0b1212")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var woodland := TextureRect.new()
	woodland.texture = preload("res://assets/illustrated/tree_0_2.svg")
	woodland.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	woodland.anchor_left = 0.45
	woodland.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	woodland.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	woodland.modulate = Color(0.55, 0.65, 0.55, 0.42)
	woodland.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(woodland)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "right", "top", "bottom"]: margin.add_theme_constant_override("margin_" + side, 44)
	add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	margin.add_child(scroll)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(box)
	var title := TextureRect.new()
	title.texture = preload("res://assets/illustrated/ashen_vow_wordmark.svg")
	title.custom_minimum_size = Vector2(0, 96)
	title.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	title.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	title.tooltip_text = "Ashen Vow"
	box.add_child(title)
	message.text = "The embers remember."
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(message)
	var continue_button: Button = _button(box, "Continue", func() -> void:
		if GameSession.character != null: get_tree().change_scene_to_file(GameSession._resume_scene()))
	continue_button.disabled = GameSession.character == null
	_button(box, "New Game — unused character slot", func() -> void:
		if not GameSession.new_character(): message.text = "No unused slot, or the current save could not be written. Existing characters were preserved.")
	for index in range(1, 4):
		var record: Dictionary = SaveStore.read_document(GameSession.slot_path(index), GameSession._valid_character_record)
		var caption: String = "Slot %d — Level %d · %d Embers" % [index, int(record.get("level", 1)), int(record.get("currency", 0))] if not record.is_empty() else "Slot %d — empty or unreadable" % index
		var button: Button = _button(box, caption, func() -> void:
			if not GameSession.load_slot(index): message.text = "Could not load that character. The save was not overwritten.")
		button.disabled = record.is_empty()
	settings_button = _button(box, "Settings & controls", _open_settings)
	_button(box, "Quit", func() -> void: GameSettings.flush(); get_tree().quit())
	if not continue_button.disabled: continue_button.grab_focus()
	else: box.get_child(3).grab_focus()

func _button(parent: Node, caption: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = caption
	button.pressed.connect(callback)
	parent.add_child(button)
	return button

func _open_settings() -> void:
	if is_instance_valid(settings): return
	var panel := preload("res://scenes/settings_panel.tscn").instantiate() as SettingsPanel
	if not UIFlow.acquire(panel):
		panel.free()
		return
	settings = panel
	panel.closed.connect(func() -> void:
		UIFlow.release(panel)
		settings = null
		settings_button.call_deferred("grab_focus"))
	add_child(panel)

func _layout() -> void:
	var factor: float = clampf(float(GameSettings.values.ui_scale), 0.75, 1.5)
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	scale = Vector2.ONE * factor
	size = get_viewport_rect().size / factor
