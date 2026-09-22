extends Control
## Clockwise from the top: spell, right hand, utility, left hand.
var player: PlayerController
const SLOT_SIZE := Vector2(52, 58)
const GOLD := Color("a79871")
const WEAPON_NAME_HOLD: float = 1.5
const WEAPON_NAME_FADE: float = 0.7
var _weapon_names: Dictionary = {}
var _weapon_name_times: Dictionary = {}

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    if is_instance_valid(player):
        player.loadout_changed.connect(_on_loadout_changed)

func handle_mobile_tap(local_position: Vector2) -> bool:
    if not is_instance_valid(player): return false
    if Rect2(Vector2(57, 0), SLOT_SIZE).has_point(local_position):
        player.cycle_spell()
        return true
    if Rect2(Vector2(114, 34), SLOT_SIZE).has_point(local_position):
        player.cycle_weapon(&"right")
        return true
    if Rect2(Vector2(57, 68), SLOT_SIZE).has_point(local_position):
        player.cycle_utility()
        return true
    if Rect2(Vector2(0, 34), SLOT_SIZE).has_point(local_position):
        player.cycle_weapon(&"left")
        return true
    return false

func _on_loadout_changed(kind: StringName, _index: int) -> void:
    if kind != &"left" and kind != &"right": return
    var weapon: WeaponDefinition = player.get_selected_weapon(kind)
    if weapon == null: return
    _weapon_names[kind] = ("RH  " if kind == &"right" else "LH  ") + weapon.display_name
    _weapon_name_times[kind] = WEAPON_NAME_HOLD + WEAPON_NAME_FADE
    queue_redraw()

func _process(delta: float) -> void:
    if not get_tree().paused:
        for hand: StringName in _weapon_name_times:
            _weapon_name_times[hand] = maxf(0.0, float(_weapon_name_times[hand]) - delta)
    queue_redraw()

func _draw() -> void:
    if not is_instance_valid(player): return
    var spell: SpellDefinition = player.spells[player.spell_index] if not player.spells.is_empty() else null
    var utility: UtilityDefinition = player.utilities[player.utility_index] if not player.utilities.is_empty() else null
    var spell_count: int = player.spell_charges[player.spell_index] if spell != null else -1
    var utility_count: int = player.utility_charges[player.utility_index] if utility != null else -1
    _draw_slot(Vector2(57, 0), spell, "C", spell_count, 0.0)
    _draw_slot(Vector2(114, 34), player.get_selected_weapon(&"right"), "Q", -1, player.get_charge_progress(&"right"))
    _draw_slot(Vector2(57, 68), utility, "V", utility_count, 0.0)
    _draw_slot(Vector2(0, 34), player.get_selected_weapon(&"left"), "R", -1, player.get_charge_progress(&"left"))
    var font: Font = ThemeDB.fallback_font
    for hand: StringName in [&"right", &"left"]:
        var remaining: float = float(_weapon_name_times.get(hand, 0.0))
        if remaining <= 0.0: continue
        var opacity: float = smoothstep(0.0, WEAPON_NAME_FADE, remaining)
        var text: String = String(_weapon_names[hand])
        var baseline := Vector2(0, -30 if hand == &"right" else -12)
        draw_string(font, baseline + Vector2(1, 2), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0, 0, 0, opacity * 0.8))
        draw_string(font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(Color("e0d9c6"), opacity))
    var spell_name: String = spell.display_name if spell != null else "No spell"
    var utility_name: String = utility.display_name if utility != null else "No utility"
    draw_string(font, Vector2(0, 144), utility_name, HORIZONTAL_ALIGNMENT_CENTER, 166, 13, Color("e0d9c6"))
    draw_string(font, Vector2(0, 162), spell_name, HORIZONTAL_ALIGNMENT_CENTER, 166, 11, Color("aaa58f"))

func _draw_slot(at: Vector2, item: Resource, key: String, count: int, charge: float) -> void:
    var rect := Rect2(at, SLOT_SIZE)
    draw_rect(rect, Color(0.018, 0.022, 0.018, 0.72))
    draw_rect(rect, Color(GOLD, 0.48 if item != null else 0.18), false, 1.0)
    draw_rect(rect.grow(-3), Color(GOLD, 0.10), false, 1.0)
    if item != null:
        var texture: Texture2D = item.get("icon") as Texture2D
        if texture != null:
            var dimensions: Vector2 = texture.get_size()
            var fitted: Vector2 = dimensions * minf(40.0 / dimensions.x, 42.0 / dimensions.y)
            draw_texture_rect(texture, Rect2(at + (SLOT_SIZE - fitted) * 0.5, fitted), false)
        else:
            draw_set_transform(at + Vector2(26, 28))
            _draw_item(item)
            draw_set_transform(Vector2.ZERO)
    var font: Font = ThemeDB.fallback_font
    draw_string(font, at + Vector2(4, 11), key, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color("99917a"))
    if count >= 0:
        draw_string(font, at + Vector2(4, 53), str(count), HORIZONTAL_ALIGNMENT_RIGHT, 43, 13, Color("eee6cf"))
    if charge > 0:
        var perimeter: float = (SLOT_SIZE.x + SLOT_SIZE.y) * 2.0
        var remaining: float = perimeter * charge
        var points := PackedVector2Array([at, at + Vector2(SLOT_SIZE.x, 0), at + SLOT_SIZE, at + Vector2(0, SLOT_SIZE.y), at])
        for i in 4:
            var distance: float = points[i].distance_to(points[i + 1])
            if remaining <= 0: break
            draw_line(points[i], points[i].lerp(points[i + 1], minf(1, remaining / distance)), Color("e9c472"), 2.0, true)
            remaining -= distance

func _draw_item(item: Resource) -> void:
    if item is WeaponDefinition:
        var weapon: WeaponDefinition = item as WeaponDefinition
        var steel: Color = weapon.blade_color
        match weapon.category:
            "Shield":
                draw_circle(Vector2.ZERO, 17, Color("383d39"))
                draw_arc(Vector2.ZERO, 17, 0, TAU, 40, GOLD, 2, true)
                draw_circle(Vector2.ZERO, 6, steel)
                draw_line(Vector2(-12, 0), Vector2(12, 0), GOLD, 1, true)
                draw_line(Vector2(0, -12), Vector2(0, 12), GOLD, 1, true)
            "Seal":
                draw_arc(Vector2.ZERO, 13, 0, TAU, 32, GOLD, 2, true)
                draw_colored_polygon(PackedVector2Array([Vector2(0,-17),Vector2(7,0),Vector2(0,17),Vector2(-7,0)]), steel)
            "Staff", "Wand":
                draw_line(Vector2(-10, 20), Vector2(9, -16), Color("897456"), 4, true)
                draw_circle(Vector2(9, -16), 7 if weapon.category == "Staff" else 4, steel)
                draw_circle(Vector2(9, -16), 3, Color("d8edee"))
            "Hammer":
                draw_line(Vector2(-11, 20), Vector2(8, -14), Color("897456"), 4, true)
                draw_rect(Rect2(1, -22, 17, 14), steel)
            _:
                var tip := Vector2(16, -22)
                if weapon.category == "Dagger": tip = Vector2(9, -10)
                draw_colored_polygon(PackedVector2Array([Vector2(-6,8),Vector2(-2,10),tip,Vector2(3,-5)]), steel)
                draw_line(Vector2(-13, 6), Vector2(1, 14), GOLD, 3, true)
                draw_line(Vector2(-6, 10), Vector2(-13, 21), Color("927954"), 4, true)
    elif item is SpellDefinition:
        var spell: SpellDefinition = item as SpellDefinition
        var color := Color("81c8e5")
        if spell.school == "Incantation": color = Color("e0ae65")
        draw_circle(Vector2.ZERO, 17, Color(color, 0.12))
        draw_arc(Vector2.ZERO, 14, 0.2, TAU - 0.2, 32, Color(color, 0.6), 1, true)
        if spell.delivery == "Self":
            draw_line(Vector2(0, -15), Vector2(0, 15), color, 3, true)
            draw_line(Vector2(-10, -4), Vector2(10, -4), color, 3, true)
        else:
            draw_colored_polygon(PackedVector2Array([Vector2(-12,17),Vector2(-4,-3),Vector2(13,-20),Vector2(6,3)]), color)
            draw_line(Vector2(-9, 14), Vector2(9, -14), Color("e1f6fa"), 2, true)
    elif item is UtilityDefinition:
        var utility: UtilityDefinition = item as UtilityDefinition
        var liquid := Color("be8935") if utility.health_restore > 0 else Color("8ba865")
        draw_circle(Vector2(0, 6), 14, Color("796746"))
        draw_circle(Vector2(0, 6), 11, liquid)
        draw_rect(Rect2(-5, -16, 10, 17), Color("a69c74"))
        draw_rect(Rect2(-7, -18, 14, 4), GOLD)
        draw_arc(Vector2(0, 6), 8, 2.8, 4.2, 16, Color("f4d78d"), 2, true)
