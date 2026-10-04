class_name ShrineServices
extends PanelContainer
var body: VBoxContainer
var message: Label
var page: String = "Level"
var draft: AttributeStats
var utilities: Array[String] = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	theme = GameTheme.get_theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	offset_left = 28
	offset_top = 28
	offset_right = -28
	offset_bottom = -28
	draft = GameSession.actor.attributes.duplicate(true) as AttributeStats
	utilities.assign(GameSession.character.prepared_utilities)
	utilities.resize(4)
	var main := VBoxContainer.new()
	add_child(main)
	var title := Label.new()
	title.text = "RENEW THE VOW"
	title.add_theme_font_size_override("font_size", 28)
	main.add_child(title)
	var tabs := HBoxContainer.new()
	main.add_child(tabs)
	for category: String in ["Level", "Respec", "Upgrade", "Utilities", "Travel"]:
		_button(tabs, category, func() -> void: page = category; _render())
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	main.add_child(scroll)
	body = VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(body)
	message = Label.new()
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	main.add_child(message)
	_button(main, "Back to preparation", queue_free)
	_render()

func _button(parent: Node, text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.pressed.connect(callback)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(button)
	return button

func _label(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(label)

func _render() -> void:
	for child: Node in body.get_children():
		body.remove_child(child)
		child.queue_free()
	var state: CharacterState = GameSession.character
	var actor: PlayerController = GameSession.actor
	var rules: ProgressionDefinition = CharacterProgression.RULES
	_label("Level %d    •    %d Embers    •    %d %ss" % [state.level, actor.current_currency, int(state.materials.get(String(rules.material_id), 0)), rules.material_name])
	match page:
		"Level":
			_label("One attribute point costs %d Embers. Choose an attribute to commit." % rules.level_cost(state.level))
			for key: String in CharacterState.ATTRIBUTES:
				_button(body, "%s  %d  →  %d" % [key.capitalize(), actor.attributes.get(key), mini(99, int(actor.attributes.get(key)) + 1)], func() -> void:
					message.text = CharacterProgression.level_attribute(key)
					draft = actor.attributes.duplicate(true) as AttributeStats
					_render())
		"Respec":
			var earned: int = state.level - actor.character_class.starting_level
			var assigned: int = 0
			for key: String in CharacterState.ATTRIBUTES: assigned += int(draft.get(key)) - int(actor.character_class.attributes.get(key))
			_label("Free respec: %d / %d earned points assigned. Your level and spent Embers are retained." % [assigned, earned])
			for key: String in CharacterState.ATTRIBUTES:
				var row := HBoxContainer.new()
				body.add_child(row)
				_button(row, "−", func() -> void: draft.set(key, maxi(int(actor.character_class.attributes.get(key)), int(draft.get(key)) - 1)); _render())
				var label := Label.new()
				label.text = "%s: %d" % [key.capitalize(), draft.get(key)]
				label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				row.add_child(label)
				_button(row, "+", func() -> void:
					if assigned < earned: draft.set(key, mini(rules.attribute_cap, int(draft.get(key)) + 1))
					_render())
			_button(body, "Apply redistribution", func() -> void: message.text = CharacterProgression.respec(draft); _render())
		"Upgrade":
			_label("Upgrades belong to this item, not every copy. Catalyst upgrades improve ordinary spell damage; percentage burns and healing are unchanged.")
			for item: EquipmentInstance in state.equipment:
				var weapon: WeaponDefinition = GameSession.weapon(item.id)
				if weapon == null: continue
				var next: int = item.upgrade_level + 1
				var text: String = "%s +%d → +%d    %d Embers / %d shards" % [weapon.display_name, item.upgrade_level, next, rules.upgrade_cost(next), rules.material_cost(next)]
				text += "\nOrdinary damage ×%.2f → ×%.2f" % [1.0 + item.upgrade_level * rules.damage_per_upgrade, 1.0 + mini(next, rules.maximum_upgrade) * rules.damage_per_upgrade]
				var button: Button = _button(body, text, func() -> void: message.text = CharacterProgression.upgrade(item.id); _render())
				button.disabled = item.upgrade_level >= rules.maximum_upgrade
		"Utilities":
			_label("Prepare consumables and transformations. The same utility cannot occupy two slots.")
			for index in 4:
				var choices := OptionButton.new()
				choices.add_item("Slot %d — Empty" % (index + 1))
				choices.set_item_metadata(0, "")
				for identity: String in state.known_utilities:
					var utility := GameSession.definition(&"utilities", StringName(identity)) as UtilityDefinition
					if utility == null: continue
					choices.add_item(utility.display_name)
					choices.set_item_metadata(choices.item_count - 1, identity)
					if utilities[index] == identity: choices.select(choices.item_count - 1)
				choices.item_selected.connect(func(choice: int) -> void: utilities[index] = String(choices.get_item_metadata(choice)))
				body.add_child(choices)
			_button(body, "Prepare utilities", func() -> void: message.text = "Utilities prepared." if GameSession.prepare_utilities(utilities) else "Choose unique owned utilities.")
		"Travel":
			_label("Only attuned shrines are available. Travel rests and resets the destination's encounters.")
			for identity: String in state.attuned_shrines:
				var shrine: Dictionary = state.attuned_shrines[identity]
				_button(body, String(shrine.get("name", identity)), func() -> void: message.text = GameSession.travel(identity))
	if OS.is_debug_build() and bool(ProjectSettings.get_setting("debug/content/catalogue_mode", false)):
		_button(body, "Development: acquire catalogue (saved character)", func() -> void: GameSession.grant_development_catalogue(); _render())
	var controls: Array[Node] = find_children("*", "Button", true, false)
	for i in controls.size():
		var control := controls[i] as Button
		control.focus_neighbor_top = control.get_path_to(controls[posmod(i - 1, controls.size())])
		control.focus_neighbor_bottom = control.get_path_to(controls[(i + 1) % controls.size()])
	if not controls.is_empty(): (controls[0] as Button).call_deferred("grab_focus")
