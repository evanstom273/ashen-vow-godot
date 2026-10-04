@tool
extends Node2D
## Editor-only, progressively cached overview. Close-up art comes from the normal
## terrain/tree pipeline; distant silhouettes use the exact same placement records.
const CELL_METRES: float = 32.0
var definition: OverworldDefinition
var detail_bounds := Rect2()
var _jobs: Array[Dictionary] = []
var _meshes: Array[ArrayMesh] = []
var _dressing_meshes: Array[ArrayMesh] = []
var _dressing_art: Node2D
var _base := PackedVector2Array()

func configure(value: OverworldDefinition, bounds: Rect2, local_detail: Rect2) -> void:
	definition = value
	detail_bounds = local_detail
	_base = RegionGeometry.drawable_polygon(value.boundary)
	_dressing_art = Node2D.new()
	_dressing_art.name = "DistantDressing"
	_dressing_art.z_index = 14 # Above local ground meshes; below authored actors.
	_dressing_art.draw.connect(_draw_dressing)
	add_child(_dressing_art)
	for y in range(floori(bounds.position.y / CELL_METRES), ceili(bounds.end.y / CELL_METRES)):
		for x in range(floori(bounds.position.x / CELL_METRES), ceili(bounds.end.x / CELL_METRES)):
			_jobs.append({"cell": Vector2(x, y) * CELL_METRES})
	for route: RegionRouteDefinition in definition.routes:
		_jobs.append({"route": route})
	set_process(true)
	queue_redraw()

func add_tree(at: Vector2, family: int, visual_scale: float) -> void:
	if detail_bounds.grow(12).has_point(at): return
	_jobs.append({"tree": at, "family": family, "scale": visual_scale})
	set_process(true)

func add_prop(at: Vector2, footprint: Vector2) -> void:
	if detail_bounds.grow(12).has_point(at): return
	_jobs.append({"prop": at, "size": footprint})
	set_process(true)

func _process(_delta: float) -> void:
	if not Engine.is_editor_hint():
		set_process(false)
		return
	var started: int = Time.get_ticks_usec()
	var vertices := PackedVector2Array()
	var colors := PackedColorArray()
	var dressing_vertices := PackedVector2Array()
	var dressing_colors := PackedColorArray()
	var count: int = 0
	while not _jobs.is_empty() and count < 32:
		var job: Dictionary = _jobs.pop_front()
		if job.has("cell"):
			var at: Vector2 = job.cell
			var bounds := Rect2(at, Vector2.ONE * CELL_METRES)
			for polygon: PackedVector2Array in RegionGeometry.clip_local_polygons(definition.boundary, bounds):
				var world := PackedVector2Array()
				var tints := PackedColorArray()
				for point: Vector2 in polygon:
					world.append(point + at)
					tints.append(definition.soil_at(point + at))
				_append_polygon(world, tints, vertices, colors)
		elif job.has("route"):
			var route: RegionRouteDefinition = job.route
			for width: float in [1.4, 1.0]:
				var polygon: PackedVector2Array = RegionGeometry.drawable_polygon(RegionGeometry.ribbon(route, width))
				var tints := PackedColorArray()
				for _i in polygon.size():
					tints.append(Color("394332") if width > 1.0 else Color("48483a"))
				_append_polygon(polygon, tints, vertices, colors)
		elif job.has("tree"):
			var at: Vector2 = job.tree
			var width: float = float(job.scale) * 0.48
			var polygon := PackedVector2Array()
			if int(job.family) == 1:
				polygon = PackedVector2Array([at + Vector2(0, -width * 2), at + Vector2(width, 0.4), at + Vector2(-width, 0.4)])
			elif int(job.family) == 2:
				polygon = PackedVector2Array([at + Vector2(-0.25, 0), at + Vector2(-0.18, -width * 1.8), at + Vector2(0.18, -width * 1.8), at + Vector2(0.25, 0)])
			else:
				for i in 8:
					polygon.append(at + Vector2(0, -width * 0.8) + Vector2.from_angle(i * TAU / 8.0) * width)
			var tints := PackedColorArray()
			for _i in polygon.size(): tints.append(Color("263f30") if int(job.family) != 2 else Color("535340"))
			_append_polygon(polygon, tints, dressing_vertices, dressing_colors)
		else:
			var at: Vector2 = job.prop
			var size_metres: Vector2 = job.size
			var polygon: PackedVector2Array = RegionGeometry.rect_polygon(Rect2(at - size_metres * 0.5, size_metres))
			_append_polygon(polygon, PackedColorArray([Color("57614c"), Color("57614c"), Color("57614c"), Color("57614c")]), dressing_vertices, dressing_colors)
		count += 1
		if Time.get_ticks_usec() - started >= 1800: break
	if not vertices.is_empty():
		_meshes.append(_mesh(vertices, colors))
		queue_redraw()
	if not dressing_vertices.is_empty():
		_dressing_meshes.append(_mesh(dressing_vertices, dressing_colors))
		_dressing_art.queue_redraw()
	if _jobs.is_empty(): set_process(false)

func _mesh(vertices: PackedVector2Array, colors: PackedColorArray) -> ArrayMesh:
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_COLOR] = colors
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

func _append_polygon(polygon: PackedVector2Array, tints: PackedColorArray, vertices: PackedVector2Array, colors: PackedColorArray) -> void:
	if polygon.size() < 3 or polygon.size() != tints.size(): return
	var triangles: PackedInt32Array = Geometry2D.triangulate_polygon(polygon)
	for index: int in triangles:
		vertices.append(polygon[index])
		colors.append(tints[index])

func _draw() -> void:
	if not Engine.is_editor_hint(): return
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE * 128)
	if not _base.is_empty(): draw_colored_polygon(_base, Color("263a2d"))
	for mesh: ArrayMesh in _meshes: draw_mesh(mesh, null)
	draw_set_transform(Vector2.ZERO)

func _draw_dressing() -> void:
	_dressing_art.draw_set_transform(Vector2.ZERO, 0, Vector2.ONE * 128)
	for mesh: ArrayMesh in _dressing_meshes: _dressing_art.draw_mesh(mesh, null)
	_dressing_art.draw_set_transform(Vector2.ZERO)
