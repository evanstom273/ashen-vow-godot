class_name MobileControls
extends Control

signal pause_requested

const GOLD := Color("a79871")
const GOLD_BRIGHT := Color("e9c472")
const PANEL := Color(0.018, 0.024, 0.025, 0.62)
const PANEL_PRESSED := Color(0.08, 0.075, 0.055, 0.82)
const TEXT := Color("e7e0cc")
const JOYSTICK_RADIUS := 58.0
const JOYSTICK_KNOB := 23.0

var player: PlayerController
var _joystick_touch: int = -1
var _joystick_origin := Vector2.ZERO
var _joystick_current := Vector2.ZERO
var _touch_actions: Dictionary = {}
var _lock_start := Vector2.ZERO
var _lock_last := Vector2.ZERO

static func should_enable() -> bool:
    return OS.has_feature("mobile") or DisplayServer.is_touchscreen_available() or "--mobile-controls" in OS.get_cmdline_user_args()

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    process_mode = Node.PROCESS_MODE_ALWAYS
    if is_instance_valid(player):
        player.set_mobile_controls_active(true)
    resized.connect(queue_redraw)
    queue_redraw()

func _exit_tree() -> void:
    if is_instance_valid(player):
        player.set_mobile_movement(Vector2.ZERO)
        player.set_mobile_controls_active(false)

func _process(_delta: float) -> void:
    queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
    if not is_instance_valid(player): return
    if event is InputEventScreenTouch:
        var touch := event as InputEventScreenTouch
        if touch.pressed:
            if _press_touch(touch.index, touch.position):
                get_viewport().set_input_as_handled()
        else:
            if _release_touch(touch.index, touch.position):
                get_viewport().set_input_as_handled()
    elif event is InputEventScreenDrag:
        var drag := event as InputEventScreenDrag
        if _drag_touch(drag.index, drag.position):
            get_viewport().set_input_as_handled()

func _press_touch(index: int, at: Vector2) -> bool:
    var rects := _action_rects()
    if rects[&"pause"].has_point(at):
        pause_requested.emit()
        return true
    if get_tree().paused: return false
    if _try_equipment_cross(at): return true

    for action_name: StringName in [&"right", &"left", &"dodge", &"cast", &"utility", &"interact", &"lock"]:
        var rect: Rect2 = rects[action_name]
        if not rect.has_point(at): continue
        _touch_actions[index] = action_name
        if action_name == &"right":
            player.begin_hand_action(&"right")
        elif action_name == &"left":
            player.begin_hand_action(&"left")
        elif action_name == &"dodge":
            player.begin_dodge_sprint_hold()
        elif action_name == &"cast":
            player.use_selected_spell()
        elif action_name == &"utility":
            player.use_selected_utility()
        elif action_name == &"interact":
            player.interact_nearby()
        elif action_name == &"lock":
            _lock_start = at
            _lock_last = at
        queue_redraw()
        return true

    if _can_start_joystick(at) and _joystick_touch < 0:
        _joystick_touch = index
        _joystick_origin = at
        _joystick_current = at
        _update_joystick(at)
        queue_redraw()
        return true
    return false

func _release_touch(index: int, at: Vector2) -> bool:
    if index == _joystick_touch:
        _joystick_touch = -1
        _joystick_origin = Vector2.ZERO
        _joystick_current = Vector2.ZERO
        player.set_mobile_movement(Vector2.ZERO)
        queue_redraw()
        return true

    if not _touch_actions.has(index): return false
    var action_name: StringName = _touch_actions[index]
    _touch_actions.erase(index)
    if action_name == &"right":
        player.release_hand_action(&"right")
    elif action_name == &"left":
        player.release_hand_action(&"left")
    elif action_name == &"dodge":
        player.release_dodge_sprint_hold()
    elif action_name == &"lock":
        _lock_last = at
        var swipe: float = _lock_last.x - _lock_start.x
        if absf(swipe) >= 36.0:
            player.cycle_target(1 if swipe > 0.0 else -1)
        else:
            player.toggle_lock()
    queue_redraw()
    return true

func _drag_touch(index: int, at: Vector2) -> bool:
    if index == _joystick_touch:
        _joystick_current = at
        _update_joystick(at)
        queue_redraw()
        return true
    if _touch_actions.has(index) and _touch_actions[index] == &"lock":
        _lock_last = at
        queue_redraw()
        return true
    return false

func _update_joystick(at: Vector2) -> void:
    var offset: Vector2 = at - _joystick_origin
    var clamped: Vector2 = offset.limit_length(JOYSTICK_RADIUS)
    player.set_mobile_movement(clamped / JOYSTICK_RADIUS)

func _try_equipment_cross(at: Vector2) -> bool:
    var equipment: Control = get_parent().get_node_or_null("EquipmentCross") as Control
    if equipment == null or not equipment.visible: return false
    var rect: Rect2 = equipment.get_global_rect()
    if not rect.has_point(at): return false
    var local_position: Vector2 = at - rect.position
    return bool(equipment.call("handle_mobile_tap", local_position))

func _can_start_joystick(at: Vector2) -> bool:
    if at.x > size.x * 0.48: return false
    if at.y < 115.0: return false
    # Keep the existing equipment cross clear; those slots are directly tappable.
    if at.x < 220.0 and at.y > size.y - 225.0: return false
    return true

func _safe_margins() -> Vector4:
    var margins := Vector4(18.0, 18.0, 18.0, 18.0)
    if not OS.has_feature("mobile"): return margins
    var safe: Rect2i = DisplayServer.get_display_safe_area()
    var screen: Vector2i = DisplayServer.screen_get_size()
    if screen.x <= 0 or screen.y <= 0 or safe.size.x <= 0 or safe.size.y <= 0: return margins
    var sx: float = size.x / float(screen.x)
    var sy: float = size.y / float(screen.y)
    margins.x = maxf(margins.x, float(safe.position.x) * sx)
    margins.y = maxf(margins.y, float(safe.position.y) * sy)
    margins.z = maxf(margins.z, float(screen.x - safe.position.x - safe.size.x) * sx)
    margins.w = maxf(margins.w, float(screen.y - safe.position.y - safe.size.y) * sy)
    return margins

func _action_rects() -> Dictionary:
    var margins := _safe_margins()
    var button_size := Vector2(74, 50)
    var gap: float = 10.0
    var right_edge: float = size.x - margins.z - 18.0
    var lower_y: float = size.y - margins.w - 142.0
    var x3: float = right_edge - button_size.x
    var x2: float = x3 - gap - button_size.x
    var x1: float = x2 - gap - button_size.x
    var y2: float = lower_y
    var y1: float = y2 - gap - button_size.y
    var lock_y: float = y1 - gap - button_size.y
    return {
        &"cast": Rect2(Vector2(x1, y1), button_size),
        &"left": Rect2(Vector2(x2, y1), button_size),
        &"dodge": Rect2(Vector2(x3, y1), button_size),
        &"interact": Rect2(Vector2(x1, y2), button_size),
        &"utility": Rect2(Vector2(x2, y2), button_size),
        &"right": Rect2(Vector2(x3, y2), button_size),
        &"lock": Rect2(Vector2(x3, lock_y), button_size),
        &"pause": Rect2(Vector2(size.x - margins.z - 62.0, margins.y + 8.0), Vector2(46, 40))
    }

func _draw() -> void:
    if not is_instance_valid(player): return
    var rects := _action_rects()
    _draw_button(rects[&"pause"], "II", false)

    if get_tree().paused: return
    _draw_button(rects[&"cast"], "CAST", _action_pressed(&"cast"))
    _draw_button(rects[&"left"], "LH", _action_pressed(&"left"))
    _draw_button(rects[&"dodge"], "DODGE", _action_pressed(&"dodge"))
    _draw_button(rects[&"interact"], "INTERACT", _action_pressed(&"interact"), player.nearby_interactable() != null)
    _draw_button(rects[&"utility"], "USE", _action_pressed(&"utility"))
    _draw_button(rects[&"right"], "RH", _action_pressed(&"right"))
    _draw_button(rects[&"lock"], "LOCK", _action_pressed(&"lock"), is_instance_valid(player.locked_target))
    var font: Font = ThemeDB.fallback_font
    var lock_hint: Rect2 = rects[&"lock"]
    draw_string(font, Vector2(lock_hint.position.x - 7.0, lock_hint.position.y - 5.0), "swipe target", HORIZONTAL_ALIGNMENT_CENTER, lock_hint.size.x + 14.0, 9, Color(0.75, 0.72, 0.62, 0.72))

    if _joystick_touch >= 0:
        draw_circle(_joystick_origin, JOYSTICK_RADIUS, Color(0.02, 0.03, 0.03, 0.36))
        draw_arc(_joystick_origin, JOYSTICK_RADIUS, 0.0, TAU, 48, Color(GOLD, 0.62), 2.0, true)
        var knob_at: Vector2 = _joystick_origin + (_joystick_current - _joystick_origin).limit_length(JOYSTICK_RADIUS)
        draw_circle(knob_at, JOYSTICK_KNOB, Color(0.22, 0.25, 0.22, 0.76))
        draw_arc(knob_at, JOYSTICK_KNOB, 0.0, TAU, 32, Color(GOLD_BRIGHT, 0.72), 1.5, true)

func _action_pressed(action_name: StringName) -> bool:
    for active: Variant in _touch_actions.values():
        if active == action_name: return true
    return false

func _draw_button(rect: Rect2, label: String, pressed: bool, accented: bool = false) -> void:
    var fill: Color = PANEL_PRESSED if pressed else PANEL
    var border: Color = GOLD_BRIGHT if pressed or accented else Color(GOLD, 0.72)
    draw_rect(rect, fill, true)
    draw_rect(rect, border, false, 2.0 if pressed else 1.0, true)
    draw_rect(rect.grow(-3.0), Color(GOLD, 0.08), false, 1.0, true)
    var font: Font = ThemeDB.fallback_font
    var color: Color = GOLD_BRIGHT if pressed or accented else TEXT
    var text_size: Vector2 = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12)
    var baseline := Vector2(rect.position.x + (rect.size.x - text_size.x) * 0.5, rect.position.y + (rect.size.y + text_size.y) * 0.5 - 2.0)
    draw_string(font, baseline, label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, color)
