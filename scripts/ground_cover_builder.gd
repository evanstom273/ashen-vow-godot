@tool
class_name GroundCoverBuilder
extends RefCounted
## Disposable CPU builder. Output: one mesh, no physics, particles or plant nodes.
var vertices := PackedVector2Array()
var colors := PackedColorArray()
var weights := PackedVector2Array()
var indices := PackedInt32Array()
var tile := Rect2()

func build_patch(profile: GroundCoverProfile, radius: Vector2, amount: int, seed_value: int) -> ArrayMesh:
	tile = Rect2(Vector2.ZERO, radius*2.0)
	if profile == null: return null
	var random := RandomNumberGenerator.new()
	random.seed = seed_value
	for _item in clampi(amount, 1, 128):
		var at: Vector2 = Vector2.from_angle(random.randf()*TAU)*radius*sqrt(random.randf())
		_stamp(at,profile.family_at(random.randf()),random.randf_range(profile.height_metres.x,profile.height_metres.y),random.randf(),profile.foliage,profile)
	return _mesh()

var _world: OverworldDefinition
var _roads: Array[Dictionary] = []
var _contexts: Array[Dictionary] = []
var _trees := PackedVector2Array()
var _first := Vector2i.ZERO
var _last := Vector2i.ZERO
var _cursor := Vector2i.ZERO
var _count: int = 0

func begin(world: OverworldDefinition, bounds: Rect2, roads: Array[Dictionary], contexts: Array[Dictionary], trees: PackedVector2Array) -> void:
	tile = bounds
	_world = world
	_roads = roads
	_contexts = contexts
	_trees = trees
	var spacing: float = maxf(2.0,world.scatter.cover_cell_metres)
	_first = Vector2i((bounds.position/spacing).floor())-Vector2i.ONE
	_last = Vector2i((bounds.end/spacing).ceil())+Vector2i.ONE
	_cursor = _first

func advance(budget_usec: int = 900) -> bool:
	# A few clusters per queue visit, not an entire dense chunk in one frame.
	var started: int = Time.get_ticks_usec()
	var cells: int = 0
	while _cursor.y <= _last.y:
		_append_cell(_cursor.x,_cursor.y)
		_cursor.x += 1
		if _cursor.x > _last.x:
			_cursor.x = _first.x
			_cursor.y += 1
		cells += 1
		if cells >= 4 or Time.get_ticks_usec()-started >= budget_usec: break
	return _cursor.y > _last.y

func finish() -> ArrayMesh:
	return _mesh()

func _append_cell(x: int, y: int) -> void:
	var world: OverworldDefinition = _world
	var bounds: Rect2 = tile
	var roads: Array[Dictionary] = _roads
	var contexts: Array[Dictionary] = _contexts
	var trees: PackedVector2Array = _trees
	var spacing: float = maxf(2.0,world.scatter.cover_cell_metres)
	var random := RandomNumberGenerator.new()
	random.seed = world.scatter.seed_value + x * 73856093 + y * 19349663
	var centre := (Vector2(x, y) + Vector2(random.randf(), random.randf())) * spacing
	var biome: RegionBiomeDefinition = world.blended_biome(centre, random.randf())
	if biome == null or biome.ground_cover == null: return
	var profile: GroundCoverProfile = biome.ground_cover
	# Authored landmark patches feather into the surrounding biome, never a hard ring.
	for context: Dictionary in contexts:
		if context.kind != "profile": continue
		var local: Vector2 = context.inverse * centre
		var rect: Rect2 = context.rect
		var edge: float = minf(minf(local.x-rect.position.x, rect.end.x-local.x), minf(local.y-rect.position.y, rect.end.y-local.y))
		if fposmod(sin(centre.x*12.9898+centre.y*78.233)*43758.5453,1.0) < smoothstep(-3.0, 2.0, edge): profile = context.profile
	# Large bare pockets amongst clusters, not a uniform lawn.
	var patch: float = 0.5 + 0.25 * sin(centre.x * 0.19 + sin(centre.y * 0.11)) + 0.25 * cos(centre.y * 0.23)
	var active: bool = random.randf() < profile.density * lerpf(0.35, 1.0, patch)
	var spread: float = random.randf_range(spacing * 0.25, spacing * 0.65)
	for _item in world.scatter.cover_items_per_cluster:
		# Each cluster consumes identical randomness in every overlapping chunk.
		var at: Vector2 = centre + Vector2.from_angle(random.randf() * TAU) * sqrt(random.randf()) * spread
		var family: String = profile.family_at(random.randf())
		var height: float = random.randf_range(profile.height_metres.x, profile.height_metres.y)
		var variation: float = random.randf()
		var sparse_roll: float = random.randf()
		if not active or not bounds.has_point(at) or sparse_roll < profile.bare_fraction: continue
		if _count >= world.scatter.cover_max_items_per_chunk: continue
		var on_road: bool = false
		var shoulder: bool = false
		for road: Dictionary in roads:
			var distance: float = at.distance_to(Geometry2D.get_closest_point_to_segment(at, road.a, road.b))
			if distance < float(road.width) * 0.48: on_road = true
			elif distance < float(road.width) * 0.5 + 1.1: shoulder = true
		var blocked: bool = false
		var wet: bool = false
		var masonry: bool = false
		for context: Dictionary in contexts:
			if context.kind == "solid" or context.kind == "water":
				var rect: Rect2 = context.bounds
				if not rect.grow(2.0).has_point(at): continue
				if Geometry2D.is_point_in_polygon(at, context.polygon): blocked = true; break
				var edge_distance: float = _edge_distance(at,context.polygon)
				if context.kind == "water" and edge_distance<2.0: wet = true
				elif context.kind == "solid" and edge_distance<1.2: masonry = true
			elif context.kind == "access":
				if at.distance_to(Geometry2D.get_closest_point_to_segment(at, context.a, context.b)) < float(context.width) * 0.5: on_road = true
			elif context.kind == "clear":
				if context.bounds.has_point(at): on_road = true
		if blocked: continue
		if on_road:
			if variation > 0.15: continue
			family = "stone" if variation < 0.05 else "litter"
			height *= 0.28
		elif wet:
			family = "reeds" if variation > 0.3 else "moss"
			height = minf(0.85, height * 1.6)
		elif masonry and variation < 0.55:
			family = "moss" if variation < 0.35 else "fern"
		elif not shoulder:
			for tree: Vector2 in trees:
				if at.distance_squared_to(tree) < 2.8 * 2.8:
					var fallen: String = "needle" if profile.families.has("needle") else "litter"
					family = fallen if variation < 0.65 else ("root" if variation < 0.8 else "fern")
					break
		if shoulder: height *= 0.7
		var tint: Color = profile.foliage.lerp(world.vegetation_at(at), 0.35).lerp(profile.dry_foliage, variation * 0.35)
		_stamp(at, family, height, variation, tint, profile)
		_count += 1

func _mesh() -> ArrayMesh:
	if indices.is_empty(): return null
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_TEX_UV] = weights
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

func _edge_distance(at: Vector2, polygon: PackedVector2Array) -> float:
	var closest: float = INF
	for index in polygon.size():
		closest = minf(closest,at.distance_to(Geometry2D.get_closest_point_to_segment(at,polygon[index],polygon[(index+1)%polygon.size()])))
	return closest

func _triangle(a: Vector2, b: Vector2, c: Vector2, tint: Color, bend: Vector3 = Vector3.ZERO, phase: float = 0.0) -> void:
	var offset: int = vertices.size()
	for point: Vector2 in [a, b, c]: vertices.append((point - tile.position) * 128.0)
	colors.append_array(PackedColorArray([tint, tint, tint]))
	weights.append_array(PackedVector2Array([Vector2(bend.x, phase), Vector2(bend.y, phase), Vector2(bend.z, phase)]))
	indices.append_array(PackedInt32Array([offset, offset+1, offset+2]))

func _stroke(a: Vector2, b: Vector2, width: float, tint: Color) -> void:
	var normal: Vector2 = (b-a).normalized().orthogonal() * width * 0.5
	_triangle(a+normal, b+normal, b-normal, tint)
	_triangle(a+normal, b-normal, a-normal, tint)

func _stamp(at: Vector2, family: String, height: float, variation: float, tint: Color, profile: GroundCoverProfile) -> void:
	var phase: float = variation * TAU + at.x * 0.21 + at.y * 0.13
	match family:
		"grass", "reeds":
			for blade in 5:
				var root: Vector2 = at + Vector2((blade-2)*height*0.16, sin(blade+phase)*height*0.12)
				var tip: Vector2 = root + Vector2(sin(phase+blade)*height*0.35, -height*(0.65+float(blade%3)*0.17))
				var width: float = height * 0.065
				_triangle(root-Vector2(width, 0), tip, root+Vector2(width, 0), tint.darkened(float(blade%2)*0.12), Vector3(0, profile.wind_response, 0), phase)
				if family == "reeds" and blade%2 == 0:
					_triangle(tip+Vector2(-0.028, 0.02), tip+Vector2(0, -0.14), tip+Vector2(0.035, 0.02), profile.dry_foliage, Vector3.ONE*profile.wind_response, phase)
		"shrub":
			for layer in 3:
				var centre: Vector2 = at+Vector2(sin(phase+layer)*height*0.2,-height*(0.2+layer*0.2))
				for edge in 7:
					var spread := Vector2(height*(0.7-layer*0.1),height*0.27)
					_triangle(centre,centre+Vector2.from_angle(edge*TAU/7.0)*spread,centre+Vector2.from_angle((edge+1)*TAU/7.0)*spread,tint.darkened(0.22-layer*0.06),Vector3.ONE*(0.15+layer*0.15)*profile.wind_response,phase)
		"needle":
			for needle in 4:
				var root: Vector2 = at+Vector2.from_angle(phase+needle)*height*0.3
				_stroke(root,root+Vector2.from_angle(phase+needle*0.5)*height,0.013,profile.litter)
		"fern":
			for frond in 5:
				var direction := Vector2.from_angle(-PI + float(frond)*PI/4.0)
				var tip: Vector2 = at+direction*height*1.1+Vector2(0, -height*0.25)
				for leaflet in range(1, 4):
					var root: Vector2 = at.lerp(tip, float(leaflet)*0.22)
					var span: Vector2 = direction.orthogonal()*height*(0.3-float(leaflet)*0.04)
					_triangle(root, root+span-direction*height*0.12, root+direction*height*0.24, tint, Vector3(0.1, 0.45, 0.3)*profile.wind_response, phase)
					_triangle(root, root-span-direction*height*0.12, root+direction*height*0.24, tint.darkened(0.1), Vector3(0.1, 0.45, 0.3)*profile.wind_response, phase)
		"branch", "root":
			var end: Vector2 = at+Vector2.from_angle(phase)*height*2.0
			_stroke(at, end, height*0.1, profile.litter.darkened(0.15))
			_stroke(at.lerp(end, 0.5), at.lerp(end, 0.5)+Vector2.from_angle(phase+0.8)*height*0.65, height*0.065, profile.litter)
		"moss":
			for patch in 3:
				var centre: Vector2 = at+Vector2.from_angle(phase+patch*2.0)*height*0.4
				for edge in 6:
					_triangle(centre, centre+Vector2.from_angle(edge*TAU/6.0)*height, centre+Vector2.from_angle((edge+1)*TAU/6.0)*height, tint.darkened(0.32))
		_:
			var width: float = height * (0.7 if family == "stone" else 0.45)
			var color: Color = profile.stone.darkened(variation*0.18) if family == "stone" else profile.litter.lightened(variation*0.08)
			_triangle(at+Vector2(-width, 0), at+Vector2(-width*0.2, -height*0.35), at+Vector2(width, height*0.15), color)
			_triangle(at+Vector2(-width, 0), at+Vector2(width, height*0.15), at+Vector2(0, height*0.28), color.darkened(0.15))
