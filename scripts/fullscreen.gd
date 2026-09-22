extends Node
## Global F11 and Alt+Enter shortcut for toggling fullscreen.

var previous_mode: DisplayServer.WindowMode = DisplayServer.WINDOW_MODE_WINDOWED


func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS


func _input(event: InputEvent) -> void:
    if not (event is InputEventKey and event.is_pressed() and not event.is_echo()):
        return

    var is_f11: bool = (event.keycode == KEY_F11 or event.physical_keycode == KEY_F11 or event.key_label == KEY_F11)
    var is_alt_enter: bool = (event.alt_pressed and (event.keycode == KEY_ENTER or event.physical_keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER or event.physical_keycode == KEY_KP_ENTER))

    if is_f11 or is_alt_enter:
        _toggle_fullscreen()
        get_viewport().set_input_as_handled()


func _toggle_fullscreen() -> void:
    var current_mode := DisplayServer.window_get_mode()
    if current_mode == DisplayServer.WINDOW_MODE_FULLSCREEN or current_mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN:
        var target_mode := previous_mode if (previous_mode != DisplayServer.WINDOW_MODE_FULLSCREEN and previous_mode != DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN) else DisplayServer.WINDOW_MODE_WINDOWED
        DisplayServer.window_set_mode(target_mode)
    else:
        previous_mode = current_mode
        DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
