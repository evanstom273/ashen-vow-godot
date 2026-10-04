class_name WorldNavigationUI
extends Control
## North-up navigation. Only map coordinates and discovery state; never gameplay movement.
signal map_toggled(open: bool)
const GOLD := Color("d2bb82")
const INK := Color("e7e0cc")
const MAX_MARKERS: int = 8
var player: PlayerController
var opened: bool = false
var bounds := Rect2(-4096, -3072, 8192, 6144)
var region_name: String = "Region"
var routes: Array = []
var clearing := Rect2()
var trees := PackedVector2Array()
var region_boundary := PackedVector2Array()
var structures: Array = []
var region_landmarks: Array = []
var biome_tiles: Array = []
var woodland: Array = []
var landmarks: Array[Dictionary] = []
var discovered: Dictionary = {}
var markers: Array[Vector2] = []
var marker_fades: Array[float] = [] # -1: unreached; otherwise seconds remaining.
const ARRIVAL_FADE_SECONDS: float = 2.0
var active_marker: int = -1
var view_zoom: float = 1.0
var pan := Vector2.ZERO
var notice: String = ""
var discovery_time: float = 0.0
var close_button: Button
var clear_button: Button
var centre_button: Button
var map_canvas: Control
var beacon: Node2D
var dragging_marker: int = -1
var arrival_announced: bool = false
var touch_origin := Vector2.ZERO
var touch_dragged: bool = false
var map_transition: Tween
var map_closing: bool = false
var map_dirty: bool = true
@export_range(0.0, 0.6, 0.01) var map_vignette_strength: float = 0.32
var map_vignette: GradientTexture2D

func _ready() -> void:
	var edge_gradient := Gradient.new()
	edge_gradient.offsets = PackedFloat32Array([0.0, 0.45, 0.75, 1.0])
	edge_gradient.colors = PackedColorArray([Color(0, 0, 0, 0), Color(0, 0, 0, 0), Color(0, 0, 0, 0.4), Color(0, 0, 0, 1)])
	edge_gradient.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CUBIC
	map_vignette = GradientTexture2D.new()
	map_vignette.gradient = edge_gradient
	map_vignette.width = 256
	map_vignette.height = 256
	map_vignette.fill = GradientTexture2D.FILL_RADIAL
	map_vignette.fill_from = Vector2(0.5, 0.5)
	map_vignette.fill_to = Vector2(1.0, 1.0)
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var scene: Node = get_tree().current_scene
	if scene.has_method("get_world_map_data"):
		var data: Dictionary = scene.call("get_world_map_data")
		bounds = data.get("bounds", bounds)
		region_name = data.get("name", region_name)
		routes = data.get("routes", [])
		clearing = data.get("clearing", Rect2())
		region_boundary = data.get("boundary", PackedVector2Array())
		structures = data.get("structures", [])
		trees = data.get("trees", PackedVector2Array())
		region_landmarks = data.get("landmarks", [])
		biome_tiles = data.get("biomes", [])
		woodland = data.get("woodland", [])
		for landmark: Dictionary in region_landmarks:
			landmarks.append(landmark)
			if landmark.get("known", false): discovered[landmarks.size()-1] = true
	else:
		var navigation := scene.get_node_or_null("SpellNavigation") as SpellNavigation
		if navigation != null: bounds = navigation.bounds
		region_name = "The Outer Court"
	var actors: Node = scene.get_node_or_null("Actors")
	if actors != null:
		for actor: Node in actors.get_children():
			if not actor is Node2D: continue
			if region_boundary.is_empty() and actor.get_script() == preload("res://scripts/forest_tree.gd"):
				trees.append(actor.global_position)
			if actor is AshenShrine:
				landmarks.append({"position": actor.global_position, "name": actor.definition.display_name, "kind": "shrine"})
			elif actor.get_script() == preload("res://scripts/campfire.gd"):
				landmarks.append({"position": actor.global_position, "name": "Campfire", "kind": "fire"})
	map_canvas = Control.new()
	map_canvas.mouse_filter = Control.MOUSE_FILTER_STOP
	map_canvas.clip_contents = true
	map_canvas.draw.connect(_draw_map)
	map_canvas.gui_input.connect(_map_input)
	add_child(map_canvas)
	map_canvas.hide()
	close_button = _button("Close  [M / Esc]", func() -> void: close_map())
	clear_button = _button("Remove marker", _remove_active)
	centre_button = _button("Centre on player", _centre_player)
	resized.connect(_layout)
	_layout()
	beacon = preload("res://scripts/navigation_beacon.gd").new()
	scene.add_child(beacon)
	beacon.hide()

func _button(text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.add_theme_color_override("font_color", INK)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("17241f")
	style.border_color = GOLD
	style.set_border_width_all(1)
	button.add_theme_stylebox_override("normal", style)
	var hover := style.duplicate() as StyleBoxFlat
	hover.bg_color = Color("314238")
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", hover)
	var focus := StyleBoxFlat.new()
	focus.bg_color = Color.TRANSPARENT
	focus.border_color = INK
	focus.set_border_width_all(2)
	button.add_theme_stylebox_override("focus", focus)
	button.pressed.connect(action)
	add_child(button)
	return button

func _layout() -> void:
	if map_canvas == null: return
	map_dirty = true
	map_canvas.position = Vector2.ZERO
	map_canvas.size = size
	close_button.position = Vector2(size.x - 200, 28)
	close_button.size = Vector2(168, 40)
	clear_button.position = Vector2(32, size.y - 57)
	clear_button.size = Vector2(155, 38)
	centre_button.position = Vector2(199, size.y - 57)
	centre_button.size = Vector2(170, 38)
	for button: Button in [close_button, clear_button, centre_button]: button.visible = opened

func request_open() -> void:
	if opened or get_tree().paused or not is_instance_valid(player) or player.health <= 0: return
	opened = true
	player.reset_control_holds()
	get_tree().paused = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	map_canvas.show()
	# Keep the user's zoom and pan between visits.
	notice = ""
	_layout()
	close_button.grab_focus()
	map_toggled.emit(true)
	_fade_map(0.0)
	map_transition = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	map_transition.tween_method(_fade_map, 0.0, 1.0, 0.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func close_map() -> void:
	if not opened or map_closing: return
	map_closing = true
	if map_transition != null and map_transition.is_valid(): map_transition.kill()
	map_transition = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	map_transition.tween_method(_fade_map, map_canvas.modulate.a, 0.0, 0.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	map_transition.tween_callback(_finish_close_map)

func _fade_map(alpha: float) -> void:
	map_canvas.modulate.a = alpha
	for button: Button in [close_button, clear_button, centre_button]: button.modulate.a = alpha

func _finish_close_map() -> void:
	map_closing = false
	opened = false
	dragging_marker = -1
	get_tree().paused = false
	player.reset_control_holds()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	map_canvas.hide()
	_layout()
	map_toggled.emit(false)

func handle_input(event: InputEvent) -> bool:
	if event.is_action_pressed("world_map") and not event.is_echo():
		if opened: close_map()
		else: request_open()
		get_viewport().set_input_as_handled()
		return true
	if not opened: return false
	if event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
		close_map()
		get_viewport().set_input_as_handled()
		return true
	# Leave mouse/touch and focus navigation to GUI, while suppressing HUD shortcuts.
	return true

func _process(delta: float) -> void:
	if not is_instance_valid(player): return
	if not get_tree().paused:
		for i in range(markers.size() - 1, -1, -1):
			if marker_fades[i] < 0: continue
			marker_fades[i] = maxf(0, marker_fades[i] - delta)
			if marker_fades[i] <= 0: _erase_marker(i)
		discovery_time += delta
		if discovery_time >= 0.25:
			discovery_time = 0.0
			for i in landmarks.size():
				if not discovered.has(i) and player.global_position.distance_to(landmarks[i].position) <= float(landmarks[i].get("discovery_radius",512)):
					discovered[i] = true
					player.show_message("Discovered: " + str(landmarks[i].name))
	clear_button.disabled = active_marker < 0
	if is_instance_valid(beacon):
		beacon.visible = active_marker >= 0 and player.health > 0
		if active_marker >= 0:
			beacon.modulate.a = _marker_alpha(active_marker)
			beacon.global_position = markers[active_marker]
			beacon.set("marker_number", active_marker + 1)
			if not get_tree().paused and not arrival_announced and marker_fades[active_marker] < 0 and player.global_position.distance_to(markers[active_marker]) <= 192:
				arrival_announced = true
				marker_fades[active_marker] = ARRIVAL_FADE_SECONDS
				player.show_message("Destination %d reached" % (active_marker + 1))
	queue_redraw()
	# Gameplay is paused while mapping; cache the large surveyed drawing until input.
	if opened and map_dirty:
		map_canvas.queue_redraw()
		map_dirty = false

func _map_scale() -> float:
	if not region_boundary.is_empty():
		return minf(map_canvas.size.x / bounds.size.x, map_canvas.size.y / bounds.size.y) * view_zoom * 0.92
	return maxf(map_canvas.size.x / bounds.size.x, map_canvas.size.y / bounds.size.y) * view_zoom

func _project(world: Vector2) -> Vector2:
	return map_canvas.size * 0.5 + pan + (world - bounds.get_center()) * _map_scale()

func _unproject(point: Vector2) -> Vector2:
	return bounds.get_center() + (point - map_canvas.size * 0.5 - pan) / _map_scale()

func _centre_player() -> void:
	pan = -(player.global_position - bounds.get_center()) * _map_scale()
	map_dirty = true

func _remove_active() -> void:
	map_dirty = true
	if active_marker >= 0:
		_erase_marker(active_marker)
		active_marker = markers.size() - 1
		arrival_announced = false
		notice = "Marker removed"
		dragging_marker = -1

func _marker_alpha(index: int) -> float:
	return 1.0 if marker_fades[index] < 0 else marker_fades[index] / ARRIVAL_FADE_SECONDS

func _erase_marker(index: int) -> void:
	markers.remove_at(index)
	marker_fades.remove_at(index)
	if active_marker == index:
		active_marker = -1
		arrival_announced = false
	elif active_marker > index:
		active_marker -= 1
	if dragging_marker == index: dragging_marker = -1
	elif dragging_marker > index: dragging_marker -= 1

func _marker_hit(index: int, point: Vector2) -> bool:
	var at: Vector2 = _project(markers[index])
	return at.distance_to(point) <= 16 or (at + Vector2(0, -26)).distance_to(point) <= 16

func _place_or_select(point: Vector2) -> void:
	for i in markers.size():
		if _marker_hit(i, point):
			active_marker = i
			dragging_marker = i
			arrival_announced = marker_fades[i] >= 0
			notice = "Destination %d selected" % (i + 1)
			return
	var world: Vector2 = _unproject(point)
	for i in landmarks.size():
		if discovered.has(i) and _project(landmarks[i].position).distance_to(point) <= 20:
			world = landmarks[i].position
			break
	if not bounds.has_point(world) or (not region_boundary.is_empty() and not Geometry2D.is_point_in_polygon(world,region_boundary)):
		notice = "Place markers inside the mapped region"
		return
	if markers.size() >= MAX_MARKERS:
		notice = "Eight markers placed — remove one first"
		return
	markers.append(world)
	marker_fades.append(-1.0)
	active_marker = markers.size() - 1
	arrival_announced = false
	notice = "Destination %d placed" % (active_marker + 1)

func _map_input(event: InputEvent) -> void:
	map_dirty = true
	if map_closing:
		map_canvas.accept_event()
		return
	if event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		dragging_marker = -1
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT: _place_or_select(event.position)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			for i in markers.size():
				if _marker_hit(i, event.position):
					active_marker = i
					_remove_active()
					break
		elif event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			var anchor: Vector2 = _unproject(event.position)
			view_zoom = clampf(view_zoom * (1.2 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / 1.2), 0.5, 6)
			pan += event.position - _project(anchor)
	elif event is InputEventMouseMotion and dragging_marker >= 0 and (event.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
		var world: Vector2 = _unproject(event.position)
		world = world.clamp(bounds.position, bounds.end)
		if region_boundary.is_empty() or Geometry2D.is_point_in_polygon(world,region_boundary): markers[dragging_marker] = world
		marker_fades[dragging_marker] = -1.0
		arrival_announced = false
		notice = "Destination %d moved" % (dragging_marker + 1)
	elif event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_MIDDLE) != 0:
		pan += event.relative
	elif event is InputEventScreenTouch:
		if event.pressed:
			touch_origin = event.position
			touch_dragged = false
		elif not touch_dragged:
			_place_or_select(event.position)
	elif event is InputEventScreenDrag:
		touch_dragged = touch_dragged or event.position.distance_to(touch_origin) > 8
		pan += event.relative
	map_canvas.accept_event()

func _text(canvas: CanvasItem, at: Vector2, text: String, font_size: int = 14, color: Color = INK) -> void:
	canvas.draw_string(ThemeDB.fallback_font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)

func _diamond(canvas: CanvasItem, at: Vector2, color: Color, radius: float = 6.0) -> void:
	canvas.draw_colored_polygon(PackedVector2Array([at + Vector2(0, -radius), at + Vector2(radius, 0), at + Vector2(0, radius), at + Vector2(-radius, 0)]), color)

func _draw_map() -> void:
	map_canvas.draw_rect(Rect2(Vector2.ZERO, map_canvas.size), Color("283b31"))
	if not region_boundary.is_empty():
		map_canvas.draw_rect(Rect2(Vector2.ZERO,map_canvas.size),Color("14261e"))
		var outline := PackedVector2Array()
		for point: Vector2 in region_boundary:
			outline.append(_project(point))
		map_canvas.draw_colored_polygon(outline,Color("314637"))
		for tile: Dictionary in biome_tiles:
			var polygon := PackedVector2Array()
			for point: Vector2 in tile.polygon: polygon.append(_project(point))
			map_canvas.draw_polygon(polygon,tile.colors)
		outline.append(outline[0])
		map_canvas.draw_polyline(outline,Color("6d7856"),1.5,true)
	# World-anchored cartographic stipple, stable while panning/zooming.
	var random := RandomNumberGenerator.new()
	random.seed = 1731
	for i in 1100:
		var world := Vector2(random.randf_range(bounds.position.x, bounds.end.x), random.randf_range(bounds.position.y, bounds.end.y))
		var at: Vector2 = _project(world)
		var shade := Color("a29570")
		shade.a = random.randf_range(0.035, 0.12)
		map_canvas.draw_line(at, at + Vector2(random.randf_range(2, 7), -1), shade, 1, true)
	if view_zoom<2.0:
		for grove: Dictionary in woodland:
			var rect: Rect2 = grove.rect
			var center: Vector2 = _project(rect.get_center())
			var radius: Vector2 = rect.size*_map_scale()*0.65
			if not Rect2(Vector2.ZERO,map_canvas.size).grow(radius.length()).has_point(center): continue
			var crown := PackedVector2Array()
			for j in 10:
				var angle: float = float(j)*TAU/10
				crown.append(center+Vector2.from_angle(angle)*radius*(0.87+sin(j*2.3+rect.position.x)*0.13))
			map_canvas.draw_colored_polygon(crown,Color(0.09,0.18,0.12,0.75))
	if clearing.has_area():
		var clearing_points := PackedVector2Array()
		for i in 64:
			var angle: float = float(i) * TAU / 64.0
			var wobble: float = 1.0 + 0.045 * sin(angle * 5) + 0.035 * cos(angle * 9)
			clearing_points.append(_project(clearing.get_center() + Vector2.from_angle(angle) * clearing.size * 0.5 * wobble))
		map_canvas.draw_colored_polygon(clearing_points, Color("555b43"))
	for route: Dictionary in routes:
		var points := PackedVector2Array()
		for point: Vector2 in route.points: points.append(_project(point))
		if points.size() > 1:
			var route_width: float = maxf(2, float(route.width) * _map_scale() * 0.34)
			map_canvas.draw_polyline(points, Color("18291f"), route_width + 3, true)
			map_canvas.draw_polyline(points, Color("a29570"), route_width, true)
	for tree: Vector2 in trees:
		if view_zoom<2.0 and not woodland.is_empty(): break
		var at: Vector2 = _project(tree)
		if not Rect2(Vector2.ZERO,map_canvas.size).grow(30).has_point(at): continue
		var radius: float = clampf(150 * _map_scale(), 5, 30)
		map_canvas.draw_line(at + Vector2(0, -radius), at + Vector2(0, radius * 0.7), Color("7e8364"), 1, true)
		for tier in 3:
			var crown := PackedVector2Array([at + Vector2(0, -radius + tier * radius * 0.4), at + Vector2(radius * (0.45 + tier * 0.15), tier * radius * 0.4), at + Vector2(-radius * (0.45 + tier * 0.15), tier * radius * 0.4)])
			map_canvas.draw_colored_polygon(crown, Color("1b3026"))
			map_canvas.draw_polyline(crown, Color("657458"), 1, true)
	for structure: Dictionary in structures:
		if view_zoom<2 and structure.kind not in ["floor","wall","tower","pool","bridge"]: continue
		var tint := Color("92937b") if structure.kind != "pool" else Color("36565a")
		if structure.has("color"): tint=structure.color
		var polygon := PackedVector2Array()
		for point: Vector2 in structure.get("polygon",[]): polygon.append(_project(point))
		if polygon.size()<3: continue
		map_canvas.draw_colored_polygon(polygon,tint)
		polygon.append(polygon[0])
		map_canvas.draw_polyline(polygon,Color("1b3026"),1,true)
	var label_boxes: Array[Rect2] = []
	var landmark_order: Array[int] = []
	for i in landmarks.size(): landmark_order.append(i)
	landmark_order.sort_custom(func(a: int,b: int) -> bool: return _landmark_priority(a)>_landmark_priority(b))
	for i: int in landmark_order:
		if not discovered.has(i): continue
		var at: Vector2 = _project(landmarks[i].position)
		map_canvas.draw_circle(at, 13, Color("10231f"))
		map_canvas.draw_arc(at, 13, 0, TAU, 32, GOLD, 1, true)
		_diamond(map_canvas, at, GOLD, 6 if landmarks[i].kind == "shrine" else 3)
		var label: String = str(landmarks[i].name)
		var extent: Vector2 = ThemeDB.fallback_font.get_string_size(label,HORIZONTAL_ALIGNMENT_LEFT,-1,14)+Vector2(8,6)
		for offset: Vector2 in [Vector2(20,-12),Vector2(20,22),Vector2(-extent.x-18,-12),Vector2(-extent.x*0.5,35)]:
			var box := Rect2(at+offset-Vector2(4,16),extent)
			var fits: bool = Rect2(Vector2(12,90),map_canvas.size-Vector2(24,200)).encloses(box)
			for previous: Rect2 in label_boxes:
				if previous.intersects(box): fits=false
			if not fits: continue
			label_boxes.append(box)
			_text(map_canvas, at+offset+Vector2(1,2),label,14,Color("09150e"))
			_text(map_canvas, at+offset,label,14)
			break
	for i in markers.size():
		var at: Vector2 = _project(markers[i])
		var color: Color = Color("b5e5d8") if i == active_marker else GOLD
		color.a = _marker_alpha(i)
		map_canvas.draw_line(at, at + Vector2(0, -26), color, 2, true)
		map_canvas.draw_circle(at + Vector2(0, -26), 12, Color(Color("10231f"), color.a))
		map_canvas.draw_arc(at + Vector2(0, -26), 12, 0, TAU, 24, color, 1.5, true)
		_text(map_canvas, at + Vector2(-4, -21), str(i + 1), 13, color)
		map_canvas.draw_arc(at, 5, 0, TAU, 16, color, 1, true)
	var player_at: Vector2 = _project(player.global_position)
	map_canvas.draw_circle(player_at, 6, Color("eaf1df"))
	map_canvas.draw_line(player_at, player_at + player.aim * 16, Color("eaf1df"), 2, true)
	# Screen-fixed soft edges; drawn before controls so their contrast is unchanged.
	if map_vignette != null:
		map_canvas.draw_texture_rect(map_vignette, Rect2(Vector2.ZERO, map_canvas.size), false, Color(1, 1, 1, map_vignette_strength))
	# Interface overlays belong on the map canvas, above the terrain, not behind it.
	_text(map_canvas, Vector2(32, 51), region_name.to_upper(), 26, GOLD)
	if not notice.is_empty(): _text(map_canvas, Vector2(32, 73), notice, 12, INK)
	_text(map_canvas, Vector2(32, size.y - 77), "Click: place/select   Drag marker: move   Right-click: remove   Wheel: zoom   Middle-drag: pan", 13)
	if active_marker >= 0:
		_text(map_canvas, Vector2(390, size.y - 33), "Beacon %d / %.1f m" % [active_marker + 1, player.global_position.distance_to(markers[active_marker]) / 128.0], 14, Color("b5e5d8"))
	elif not notice.is_empty():
		_text(map_canvas, Vector2(390, size.y - 33), notice, 13)
	var rose := Vector2(size.x - 56, 135)
	map_canvas.draw_line(rose + Vector2(0, -17), rose + Vector2(0, 17), GOLD, 1, true)
	map_canvas.draw_line(rose + Vector2(-12, 0), rose + Vector2(12, 0), GOLD, 1, true)
	_diamond(map_canvas, rose, GOLD, 5)
	_text(map_canvas, rose + Vector2(-5, -23), "N", 13, GOLD)
	var ruler_metres: float = 50.0 if bounds.size.x > 20000 and view_zoom < 2 else 10.0
	var ruler: float = ruler_metres * 128 * _map_scale()
	map_canvas.draw_line(Vector2(32, size.y - 126), Vector2(32 + ruler, size.y - 126), GOLD, 2)
	_text(map_canvas, Vector2(32, size.y - 136), "%d m" % roundi(ruler_metres), 12, GOLD)

func _landmark_priority(index: int) -> int:
	match str(landmarks[index].kind):
		"fort": return 4
		"shrine": return 3
		"chapel": return 2
	return 1

func _draw() -> void:
	if not is_instance_valid(player): return
	if opened:
		return
	if get_tree().paused: return
	var width: float = minf(340, size.x * 0.32)
	var left: float = (size.x - width) * 0.5
	draw_line(Vector2(left, 24), Vector2(left + width, 24), Color(GOLD, 0.6), 1)
	for i in 17:
		var x: float = left + width * i / 16.0
		draw_line(Vector2(x, 21), Vector2(x, 27 if i % 4 == 0 else 24), Color(GOLD, 0.55), 1)
	for i in 5:
		_text(self, Vector2(left + width * i / 4.0 - 4, 17), ["S", "W", "N", "E", "S"][i], 12, GOLD)
	for i in landmarks.size():
		if discovered.has(i): _compass_marker(landmarks[i].position, width, left, Color("abb6a0"), 3)
	if active_marker >= 0:
		_compass_marker(markers[active_marker], width, left, Color(GOLD, _marker_alpha(active_marker)), 6)
		var distance_m: float = player.global_position.distance_to(markers[active_marker]) / 128.0
		_text(self, Vector2(size.x * 0.5 - 66, 56), "Destination %d  ·  %.0f m" % [active_marker + 1, distance_m], 12, GOLD)

func _compass_marker(world: Vector2, width: float, left: float, color: Color, radius: float) -> void:
	var offset: Vector2 = world - player.global_position
	var bearing: float = atan2(offset.x, -offset.y)
	_diamond(self, Vector2(left + width * (bearing / TAU + 0.5), 34), color, radius)

func _exit_tree() -> void:
	if is_instance_valid(beacon): beacon.queue_free()
	if opened: get_tree().paused = false
