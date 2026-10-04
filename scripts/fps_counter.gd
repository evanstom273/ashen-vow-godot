extends PanelContainer
## Lightweight gameplay-session telemetry; no frame history or per-frame text updates.
## Min/max are completed sampling-window FPS, not individual-frame reciprocals.
@export_range(0.1, 2.0, 0.1) var sample_interval_seconds: float = 0.5
var readout: Label
var _previous_usec: int = 0
var _window_seconds: float = 0.0
var _window_frames: int = 0
var _total_seconds: float = 0.0
var _total_frames: int = 0
var _current_fps: float = 0.0
var _minimum_fps: float = INF
var _maximum_fps: float = 0.0
var _suspended: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	offset_left = -194
	offset_right = -20
	offset_top = 20
	offset_bottom = 112
	grow_horizontal = Control.GROW_DIRECTION_BEGIN
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.04, 0.035, 0.78)
	style.border_color = Color(0.66, 0.59, 0.38, 0.45)
	style.set_border_width_all(1)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	add_theme_stylebox_override("panel", style)
	readout = Label.new()
	readout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	readout.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	readout.add_theme_font_size_override("font_size", 13)
	readout.add_theme_color_override("font_color", Color("d9c79f"))
	add_child(readout)
	_refresh_text()

func _process(_delta: float) -> void:
	var now_usec: int = Time.get_ticks_usec()
	var suspended: bool = get_tree().paused or not get_window().has_focus()
	if suspended != _suspended:
		_suspended = suspended
		_refresh_text()
	if suspended:
		# Exclude menus/alt-tab time, including partially sampled windows.
		_previous_usec = 0
		_window_seconds = 0.0
		_window_frames = 0
		return
	if _previous_usec == 0:
		_previous_usec = now_usec
		return
	# Monotonic wall time is independent of Engine.time_scale and hit-stop.
	var frame_seconds: float = float(now_usec - _previous_usec) / 1000000.0
	_previous_usec = now_usec
	if frame_seconds <= 0.0: return
	_window_frames += 1
	_window_seconds += frame_seconds
	if _window_seconds < maxf(0.1, sample_interval_seconds): return
	_current_fps = float(_window_frames) / _window_seconds
	_minimum_fps = minf(_minimum_fps, _current_fps)
	_maximum_fps = maxf(_maximum_fps, _current_fps)
	_total_frames += _window_frames
	_total_seconds += _window_seconds
	_window_frames = 0
	_window_seconds = 0.0
	_refresh_text()

func _refresh_text() -> void:
	var heading: String = "FPS (paused)" if _suspended else "FPS"
	if _total_frames == 0:
		readout.text = "%s  --\nMin  --\nMax  --\nAvg  --" % heading
		return
	# Frame count / elapsed time, not an unweighted average of FPS samples.
	var average_fps: float = float(_total_frames) / _total_seconds
	readout.text = "%s  %.1f\nMin  %.1f\nMax  %.1f\nAvg  %.1f" % [heading, _current_fps, _minimum_fps, _maximum_fps, average_fps]
