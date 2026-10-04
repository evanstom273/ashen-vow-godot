@tool
extends Node2D
## Shared deterministic editor/runtime ground, clipped to a small cullable chunk.
signal mesh_requested(chunk: Node2D)
var tile_metres := Vector2.ZERO
var seed_value: int = 0
var definition: OverworldDefinition
## Validated, chunk-local metre coordinates supplied by the region builder.
var shoulder_polygons: Array[PackedVector2Array] = []
var road_polygons: Array[PackedVector2Array] = []
var road_segments: Array[Dictionary] = []
var cover_contexts: Array[Dictionary] = []
var nearby_trees := PackedVector2Array()
var cover_art: MeshInstance2D
var _cover_builder: GroundCoverBuilder
var _detail_complete: bool = false
var detail_mesh: ArrayMesh
var detail_wanted: bool = false
var _fallback_polygon := PackedVector2Array()
var _fallback_colors := PackedColorArray()
var _vertices := PackedVector2Array()
var _colors := PackedColorArray()
var _indices := PackedInt32Array()

func _ready() -> void:
	if definition == null or definition.scatter == null: return
	var side: float = definition.scatter.chunk_metres
	if side<=0: return
	_fallback_polygon = RegionGeometry.rect_polygon(Rect2(Vector2.ZERO,Vector2.ONE*side))
	for point: Vector2 in _fallback_polygon: _fallback_colors.append(definition.soil_at(point+tile_metres))
	if Engine.is_editor_hint():
		_request_detail(true)
	else:
		var screen := VisibleOnScreenNotifier2D.new()
		# Prewarm a full chunk ahead of the view, including at Raven's widest zoom.
		# Do not hide this node: the notifier needs to remain visible to the renderer.
		screen.rect = Rect2(Vector2.ZERO,Vector2.ONE*side*128).grow(side*128)
		screen.screen_entered.connect(_request_detail.bind(true))
		screen.screen_exited.connect(_request_detail.bind(false))
		add_child(screen)

func _request_detail(wanted: bool) -> void:
	detail_wanted = wanted
	if is_instance_valid(cover_art): cover_art.visible = wanted
	if wanted and not _detail_complete: mesh_requested.emit(self)

func _draw() -> void:
	# No random generation, clipping, biome sampling or triangulation on redraw/F11.
	draw_set_transform(Vector2.ZERO,0,Vector2.ONE*128)
	if detail_mesh != null:
		draw_mesh(detail_mesh,null)
	elif _fallback_polygon.size()==4:
		draw_polygon(_fallback_polygon,_fallback_colors)
	draw_set_transform(Vector2.ZERO)

func prepare_mesh() -> bool:
	if _detail_complete: return true
	if definition == null or definition.scatter == null: return true
	if detail_mesh == null:
		_prepare_base()
		return detail_mesh == null
	if _cover_builder != null and not _cover_builder.advance(): return false
	var cover: ArrayMesh = _cover_builder.finish() if _cover_builder != null else null
	if cover != null:
		cover_art = MeshInstance2D.new()
		cover_art.name = "BatchedGroundCover"
		cover_art.mesh = cover
		cover_art.material = preload("res://data/environment/ground_cover_material.tres")
		# Region -20 + ground -1 + cover 12 = -9: above floors, below actors.
		cover_art.z_index = 12
		cover_art.visible = detail_wanted
		add_child(cover_art)
	_cover_builder = null
	# Keep the small indexed authoring inputs so a discarded cosmetic mesh can
	# regenerate identically. Neither this cache nor eviction owns world collision.
	_detail_complete = true
	return true

func discard_detail() -> void:
	if detail_wanted: return
	if is_instance_valid(cover_art):
		remove_child(cover_art)
		cover_art.queue_free()
	cover_art = null
	detail_mesh = null
	_cover_builder = null
	_detail_complete = false
	_vertices = PackedVector2Array()
	_colors = PackedColorArray()
	_indices = PackedInt32Array()
	queue_redraw()

func _prepare_base() -> void:
	# Called by the region's bounded work queue, never from _draw().
	if detail_mesh != null: return
	if definition == null or definition.scatter == null: return
	var side: float = definition.scatter.chunk_metres
	if side<=0: return
	_vertices.clear()
	_colors.clear()
	_indices.clear()
	# Sample biomes per vertex: neighbouring tiles share exactly the same edge colours.
	for y in 4:
		for x in 4:
			var rect := Rect2(Vector2(x,y)*side/4,Vector2.ONE*side/4)
			var polygon: PackedVector2Array = RegionGeometry.rect_polygon(rect)
			var colors := PackedColorArray()
			for point: Vector2 in polygon: colors.append(_soil_tint(point+tile_metres))
			_append_polygon(polygon,colors)
	_append_patches(side)
	for polygon: PackedVector2Array in shoulder_polygons: _append_path(polygon, 0.28)
	for polygon: PackedVector2Array in road_polygons: _append_path(polygon, 0.62)
	if _indices.is_empty(): return
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = _vertices
	arrays[Mesh.ARRAY_COLOR] = _colors
	arrays[Mesh.ARRAY_INDEX] = _indices
	detail_mesh = ArrayMesh.new()
	detail_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	_cover_builder = GroundCoverBuilder.new()
	_cover_builder.begin(definition,Rect2(tile_metres,Vector2.ONE*side),road_segments,cover_contexts,nearby_trees)
	# One retained mesh per visited chunk, not hundreds of individual canvas polygons.
	_vertices = PackedVector2Array()
	_colors = PackedColorArray()
	_indices = PackedInt32Array()
	queue_redraw()

func _soil_tint(at: Vector2) -> Color:
	# Continuous low-contrast variation sampled in world metres; no tile-local noise.
	var variation: float = sin(at.x*0.27+sin(at.y*0.19))*cos(at.y*0.31+at.x*0.08)
	var base: Color = definition.soil_at(at)
	for context: Dictionary in cover_contexts:
		if context.kind == "profile":
			var local: Vector2 = context.inverse * at
			var rect: Rect2 = context.rect
			var edge: float = minf(minf(local.x-rect.position.x,rect.end.x-local.x),minf(local.y-rect.position.y,rect.end.y-local.y))
			var profile: GroundCoverProfile = context.profile
			base = base.lerp(Color(profile.soil_tint,1.0),profile.soil_tint.a*smoothstep(-3.0,3.0,edge))
		elif context.kind == "water":
			var rect: Rect2 = context.bounds
			if rect.grow(2.0).has_point(at):
				var polygon: PackedVector2Array = context.polygon
				var distance: float = 3.0
				for index in polygon.size(): distance = minf(distance,at.distance_to(Geometry2D.get_closest_point_to_segment(at,polygon[index],polygon[(index+1)%polygon.size()])))
				base = base.lerp(Color("283d31"),(1.0-smoothstep(0.0,2.0,distance))*0.28)
	return base.lightened(variation*0.035) if variation>0.0 else base.darkened(-variation*0.09)

func _append_path(polygon: PackedVector2Array, strength: float) -> void:
	var colors := PackedColorArray()
	for point: Vector2 in polygon:
		var at: Vector2 = point+tile_metres
		colors.append(_soil_tint(at).lerp(Color("57533c"),strength))
	_append_polygon(polygon,colors)

func _append_polygon(polygon: PackedVector2Array, colors: PackedColorArray) -> void:
	if polygon.size()<3 or polygon.size()!=colors.size(): return
	var triangles: PackedInt32Array = Geometry2D.triangulate_polygon(polygon)
	if triangles.is_empty(): return
	var offset: int = _vertices.size()
	_vertices.append_array(polygon)
	_colors.append_array(colors)
	for index: int in triangles: _indices.append(offset+index)

func _append_solid(polygon: PackedVector2Array, color: Color) -> void:
	var colors := PackedColorArray()
	colors.resize(polygon.size())
	colors.fill(color)
	_append_polygon(polygon,colors)

func _append_line(from: Vector2, to: Vector2, color: Color, width: float) -> void:
	var normal: Vector2 = (to-from).normalized().orthogonal()*width*0.5
	_append_solid(PackedVector2Array([from+normal,to+normal,to-normal,from-normal]),color)

func _append_patches(side: float) -> void:
	var local_bounds := Rect2(Vector2.ZERO,Vector2.ONE*side)
	var base_cell := Vector2i((tile_metres/side).floor())
	# Include neighbouring patches with the same random consumption and seed. Build
	# and validate once, not on every redraw. Only cosmetic slivers are dropped.
	for ny in range(-1,2):
		for nx in range(-1,2):
			var cell: Vector2i = base_cell+Vector2i(nx,ny)
			var patch_random := RandomNumberGenerator.new()
			patch_random.seed = definition.scatter.seed_value+cell.x*1723+cell.y*631
			for i in 16:
				var local_at := Vector2(cell-base_cell)*side+Vector2(patch_random.randf()*side,patch_random.randf()*side)
				var patch := PackedVector2Array()
				for j in 9: patch.append(local_at+Vector2.from_angle(j*TAU/9.0)*patch_random.randf_range(0.7,2.2))
				if not local_bounds.grow(2.2).has_point(local_at): continue
				var tint: Color = _soil_tint(tile_metres+local_at).lightened(0.02)
				for piece: PackedVector2Array in RegionGeometry.clip_local_polygons(patch,local_bounds):
					_append_solid(piece,tint)
