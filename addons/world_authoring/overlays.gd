@tool
extends RefCounted
## Selected authored nodes only. Bounded traversal; generated scatter is excluded.
static func draw(canvas: Control, view: Transform2D, selection: Array[Node], mode: int) -> void:
	var queue: Array[Node] = []
	queue.assign(selection)
	var visited: Dictionary = {}
	var remaining: int = 512
	while not queue.is_empty() and remaining > 0:
		var node: Node = queue.pop_front()
		if not is_instance_valid(node) or visited.has(node): continue
		visited[node] = true
		remaining -= 1
		if node.has_meta("region_generator") or node is StillwoodOverworld: continue
		for child: Node in node.get_children():
			if child.owner != null: queue.append(child)
		if not node is Node2D: continue
		var transform: Transform2D = view * node.global_transform
		var color := Color(0.35, 0.85, 0.65, 0.8)
		if mode == 1:
			if node is CollisionShape2D and node.shape != null:
				_outline(canvas, transform, _shape(node.shape), Color(1, 0.55, 0.2, 0.8) if node.disabled else color)
			elif node is CollisionPolygon2D: _outline(canvas, transform, node.polygon, color)
			elif node is ForestTree: _circle(canvas, transform, 24, color)
		elif mode == 2 and node is Sentinel:
			var definition: EnemyDefinition = node.definition
			if definition != null and definition.perception != null:
				var radius: float = definition.perception.sight_metres * WorldScale.UNITS_PER_METRE
				_circle(canvas, view * Transform2D(0, node.global_position), radius, Color(1, 0.6, 0.3, 0.55))
			canvas.draw_string(ThemeDB.fallback_font, transform.origin + Vector2(10, -16), "Encounter: " + String(node.name), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1, 0.8, 0.5))
		elif mode == 3 and node is Sentinel and node.definition != null:
			for move: EnemyMove in node.definition.moves:
				if move != null: _circle(canvas, view * Transform2D(0, node.global_position), move.maximum_metres * WorldScale.UNITS_PER_METRE, Color(0.6, 0.75, 1, 0.5))
		if mode in [1, 4] and node is BuildingFloor and node.definition != null:
			for polygon: PackedVector2Array in node.definition.regions_metres:
				_outline(canvas, transform.scaled_local(Vector2.ONE * WorldScale.UNITS_PER_METRE), polygon, Color(0.55, 0.7, 1, 0.8))
		if mode == 4 and node is ElevationTransition and node.definition != null:
			canvas.draw_line(transform * (node.definition.from_metres * 128), transform * (node.definition.to_metres * 128), Color(0.9, 0.8, 0.3), 3, true)
	canvas.draw_string(ThemeDB.fallback_font, Vector2(18, 32), "Authored selection • cosmetic overlay • collision and Resources unchanged", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)

static func _circle(canvas: Control, transform: Transform2D, radius: float, color: Color) -> void:
	var points := PackedVector2Array()
	for index in 48: points.append(Vector2.from_angle(TAU * index / 48.0) * radius)
	_outline(canvas, transform, points, color)

static func _shape(shape: Shape2D) -> PackedVector2Array:
	if shape is RectangleShape2D: return RegionGeometry.rect_polygon(Rect2(-shape.size * 0.5, shape.size))
	if shape is ConvexPolygonShape2D: return shape.points
	var result := PackedVector2Array()
	if shape is CircleShape2D or shape is CapsuleShape2D:
		for index in 48:
			var point: Vector2 = Vector2.from_angle(TAU * index / 48.0) * shape.radius
			if shape is CapsuleShape2D: point.y += signf(point.y) * maxf(0, shape.height * 0.5 - shape.radius)
			result.append(point)
	return result

static func _outline(canvas: Control, transform: Transform2D, local: PackedVector2Array, color: Color) -> void:
	if local.size() < 2: return
	var points := PackedVector2Array()
	for point: Vector2 in local: points.append(transform * point)
	points.append(points[0])
	canvas.draw_polyline(points, color, 1.5, true)

static func audit_ids(node: Node, ids: Dictionary, issues: Array[String]) -> void:
	if node.has_meta("region_generator") or node is StillwoodOverworld: return
	for property: Dictionary in node.get_property_list():
		if property.name not in [&"persistent_id", &"landmark_id", &"checkpoint_id", &"encounter_id", &"reward_id"]: continue
		var identity: String = str(node.get(property.name))
		if identity.is_empty(): issues.append(str(node.get_path()) + ": assign " + str(property.name))
		elif ids.has(identity): issues.append("Duplicate authored ID: " + identity)
		else: ids[identity] = true
	for child: Node in node.get_children():
		if child.owner != null: audit_ids(child, ids, issues)

static func draw_payload(canvas: Control, view: Transform2D, inspected: Object, origin: Vector2) -> void:
	if not is_instance_valid(inspected): return
	if inspected is SpellDefinition: inspected = inspected.delivery_definition
	if not is_instance_valid(inspected): return
	var transform: Transform2D = view * Transform2D(0, origin)
	var color := Color(0.85, 0.65, 1, 0.8)
	if inspected is AttackDefinition:
		var arc := PackedVector2Array([Vector2.ZERO])
		for i in 49: arc.append(Vector2.from_angle(deg_to_rad(inspected.arc_degrees) * (float(i) / 48.0 - 0.5)) * inspected.reach * WorldScale.ART_SCALE)
		_outline(canvas, transform, arc, color)
		return
	if not inspected is SpellDeliveryDefinition: return
	if inspected is BeamDelivery:
		_outline(canvas, transform, RegionGeometry.rect_polygon(Rect2(0,-inspected.width*0.5,inspected.length,inspected.width)), color)
	elif inspected is ConeDelivery:
		var sector := PackedVector2Array([Vector2.ZERO])
		for i in 49: sector.append(Vector2.from_angle(deg_to_rad(inspected.angle_degrees) * (float(i)/48.0-0.5)) * inspected.radius)
		_outline(canvas, transform, sector, color)
	else:
		for field: Dictionary in inspected.get_property_list():
			if field.name in [&"radius", &"trigger_radius", &"impact_radius", &"orbit_radius", &"break_range"]:
				_circle(canvas, transform, float(inspected.get(field.name)), color)
	_circle(canvas, transform, inspected.cast_range, Color(0.5,0.6,1,0.25))
