class_name SpellNavigation
extends Node
## Empty bounds allow local windows anywhere; region scenes supply real bounds.
@export var bounds := Rect2()
@export var cell_size: float = 128.0
@export_range(1, 128, 1) var agent_radius: float = 64.0
var grid := AStarGrid2D.new()
var initialized: bool = false
var _elevation_revision: int = -1
## Regional scenes cache bounded local grids instead of scanning the entire overworld.
@export var local_windows: bool = true
var window_grids: Dictionary = {}
var pending_windows: Array[Dictionary] = []
var coarse := NavigationRoutes.new()
@export_range(1, 256, 1) var probes_per_frame: int = 256

static func of(actor: Node) -> SpellNavigation:
	var scene: Node = actor.get_tree().current_scene
	var existing := scene.get_node_or_null("SpellNavigation") as SpellNavigation
	if existing != null: return existing
	var result := SpellNavigation.new()
	result.name = "SpellNavigation"
	scene.add_child(result)
	return result

func build(actor: Node2D) -> void:
	# Compatibility entry point: all builds use the bounded window scheduler.
	prewarm(actor)

## Partial pursuit advances through local windows toward a distant attacker.
## Default callers still require a complete path (e.g. summon target selection).
func path(actor: Node2D, destination: Vector2, allow_partial: bool = false, destination_level: int = -999) -> PackedVector2Array:
	_refresh_elevation(actor)
	var floor_level: int = Elevation.level(actor)
	if destination_level == -999: destination_level = floor_level
	var goal: Vector2 = destination
	if destination_level != floor_level or actor.global_position.distance_to(destination) > cell_size * 24.0:
		if coarse.signature != _elevation_revision: coarse.rebuild(get_tree().current_scene, Elevation.of(actor))
		goal = coarse.waypoint(actor.global_position, floor_level, destination, destination_level)
		if not goal.is_finite(): return PackedVector2Array()
		allow_partial = true
	return _window_path(actor, goal, allow_partial)

func invalidate_windows() -> void:
	window_grids.clear()
	pending_windows.clear()
	initialized = false
	coarse.signature = -1

func prewarm(actor: Node2D) -> void:
	_refresh_elevation(actor)
	_request_window(actor,_sector(actor.global_position))

func _refresh_elevation(actor: Node2D) -> void:
	var current: int = Elevation.of(actor).revision
	if current != _elevation_revision:
		invalidate_windows()
		_elevation_revision = current

func _key(actor: Node2D, sector: Vector2i) -> String:
	return str(sector.x) + ":" + str(sector.y) + ":" + str(Elevation.level(actor)) + ":" + str(_clearance(actor))

func _clearance(actor: Node2D) -> float:
	var radius: float = Elevation.body_radius(actor) if actor is CollisionObject2D else agent_radius
	return ceilf(maxf(16.0, radius) / 16.0) * 16.0

func _sector(at: Vector2) -> Vector2i:
	return Vector2i((at/(cell_size*32)).floor())

func _request_window(actor: Node2D, sector: Vector2i) -> void:
	var key: String = _key(actor, sector)
	if window_grids.has(key): return
	for job: Dictionary in pending_windows:
		if job.key == key: return
	if pending_windows.size() >= 8: return
	var local_grid := AStarGrid2D.new()
	local_grid.region = Rect2i(0,0,64,64)
	local_grid.cell_size = Vector2.ONE*cell_size
	local_grid.offset = Vector2(sector*32-Vector2i(16,16))*cell_size+Vector2.ONE*cell_size*0.5
	local_grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	local_grid.update()
	var shape := CircleShape2D.new()
	shape.radius = _clearance(actor)
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.collision_mask = Elevation.mask_for(1, Elevation.level(actor))
	var excluded: Array[RID] = []
	for player: Node in actor.get_tree().get_nodes_in_group("player"):
		if player is CollisionObject2D: excluded.append(player.get_rid())
	# Pre-exclude other registered storeys so each grid cell costs exactly ONE
	# collision probe even with many overlapping floors (256/frame budget retained).
	var window := Rect2(local_grid.offset - Vector2.ONE * cell_size, Vector2.ONE * cell_size * 66)
	for candidate: CollisionObject2D in Elevation.of(actor).nearby_raised(window):
		if is_instance_valid(candidate) and not Elevation.occupies(candidate, Elevation.level(actor)):
			excluded.append(candidate.get_rid())
	query.exclude = excluded
	pending_windows.append({"key":key,"level":Elevation.level(actor),"grid":local_grid,"query":query,"radius":shape.radius,"cursor":0,"actor":weakref(actor)})

func _physics_process(_delta: float) -> void:
	var budget: int = mini(256,probes_per_frame)
	while budget > 0 and not pending_windows.is_empty():
		var job: Dictionary = pending_windows[0]
		var candidate: Variant = job.actor.get_ref()
		if not is_instance_valid(candidate) or not candidate.is_inside_tree():
			pending_windows.pop_front()
			continue
		var actor := candidate as Node2D
		if Elevation.of(actor).revision != _elevation_revision:
			_refresh_elevation(actor)
			break
		var local_grid: AStarGrid2D = job.grid
		var query: PhysicsShapeQueryParameters2D = job.query
		var cursor: int = job.cursor
		var cell := Vector2i(cursor%64,floori(float(cursor)/64.0))
		query.transform = Transform2D(0,local_grid.get_point_position(cell))
		if (bounds.has_area() and not bounds.has_point(query.transform.origin)) or not Elevation.of(actor).support_at(query.transform.origin, int(job.level), float(job.radius)) or not actor.get_world_2d().direct_space_state.intersect_shape(query,1).is_empty(): local_grid.set_point_solid(cell)
		budget -= 1
		job.cursor = cursor+1
		if int(job.cursor) >= 4096:
			if window_grids.size() >= 8: window_grids.erase(window_grids.keys()[0])
			window_grids[job.key] = local_grid
			pending_windows.pop_front()

func _window_path(actor: Node2D, destination: Vector2, allow_partial: bool = false) -> PackedVector2Array:
	if bounds.has_area() and not bounds.has_point(destination): return PackedVector2Array()
	var sector: Vector2i = _sector(actor.global_position)
	var key: String = _key(actor, sector)
	if not window_grids.has(key):
		_request_window(actor,sector)
		return PackedVector2Array()
	var local_grid: AStarGrid2D = window_grids[key]
	var origin: Vector2 = local_grid.offset-Vector2.ONE*cell_size*0.5
	var start := Vector2i(((actor.global_position-origin)/cell_size).floor())
	var end := Vector2i(((destination-origin)/cell_size).floor())
	if not local_grid.region.has_point(start) or local_grid.is_point_solid(start): return PackedVector2Array()
	if allow_partial:
		# Do not enlarge grids or add collision probes for long-range aggression.
		# As the actor moves into another sector, its next request uses that window.
		end = _pursuit_goal(local_grid, end)
	elif not local_grid.region.has_point(end):
		return PackedVector2Array()
	if local_grid.is_point_solid(end): return PackedVector2Array()
	return local_grid.get_point_path(start, end, allow_partial)

func _pursuit_goal(local_grid: AStarGrid2D, destination: Vector2i) -> Vector2i:
	var region: Rect2i = local_grid.region
	var goal := Vector2i(clampi(destination.x, region.position.x, region.end.x - 1), clampi(destination.y, region.position.y, region.end.y - 1))
	if not local_grid.is_point_solid(goal): return goal
	# A clipped goal can fall on a tree/wall. Choose an open goal from this already
	# probed, bounded 64x64 grid; partial A* approaches the closest reachable cell.
	# Never clear solids to manufacture a path, or search toward a solid endpoint.
	var nearest: float = INF
	for y in range(region.position.y, region.end.y):
		for x in range(region.position.x, region.end.x):
			var cell := Vector2i(x, y)
			if local_grid.is_point_solid(cell): continue
			var distance: float = Vector2(cell).distance_squared_to(Vector2(destination))
			if distance < nearest:
				nearest = distance
				goal = cell
	return goal
