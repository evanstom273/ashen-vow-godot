extends CanvasLayer
@export var area_title: String = "THE OUTER COURT"
@export var area_subtitle: String = "Where the embers remember"
var player: PlayerController
var root: Control
var health_bar: ProgressBar
var damage_bar: ProgressBar
var stamina_bar: ProgressBar
var target_bar: ProgressBar
var prompt: Label
var feedback: Label
var target_name: Label
var title: VBoxContainer
var help_panel: PanelContainer
var menu: PanelContainer
var menu_title: Label
var resume_button: Button
var respawn_button: Button
var slot_buttons: Array[Button] = []
var atmosphere: ShaderMaterial
var elapsed: float = 0
var death_time: float = 0
var damage_delay: float = 0
var currency_label: Label
var mobile_controls: MobileControls
var shrine_loadout_menu: ShrineLoadoutMenu
var world_navigation: WorldNavigationUI
var controls_hint: Label
var help_text: Label
var _controller_prompts: bool = false
var settings_panel: SettingsPanel

func _ready() -> void:
	layer = 50
	process_mode = Node.PROCESS_MODE_ALWAYS
	player = get_tree().get_first_node_in_group("player")
	root = Control.new()
	root.theme = GameTheme.get_theme()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	GameSettings.settings_changed.connect(_apply_ui_scale)
	get_viewport().size_changed.connect(_apply_ui_scale)
	_apply_ui_scale()
	var veil := ColorRect.new()
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	atmosphere = ShaderMaterial.new()
	atmosphere.shader = load("res://shaders/atmosphere.gdshader")
	veil.material = atmosphere
	root.add_child(veil)
	var portrait := PanelContainer.new()
	portrait.position = Vector2(28,24)
	portrait.custom_minimum_size = Vector2(48,48)
	var portrait_style := StyleBoxFlat.new()
	portrait_style.bg_color = Color(0.025,0.04,0.045,0.96)
	portrait_style.border_color = Color("a99661")
	portrait_style.set_border_width_all(2)
	portrait_style.set_corner_radius_all(22)
	portrait.add_theme_stylebox_override("panel",portrait_style)
	root.add_child(portrait)
	var status := VBoxContainer.new()
	status.position = Vector2(88,27)
	status.add_theme_constant_override("separation",7)
	root.add_child(status)
	status.add_child(_label("ASHEN WANDERER",12,Color("d9c79f")))
	var health_stack := Control.new()
	health_stack.custom_minimum_size = Vector2(242,13)
	status.add_child(health_stack)
	damage_bar = _bar(Color("b69763"),Vector2(242,13))
	health_stack.add_child(damage_bar)
	health_bar = _bar(Color("ad514b"),Vector2(242,13))
	health_bar.get_theme_stylebox("background").bg_color = Color.TRANSPARENT
	health_stack.add_child(health_bar)
	stamina_bar = _bar(Color("8d9d72"),Vector2(200,7))
	status.add_child(stamina_bar)
	controls_hint = _label("",11,Color("929b98"))
	if MobileControls.should_enable(): controls_hint.text = "TOUCH CONTROLS"
	status.add_child(controls_hint)
	var status_effects := ActorStatusDisplay.new()
	status_effects.actor = player
	status_effects.position = Vector2(88, 113)
	root.add_child(status_effects)
	var onboarding := PlayerOnboarding.new()
	onboarding.actor = player
	player.add_child(onboarding)
	currency_label = _label("Embers  0",13,Color("e6b968"))
	currency_label.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	currency_label.offset_left = -150
	currency_label.offset_top = -44
	currency_label.offset_right = -28
	currency_label.offset_bottom = -20
	root.add_child(currency_label)
	var prompt_back := _panel()
	root.add_child(prompt_back)
	prompt_back.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	prompt_back.position = Vector2(-270,-74)
	prompt_back.custom_minimum_size = Vector2(540,56)
	var bottom := VBoxContainer.new()
	root.add_child(bottom)
	bottom.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	bottom.position += Vector2(-230,-88)
	bottom.custom_minimum_size = Vector2(460,70)
	feedback = _label("",17,Color("d2c49f"))
	prompt = _label("",16,Color("d8e0cf"))
	feedback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bottom.add_child(feedback)
	bottom.add_child(prompt)
	var equipment := Control.new()
	equipment.name = "EquipmentCross"
	equipment.set_script(preload("res://scripts/equipment_cross.gd"))
	equipment.set("player", player)
	root.add_child(equipment)
	equipment.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	equipment.offset_left = 28
	equipment.offset_top = -186
	equipment.offset_right = 194
	equipment.offset_bottom = -20
	if MobileControls.should_enable():
		mobile_controls = preload("res://scenes/mobile_controls.tscn").instantiate() as MobileControls
		mobile_controls.player = player
		mobile_controls.pause_requested.connect(func() -> void:
			if player.health > 0 and (shrine_loadout_menu == null or not shrine_loadout_menu.visible):
				_pause(not menu.visible))
		root.add_child(mobile_controls)
	var target_box := VBoxContainer.new()
	root.add_child(target_box)
	target_box.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	target_box.position += Vector2(-130,110)
	target_name = _label("",13,Color("c7bc9b"))
	target_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	target_box.add_child(target_name)
	target_bar = _bar(Color("b08059"),Vector2(260,5))
	target_box.add_child(target_bar)
	title = VBoxContainer.new()
	root.add_child(title)
	title.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	title.position += Vector2(-230,-130)
	title.custom_minimum_size = Vector2(460,80)
	var heading := _label(area_title,30,Color("d9d0b4"))
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_child(heading)
	var subtitle := _label(area_subtitle,14,Color("99aaa8"))
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_child(subtitle)
	help_panel = _panel()
	root.add_child(help_panel)
	help_panel.position = Vector2(32,130)
	help_text = _label("", 12, Color("ccd1bf"))
	help_panel.position.y = 40
	help_panel.add_child(help_text)
	GameSettings.settings_changed.connect(_refresh_prompts)
	_refresh_prompts()
	help_panel.visible = false
	_build_menu()
	shrine_loadout_menu = preload("res://scenes/shrine_loadout_menu.tscn").instantiate() as ShrineLoadoutMenu
	root.add_child(shrine_loadout_menu)
	shrine_loadout_menu.closed.connect(_close_shrine_loadout)
	player.shrine_menu_requested.connect(_open_shrine_loadout)
	player.damaged.connect(func() -> void: damage_delay = 0.45)
	player.interaction_changed.connect(func(text: String) -> void: prompt.text = text)
	# Below the full-screen map; ignores pointer input and samples independently.
	var fps_counter := preload("res://scripts/fps_counter.gd").new()
	fps_counter.name = "FPSCounter"
	root.add_child(fps_counter)
	world_navigation = WorldNavigationUI.new()
	world_navigation.player = player
	root.add_child(world_navigation)
	world_navigation.map_toggled.connect(func(open: bool) -> void:
		help_panel.hide()
		if is_instance_valid(mobile_controls): mobile_controls.set_controls_enabled(not open))

func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size",font_size)
	label.add_theme_color_override("font_color",color)
	label.add_theme_color_override("font_shadow_color",Color(0,0,0,0.6))
	label.add_theme_constant_override("shadow_offset_y",2)
	return label

func _bar(color: Color, dimensions: Vector2) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.custom_minimum_size = dimensions
	bar.size = dimensions
	bar.show_percentage = false
	bar.value = 100
	var back := StyleBoxFlat.new()
	back.bg_color = Color("17242b")
	back.border_color = Color("6c6b59")
	back.set_border_width_all(1)
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	bar.add_theme_stylebox_override("background",back)
	bar.add_theme_stylebox_override("fill",fill)
	return bar

func _panel() -> PanelContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.045,0.075,0.09,0.96)
	style.border_color = Color("80765a")
	style.set_border_width_all(1)
	style.content_margin_left = 24
	style.content_margin_right = 24
	style.content_margin_top = 20
	style.content_margin_bottom = 20
	panel.add_theme_stylebox_override("panel",style)
	return panel

func _build_menu() -> void:
	menu = _panel()
	root.add_child(menu)
	menu.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	menu.position += Vector2(-190,-215)
	menu.custom_minimum_size = Vector2(380,430)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(332, 386)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	menu.add_child(scroll)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation",12)
	scroll.add_child(box)
	menu_title = _label("A MOMENT OF REST",22,Color("d9c79f"))
	menu_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(menu_title)
	resume_button = _button("Resume",func() -> void: _pause(false))
	box.add_child(resume_button)
	respawn_button = _button("Return to last shrine", func() -> void: GameSession.respawn())
	box.add_child(respawn_button)
	box.add_child(_button("Save character", func() -> void: GameSession.save_now()))
	box.add_child(_button("Settings & rebind controls", func() -> void:
		if is_instance_valid(settings_panel): return
		settings_panel = preload("res://scenes/settings_panel.tscn").instantiate() as SettingsPanel
		menu.hide()
		settings_panel.closed.connect(func() -> void:
			menu.show()
			resume_button.call_deferred("grab_focus"))
		root.add_child(settings_panel)))
	box.add_child(_button("Return to title", func() -> void:
		if GameSession.development_session or GameSession.save_now():
			UIFlow.clear()
			GameSession.leave_development_session()
			get_tree().change_scene_to_file("res://scenes/title_screen.tscn")))
	box.add_child(_button("New Game (empty slot)", func() -> void: GameSession.new_character()))
	for index in range(1, 4):
		var load_button: Button = _button("Continue - slot %d" % index, GameSession.load_slot.bind(index))
		load_button.disabled = not FileAccess.file_exists(GameSession.slot_path(index)) and not FileAccess.file_exists(GameSession.slot_path(index) + ".bak")
		slot_buttons.append(load_button)
		box.add_child(load_button)
	# Presentation controls live in the shared SettingsPanel, not a second copy.
	menu.visible = false

func _button(text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 34
	button.pressed.connect(callback)
	return button

func _open_shrine_loadout() -> void:
	if not is_instance_valid(player) or player.health <= 0: return
	if not UIFlow.acquire(shrine_loadout_menu): return
	menu.visible = false
	help_panel.visible = false
	player.reset_control_holds()
	if is_instance_valid(mobile_controls): mobile_controls.set_controls_enabled(false)
	shrine_loadout_menu.open_for(player)

func _close_shrine_loadout(_applied: bool) -> void:
	UIFlow.release(shrine_loadout_menu)
	GameSession.save_now()
	if is_instance_valid(mobile_controls): mobile_controls.set_controls_enabled(true)
	prompt.text = ""

func _pause(value: bool) -> void:
	if value and not UIFlow.acquire(menu): return
	if value:
		player.reset_control_holds()
		for index in slot_buttons.size():
			slot_buttons[index].disabled = not FileAccess.file_exists(GameSession.slot_path(index + 1)) and not FileAccess.file_exists(GameSession.slot_path(index + 1) + ".bak")
	if not value: UIFlow.release(menu)
	menu.visible = value
	player._right_held = false
	if value: resume_button.grab_focus()

func _input(event: InputEvent) -> void:
	if event is InputEventJoypadButton or (event is InputEventJoypadMotion and absf(event.axis_value) > 0.3):
		if not _controller_prompts: _controller_prompts = true; _refresh_prompts()
	elif event is InputEventKey or event is InputEventMouseButton:
		if _controller_prompts: _controller_prompts = false; _refresh_prompts()
	if is_instance_valid(settings_panel): return
	if is_instance_valid(world_navigation) and world_navigation.handle_input(event): return
	if is_instance_valid(shrine_loadout_menu) and shrine_loadout_menu.handle_menu_input(event):
		return
	if event.is_action_pressed("ui_cancel") and get_tree().paused:
		if shrine_loadout_menu.visible: shrine_loadout_menu.cancel()
		elif player.health > 0: _pause(false)
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("pause") and is_instance_valid(shrine_loadout_menu) and shrine_loadout_menu.visible:
		shrine_loadout_menu.cancel()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("pause") and player.health > 0:
		_pause(not menu.visible)
		get_viewport().set_input_as_handled()
	if event.is_action_pressed("help"):
		help_panel.visible = not help_panel.visible
		get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	if not is_instance_valid(player): return
	if not get_tree().paused: elapsed += delta
	title.modulate.a = smoothstep(0,0.6,elapsed) * (1-smoothstep(2.5,4.5,elapsed))
	title.visible = elapsed < 4.5
	health_bar.value = lerpf(health_bar.value,float(player.health)/player.max_health*100,1-exp(-delta*18))
	damage_delay = maxf(0,damage_delay-delta)
	if damage_delay == 0: damage_bar.value = move_toward(damage_bar.value,health_bar.value,delta*40)
	stamina_bar.value = lerpf(stamina_bar.value,player.stamina/player.max_stamina*100.0,1-exp(-delta*20))
	currency_label.text = (player.currency_definition.display_name if player.currency_definition != null else "Embers") + "  " + str(player.current_currency)
	stamina_bar.modulate = Color("ffb9a0") if player._denied_timer > 0 else Color.WHITE
	feedback.text = player.message if player.message_time > 0 else player.delivery_status()
	var target: Node2D = player.locked_target
	target_bar.visible = is_instance_valid(target) and target.get("health") != null and target.is_targetable()
	target_name.text = ""
	if is_instance_valid(target):
		target_name.text = String(target.get_display_name()).to_upper() if target.has_method("get_display_name") else String(target.name).to_upper()
		if target_bar.visible: target_bar.value = lerpf(target_bar.value,float(target.health)/target.max_health*100,1-exp(-delta*12))
	var response: float = Feedback.presentation.hud_strength if is_instance_valid(Feedback.presentation) else 0.0
	health_bar.modulate = Color.WHITE.lerp(Color(1.4, 1.15, 1.1), response)
	if player.health <= 0 and not menu.visible:
		death_time += delta
		if death_time > 1.3:
			menu_title.text = "YOUR EMBER FADES"
			resume_button.visible = false
			_pause(true)
			respawn_button.grab_focus()

func _apply_ui_scale() -> void:
	if not is_instance_valid(root): return
	var factor: float = clampf(float(GameSettings.values.ui_scale), 0.75, 1.5)
	# Scale only the CanvasLayer content; gameplay zoom and world units never change.
	root.set_anchors_preset(Control.PRESET_TOP_LEFT)
	root.scale = Vector2.ONE * factor
	root.size = get_viewport().get_visible_rect().size / factor


func _refresh_prompts() -> void:
	if not is_instance_valid(controls_hint) or not is_instance_valid(help_text): return
	controls_hint.text = GameSettings.prompt("help", _controller_prompts) + ": controls   ESC / Menu: pause"
	var rows := PackedStringArray()
	for pair: Array in [["move_up", "Move forward"], ["attack", "Right hand"], ["left_attack", "Left hand"], ["dodge", "Tap dodge / hold sprint"], ["cast_spell", "Cast selected spell"], ["use_utility", "Use utility / transform"], ["cycle_right", "Cycle right weapon"], ["cycle_left", "Cycle left weapon"], ["cycle_spell", "Cycle spell"], ["cycle_utility", "Cycle utility"], ["lock_on", "Lock enemy"], ["interact", "Interact / rest"], ["spell_command", "Command orbiters"], ["world_map", "World map"]]:
		rows.append(GameSettings.prompt(pair[0], _controller_prompts) + "   " + pair[1])
	rows.append("F11   Fullscreen\nMenus: directions navigate / confirm / back")
	help_text.text = "\n".join(rows)
