extends Node
## Global F11 and Alt+Enter shortcut for toggling fullscreen.

var previous_mode: DisplayServer.WindowMode = DisplayServer.WINDOW_MODE_WINDOWED
var _toggle_pending: bool = false
var _toggle_started_usec: int = 0
var _mode_change_usec: int = 0


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
	# Do not stack display mode changes while a previous one awaits its first frame.
	if _toggle_pending: return
	_toggle_pending = true
	_toggle_started_usec = Time.get_ticks_usec()
	print("[Display] Fullscreen toggle requested")
	var current_mode := DisplayServer.window_get_mode()
	if current_mode == DisplayServer.WINDOW_MODE_FULLSCREEN or current_mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN:
		var target_mode := previous_mode if (previous_mode != DisplayServer.WINDOW_MODE_FULLSCREEN and previous_mode != DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN) else DisplayServer.WINDOW_MODE_WINDOWED
		DisplayServer.window_set_mode(target_mode)
	else:
		previous_mode = current_mode
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	_mode_change_usec = Time.get_ticks_usec()-_toggle_started_usec
	print("[Display] Window mode change returned in ",_mode_change_usec/1000.0," ms; waiting for rendered frame")
	RenderingServer.frame_post_draw.connect(_report_fullscreen_frame,CONNECT_ONE_SHOT)


func _report_fullscreen_frame() -> void:
	print("[Display] First frame after fullscreen toggle: ",(Time.get_ticks_usec()-_toggle_started_usec)/1000.0," ms total")
	_toggle_pending = false
