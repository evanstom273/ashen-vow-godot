@tool
class_name LandmarkApproach
extends Node2D
## Editable visual approach, not a navigation link or a collider.
@export var definition: LandmarkApproachDefinition:
	set(value):
		if definition != null and definition.changed.is_connected(_rebuild): definition.changed.disconnect(_rebuild)
		definition = value
		if definition != null: definition.changed.connect(_rebuild)
		if is_inside_tree(): _rebuild()
var ground_art: Node2D
var _owned_art: Array[Node2D] = []

func _ready() -> void:
	y_sort_enabled = true
	_rebuild()

func _rebuild() -> void:
	if not is_inside_tree(): return
	for entry: Variant in _owned_art:
		if not is_instance_valid(entry): continue
		var art: Node2D = entry
		if art.get_parent() == self: remove_child(art)
		art.queue_free()
	_owned_art.clear()
	if definition == null: return
	ground_art = Node2D.new()
	ground_art.name = "ApproachGround"
	ground_art.z_index = -8
	ground_art.draw.connect(_draw_ground)
	add_child(ground_art)
	_owned_art.append(ground_art)
	for at: Vector2 in definition.frame_positions_metres:
		var frame := Node2D.new()
		frame.position = at*128.0
		frame.draw.connect(_draw_frame.bind(frame))
		add_child(frame)
		_owned_art.append(frame)
		if definition.frame_style == 2:
			var cloth := Polygon2D.new()
			cloth.polygon = PackedVector2Array([Vector2(0,-252),Vector2(78,-238),Vector2(72,-105),Vector2(40,-125),Vector2(5,-96)])
			cloth.color = definition.cloth_color
			cloth.material = preload("res://data/environment/wind_undergrowth.tres").make_material(260.0,float(definition.seed_value))
			frame.add_child(cloth)

func cover_clearances() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if definition == null: return result
	for index in range(1,definition.points_metres.size()):
		var a: Vector2 = to_global(definition.points_metres[index-1]*128.0)/128.0
		var b: Vector2 = to_global(definition.points_metres[index]*128.0)/128.0
		var width: float = definition.width_metres*maxf(absf(global_scale.x),absf(global_scale.y))
		result.append({"kind":"access", "a":a, "b":b, "width":width, "bounds":Rect2(a,Vector2.ZERO).expand(b).grow(width)})
	return result

func _draw_ground() -> void:
	if definition == null or definition.points_metres.size()<2: return
	ground_art.draw_set_transform(Vector2.ZERO,0,Vector2.ONE*128.0)
	var route := RegionRouteDefinition.new()
	route.points_metres = definition.points_metres
	route.width_metres = definition.width_metres
	var shoulder: PackedVector2Array = RegionGeometry.drawable_polygon(RegionGeometry.ribbon(route,1.3))
	var centre: PackedVector2Array = RegionGeometry.drawable_polygon(RegionGeometry.ribbon(route,0.85))
	if shoulder.size()>2: ground_art.draw_colored_polygon(shoulder, Color(definition.surface,0.26))
	if centre.size()>2: ground_art.draw_colored_polygon(centre, Color(definition.worn_centre,0.2))
	var random := RandomNumberGenerator.new()
	random.seed = definition.seed_value
	var next: float = 0.0
	for index in range(1,definition.points_metres.size()):
		var a: Vector2 = definition.points_metres[index-1]
		var b: Vector2 = definition.points_metres[index]
		var tangent: Vector2 = (b-a).normalized()
		var normal: Vector2 = tangent.orthogonal()
		var distance: float = a.distance_to(b)
		var along: float = next
		while along < distance:
			var at: Vector2 = a+tangent*along
			for side: float in [-1.0, 1.0]:
				if random.randf()<0.22: continue
				var edge: Vector2 = at+normal*side*(definition.width_metres*0.5+random.randf_range(0.0,0.28))
				var radius: float = random.randf_range(0.11,0.28)
				if definition.edge_style in [1,3]:
					ground_art.draw_line(edge-normal*0.12,edge+tangent*0.55,definition.edging,0.1 if definition.edge_style==1 else 0.045)
				else:
					var stone := PackedVector2Array([edge+Vector2(-radius,0),edge+Vector2(-radius*0.4,-radius*0.7),edge+Vector2(radius,-radius*0.3),edge+Vector2(radius*0.4,radius*0.5)])
					ground_art.draw_colored_polygon(stone,definition.edging.darkened(random.randf_range(0.0,0.2)))
			# Small irregular paver remnants indicate old workmanship without a neat carpet.
			if definition.edge_style==0 and random.randf()<0.4:
				ground_art.draw_line(at-normal*random.randf_range(0.2,0.6),at+normal*random.randf_range(0.2,0.6),Color(definition.edging,0.32),0.25)
			along += maxf(0.5,definition.edge_spacing_metres)
		next = along-distance
	if definition.threshold:
		var end: Vector2 = definition.points_metres[-1]
		var normal: Vector2 = (end-definition.points_metres[-2]).normalized().orthogonal()
		ground_art.draw_line(end-normal*definition.width_metres*0.44,end+normal*definition.width_metres*0.44,Color(definition.accent_color,0.48),0.16)
	ground_art.draw_set_transform(Vector2.ZERO)

func _draw_frame(frame: Node2D) -> void:
	frame.draw_set_transform(Vector2.ZERO,0,Vector2.ONE*128.0)
	frame.draw_colored_polygon(PackedVector2Array([Vector2(-0.35,0.12),Vector2(0.3,0.24),Vector2(0.75,-0.18),Vector2(0.2,-0.35)]),Color(0.03,0.04,0.03,0.2))
	var height: float = 0.45 if definition.frame_style==0 else (2.1 if definition.frame_style==2 else 1.15)
	frame.draw_colored_polygon(PackedVector2Array([Vector2(-0.13,0.1),Vector2(-0.12,-height),Vector2(0.09,-height-0.05),Vector2(0.17,0.05)]),definition.edging)
	frame.draw_line(Vector2(-0.1,-height),Vector2(-0.09,-0.02),definition.accent_color.darkened(0.12),0.03)
	if definition.frame_style==1:
		frame.draw_line(Vector2(-0.32,-height*0.65),Vector2(0.32,-height*0.65),definition.edging,0.1)
	elif definition.frame_style==3:
		frame.draw_rect(Rect2(-0.22,-height-0.07,0.44,0.15),definition.accent_color.darkened(0.2))
	frame.draw_set_transform(Vector2.ZERO)
