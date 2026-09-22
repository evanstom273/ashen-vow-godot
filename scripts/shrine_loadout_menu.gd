class_name ShrineLoadoutMenu
extends Control

signal closed(applied: bool)

const CATALOG: GameDataCatalog = preload("res://data/game_catalog.tres")
const GOLD := Color("a79871")
const GOLD_BRIGHT := Color("e9c472")
const TEXT := Color("e7e0cc")
const MUTED := Color("9c9a8c")
const PANEL := Color(0.035, 0.052, 0.055, 0.985)

var player: PlayerController
var _section: StringName = &"right"
var _selected_slot: int = 0
var _draft_right: Array[WeaponDefinition] = []
var _draft_left: Array[WeaponDefinition] = []
var _draft_spells: Array[SpellDefinition] = []

var _slot_box: VBoxContainer
var _available_box: VBoxContainer
var _details_title: Label
var _details_body: Label
var _section_title: Label
var _capacity_label: Label
var _tab_buttons: Dictionary = {}

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    mouse_filter = Control.MOUSE_FILTER_STOP
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _build_ui()
    visible = false

func open_for(target: PlayerController) -> void:
    player = target
    _copy_drafts()
    _section = &"right"
    _selected_slot = 0
    visible = true
    _refresh_all()

func cancel() -> void:
    if not visible: return
    visible = false
    closed.emit(false)

func _apply_and_close() -> void:
    if not is_instance_valid(player): return
    player.set_weapon_loadout(&"right", _draft_right)
    player.set_weapon_loadout(&"left", _draft_left)
    player.set_spell_loadout(_draft_spells)
    player.show_message("Loadout prepared", 1.4)
    visible = false
    closed.emit(true)

func _copy_drafts() -> void:
    _draft_right.clear()
    _draft_left.clear()
    _draft_spells.clear()
    for item: WeaponDefinition in player.right_hand_weapons: _draft_right.append(item)
    for item: WeaponDefinition in player.left_hand_weapons: _draft_left.append(item)
    for item: SpellDefinition in player.spells: _draft_spells.append(item)
    _resize_weapon_draft(_draft_right, player.get_weapon_slot_capacity(&"right"))
    _resize_weapon_draft(_draft_left, player.get_weapon_slot_capacity(&"left"))
    _resize_spell_draft(_draft_spells, player.get_spell_slot_capacity())

func _resize_weapon_draft(items: Array[WeaponDefinition], capacity: int) -> void:
    while items.size() > capacity: items.pop_back()
    while items.size() < capacity: items.append(null)

func _resize_spell_draft(items: Array[SpellDefinition], capacity: int) -> void:
    while items.size() > capacity: items.pop_back()
    while items.size() < capacity: items.append(null)

func _build_ui() -> void:
    var backdrop := ColorRect.new()
    backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    backdrop.color = Color(0.005, 0.008, 0.009, 0.80)
    backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
    add_child(backdrop)

    var frame := PanelContainer.new()
    frame.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
    frame.position = Vector2(-430, -270)
    frame.custom_minimum_size = Vector2(860, 540)
    frame.add_theme_stylebox_override("panel", _panel_style())
    add_child(frame)

    var main := VBoxContainer.new()
    main.add_theme_constant_override("separation", 12)
    frame.add_child(main)

    var eyebrow := _label("ASHEN SHRINE", 11, GOLD, HORIZONTAL_ALIGNMENT_CENTER)
    main.add_child(eyebrow)
    var heading := _label("PREPARE LOADOUT", 26, TEXT, HORIZONTAL_ALIGNMENT_CENTER)
    main.add_child(heading)
    var sub := _label("Choose what you carry into the courtyard. Changes apply when confirmed.", 12, MUTED, HORIZONTAL_ALIGNMENT_CENTER)
    main.add_child(sub)

    var tabs := HBoxContainer.new()
    tabs.add_theme_constant_override("separation", 8)
    main.add_child(tabs)
    _add_tab(tabs, &"right", "RIGHT HAND")
    _add_tab(tabs, &"left", "LEFT HAND")
    _add_tab(tabs, &"spell", "SPELLS")

    var section_header := HBoxContainer.new()
    main.add_child(section_header)
    _section_title = _label("RIGHT HAND", 16, GOLD_BRIGHT)
    _section_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    section_header.add_child(_section_title)
    _capacity_label = _label("", 11, MUTED, HORIZONTAL_ALIGNMENT_RIGHT)
    section_header.add_child(_capacity_label)

    var columns := HBoxContainer.new()
    columns.custom_minimum_size = Vector2(0, 320)
    columns.add_theme_constant_override("separation", 14)
    columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
    main.add_child(columns)

    var slots_panel := PanelContainer.new()
    slots_panel.custom_minimum_size = Vector2(280, 0)
    slots_panel.add_theme_stylebox_override("panel", _inner_style())
    columns.add_child(slots_panel)
    var slots_wrap := VBoxContainer.new()
    slots_wrap.add_theme_constant_override("separation", 8)
    slots_panel.add_child(slots_wrap)
    slots_wrap.add_child(_label("EQUIPPED SLOTS", 11, MUTED))
    _slot_box = VBoxContainer.new()
    _slot_box.add_theme_constant_override("separation", 7)
    slots_wrap.add_child(_slot_box)

    var available_panel := PanelContainer.new()
    available_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    available_panel.add_theme_stylebox_override("panel", _inner_style())
    columns.add_child(available_panel)
    var available_wrap := VBoxContainer.new()
    available_wrap.add_theme_constant_override("separation", 7)
    available_panel.add_child(available_wrap)
    available_wrap.add_child(_label("AVAILABLE", 11, MUTED))
    var scroll := ScrollContainer.new()
    scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    available_wrap.add_child(scroll)
    _available_box = VBoxContainer.new()
    _available_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _available_box.add_theme_constant_override("separation", 5)
    scroll.add_child(_available_box)

    var details := PanelContainer.new()
    details.custom_minimum_size = Vector2(230, 0)
    details.add_theme_stylebox_override("panel", _inner_style())
    columns.add_child(details)
    var details_wrap := VBoxContainer.new()
    details_wrap.add_theme_constant_override("separation", 8)
    details.add_child(details_wrap)
    details_wrap.add_child(_label("DETAILS", 11, MUTED))
    _details_title = _label("Empty slot", 17, TEXT)
    details_wrap.add_child(_details_title)
    _details_body = _label("", 11, Color("c5c4b6"))
    _details_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    _details_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
    details_wrap.add_child(_details_body)

    var actions := HBoxContainer.new()
    actions.alignment = BoxContainer.ALIGNMENT_END
    actions.add_theme_constant_override("separation", 10)
    main.add_child(actions)
    actions.add_child(_button("DISCARD", cancel, Vector2(132, 40)))
    actions.add_child(_button("APPLY & RETURN", _apply_and_close, Vector2(190, 40), true))

func _add_tab(parent: HBoxContainer, section: StringName, text: String) -> void:
    var button := _button(text, _set_section.bind(section), Vector2(0, 38))
    button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    parent.add_child(button)
    _tab_buttons[section] = button

func _set_section(section: StringName) -> void:
    _section = section
    _selected_slot = 0
    _refresh_all()

func _select_slot(index: int) -> void:
    _selected_slot = index
    _refresh_slots()
    _refresh_details(_selected_item())

func _equip_weapon(item: WeaponDefinition) -> void:
    var draft: Array[WeaponDefinition] = _draft_right if _section == &"right" else _draft_left
    for i in draft.size():
        if i != _selected_slot and draft[i] == item: draft[i] = null
    draft[_selected_slot] = item
    _refresh_all()

func _equip_spell(item: SpellDefinition) -> void:
    for i in _draft_spells.size():
        if i != _selected_slot and _draft_spells[i] == item: _draft_spells[i] = null
    _draft_spells[_selected_slot] = item
    _refresh_all()

func _clear_slot() -> void:
    if _section == &"right": _draft_right[_selected_slot] = null
    elif _section == &"left": _draft_left[_selected_slot] = null
    else: _draft_spells[_selected_slot] = null
    _refresh_all()

func _refresh_all() -> void:
    if not is_instance_valid(player): return
    var titles := {&"right": "RIGHT HAND", &"left": "LEFT HAND", &"spell": "PREPARED SPELLS"}
    _section_title.text = titles[_section]
    var capacity: int = player.get_spell_slot_capacity() if _section == &"spell" else player.get_weapon_slot_capacity(_section)
    if _section == &"spell":
        _capacity_label.text = str(capacity) + " slots  ·  " + str(player.spell_slot_bonus) + " bonus"
    else:
        _capacity_label.text = str(capacity) + " slots"
    for section: StringName in _tab_buttons:
        var button: Button = _tab_buttons[section]
        button.modulate = Color.WHITE if section == _section else Color(0.68, 0.68, 0.64)
    _selected_slot = clampi(_selected_slot, 0, maxi(0, capacity - 1))
    _refresh_slots()
    _refresh_available()
    _refresh_details(_selected_item())

func _refresh_slots() -> void:
    _clear_children(_slot_box)
    var count: int = player.get_spell_slot_capacity() if _section == &"spell" else player.get_weapon_slot_capacity(_section)
    for i in count:
        var item: Resource = _draft_item(i)
        var name: String = String(item.get("display_name")) if item != null else "Empty"
        var prefix: String = "SPELL" if _section == &"spell" else ("RH" if _section == &"right" else "LH")
        var button := _button(prefix + " " + str(i + 1) + "    " + name, _select_slot.bind(i), Vector2(0, 45))
        button.alignment = HORIZONTAL_ALIGNMENT_LEFT
        if i == _selected_slot:
            button.add_theme_color_override("font_color", GOLD_BRIGHT)
        _slot_box.add_child(button)

func _refresh_available() -> void:
    _clear_children(_available_box)
    _available_box.add_child(_button("— EMPTY SLOT —", _clear_slot, Vector2(0, 38)))
    if _section == &"spell":
        for spell: SpellDefinition in CATALOG.spells:
            if spell == null: continue
            var button := _button(spell.display_name + "   ·   " + spell.school, _equip_spell.bind(spell), Vector2(0, 40))
            button.alignment = HORIZONTAL_ALIGNMENT_LEFT
            _available_box.add_child(button)
    else:
        for weapon: WeaponDefinition in CATALOG.weapons:
            if weapon == null: continue
            if _section == &"right" and not weapon.usable_in_right_hand: continue
            if _section == &"left" and not weapon.usable_in_left_hand: continue
            var label_text: String = weapon.display_name + "   ·   " + weapon.category
            var button := _button(label_text, _equip_weapon.bind(weapon), Vector2(0, 40))
            button.alignment = HORIZONTAL_ALIGNMENT_LEFT
            _available_box.add_child(button)

func _selected_item() -> Resource:
    return _draft_item(_selected_slot)

func _draft_item(index: int) -> Resource:
    if _section == &"right": return _draft_right[index] if index < _draft_right.size() else null
    if _section == &"left": return _draft_left[index] if index < _draft_left.size() else null
    return _draft_spells[index] if index < _draft_spells.size() else null

func _refresh_details(item: Resource) -> void:
    if item == null:
        _details_title.text = "Empty slot"
        _details_body.text = "Leave this slot empty. Gameplay cycling skips empty slots."
        return
    _details_title.text = String(item.get("display_name"))
    if item is WeaponDefinition:
        var weapon := item as WeaponDefinition
        var requirement_text := _requirements_text(weapon.requirements)
        _details_body.text = weapon.category + "\nWeight  " + str(snappedf(weapon.weight, 0.1)) + "\n" + requirement_text + "\n\n" + weapon.description
        if weapon.is_spell_catalyst:
            _details_body.text += "\n\nCatalyst: " + (", ".join(PackedStringArray(weapon.catalyst_schools)) if not weapon.catalyst_schools.is_empty() else "all schools")
    elif item is SpellDefinition:
        var spell := item as SpellDefinition
        _details_body.text = spell.school + "\nUses  " + str(spell.maximum_charges) + "\nMemory cost  " + str(spell.memory_slots) + "\n" + _requirements_text(spell.requirements) + "\n\n" + spell.description

func _requirements_text(requirements: AttributeStats) -> String:
    if requirements == null: return "No requirements"
    var parts: Array[String] = []
    if requirements.vigour > 0: parts.append("VIG " + str(requirements.vigour))
    if requirements.endurance > 0: parts.append("END " + str(requirements.endurance))
    if requirements.strength > 0: parts.append("STR " + str(requirements.strength))
    if requirements.dexterity > 0: parts.append("DEX " + str(requirements.dexterity))
    if requirements.intelligence > 0: parts.append("INT " + str(requirements.intelligence))
    if requirements.faith > 0: parts.append("FAI " + str(requirements.faith))
    if requirements.arcane > 0: parts.append("ARC " + str(requirements.arcane))
    return "Requirements  " + (" · ".join(PackedStringArray(parts)) if not parts.is_empty() else "None")

func _clear_children(node: Node) -> void:
    for child: Node in node.get_children():
        node.remove_child(child)
        child.queue_free()

func _label(text: String, size: int, color: Color, alignment: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
    var label := Label.new()
    label.text = text
    label.horizontal_alignment = alignment
    label.add_theme_font_size_override("font_size", size)
    label.add_theme_color_override("font_color", color)
    label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
    label.add_theme_constant_override("shadow_offset_y", 2)
    return label

func _button(text: String, callback: Callable, minimum: Vector2, primary: bool = false) -> Button:
    var button := Button.new()
    button.text = text
    button.custom_minimum_size = minimum
    var normal := StyleBoxFlat.new()
    normal.bg_color = Color(0.055, 0.073, 0.074, 0.94)
    normal.border_color = GOLD_BRIGHT if primary else Color(GOLD, 0.62)
    normal.set_border_width_all(1)
    normal.set_corner_radius_all(4)
    var hover := normal.duplicate() as StyleBoxFlat
    hover.bg_color = Color(0.10, 0.105, 0.08, 0.98)
    hover.border_color = GOLD_BRIGHT
    button.add_theme_stylebox_override("normal", normal)
    button.add_theme_stylebox_override("hover", hover)
    button.add_theme_stylebox_override("pressed", hover)
    button.add_theme_color_override("font_color", TEXT)
    button.pressed.connect(callback)
    return button

func _panel_style() -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = PANEL
    style.border_color = Color(GOLD, 0.82)
    style.set_border_width_all(1)
    style.content_margin_left = 24
    style.content_margin_right = 24
    style.content_margin_top = 20
    style.content_margin_bottom = 20
    return style

func _inner_style() -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = Color(0.025, 0.038, 0.040, 0.86)
    style.border_color = Color(GOLD, 0.30)
    style.set_border_width_all(1)
    style.content_margin_left = 12
    style.content_margin_right = 12
    style.content_margin_top = 10
    style.content_margin_bottom = 10
    return style
