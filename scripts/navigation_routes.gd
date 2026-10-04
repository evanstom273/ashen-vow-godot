class_name NavigationRoutes
extends RefCounted
## Coarse authored guidance only. Local collision grids validate every actual step.
var graph := AStar2D.new()
var levels: Dictionary = {}
var portal_exit: Dictionary = {}
var signature: int = -1

func rebuild(scene: Node, elevation: Elevation) -> void:
	graph.clear()
	levels.clear()
	portal_exit.clear()
	var region: Variant = null
	for property: Dictionary in scene.get_property_list():
		if property.name == &"region_definition": region = scene.get("region_definition"); break
	if region is OverworldDefinition:
		var segments: Array[Dictionary] = []
		for route: RegionRouteDefinition in region.routes:
			if route == null: continue
			for index in range(1, route.points_metres.size()):
				segments.append({"a": route.points_metres[index - 1] * 128.0, "b": route.points_metres[index] * 128.0})
		_connect_routes(segments)
	for transition: ElevationTransition in elevation.stairs:
		if not is_instance_valid(transition) or not transition.valid_configuration(): continue
		var a: int = _point(transition.to_global(transition.definition.from_metres * 128.0), transition.definition.from_level)
		var b: int = _point(transition.to_global(transition.definition.to_metres * 128.0), transition.definition.to_level)
		graph.connect_points(a, b)
		portal_exit[a] = b
		portal_exit[b] = a
	# Link stair approaches to authored routes on the same floor. Collision is not bypassed.
	for key: int in portal_exit:
		var nearest_point_id: int = -1
		var distance: float = INF
		for candidate: int in graph.get_point_ids():
			if candidate == key or int(levels[candidate]) != int(levels[key]): continue
			var length: float = graph.get_point_position(key).distance_to(graph.get_point_position(candidate))
			if length < distance: nearest_point_id = candidate; distance = length
		if nearest_point_id >= 0: graph.connect_points(key, nearest_point_id)
	signature = elevation.revision

func _connect_routes(segments: Array[Dictionary]) -> void:
	# Split crossings in the coarse graph. This is a bounded authored route set,
	# built on explicit world revision, not a per-actor/per-frame geometry scan.
	for segment: Dictionary in segments:
		var points: Array[Vector2] = [segment.a, segment.b]
		for other: Dictionary in segments:
			if segment == other: continue
			var crossing: Variant = Geometry2D.segment_intersects_segment(segment.a, segment.b, other.a, other.b)
			if crossing is Vector2 and not points.has(crossing): points.append(crossing)
		points.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.distance_squared_to(segment.a) < b.distance_squared_to(segment.a))
		var previous: int = -1
		for point: Vector2 in points:
			var identity: int = _point(point, 0)
			if previous >= 0 and previous != identity and not graph.are_points_connected(previous, identity): graph.connect_points(previous, identity)
			previous = identity

func _point(at: Vector2, floor_level: int) -> int:
	for identity: int in graph.get_point_ids():
		if int(levels[identity]) == floor_level and graph.get_point_position(identity).distance_to(at) < 128.0: return identity
	var identity: int = graph.get_available_point_id()
	graph.add_point(identity, at)
	levels[identity] = floor_level
	return identity

func nearest(at: Vector2, floor_level: int) -> int:
	var best: int = -1
	var distance: float = INF
	for identity: int in graph.get_point_ids():
		if int(levels[identity]) != floor_level: continue
		var candidate: float = at.distance_squared_to(graph.get_point_position(identity))
		if candidate < distance: best = identity; distance = candidate
	return best

func waypoint(start: Vector2, from_level: int, destination: Vector2, to_level: int) -> Vector2:
	var a: int = nearest(start, from_level)
	var b: int = nearest(destination, to_level)
	if a < 0 or b < 0: return Vector2.INF if from_level != to_level else destination
	var path: PackedInt64Array = graph.get_id_path(a, b)
	if path.is_empty(): return Vector2.INF if from_level != to_level else destination
	for index in path.size():
		var point: Vector2 = graph.get_point_position(path[index])
		if index == path.size() - 1 and from_level == to_level: return destination
		if index == 0 and path.size() > 1 and int(levels[path[1]]) == from_level:
			var next_point: Vector2 = graph.get_point_position(path[1])
			var projection: Vector2 = Geometry2D.get_closest_point_to_segment(start, point, next_point)
			if start.distance_to(projection) < 256.0 and (start-point).dot(next_point-point) > 0.0: continue
		if start.distance_to(point) > 192.0: return point
		if portal_exit.has(path[index]) and index + 1 < path.size() and path[index+1] == int(portal_exit[path[index]]):
			return graph.get_point_position(path[index+1])
	return destination
