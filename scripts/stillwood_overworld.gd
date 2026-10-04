@tool
class_name StillwoodOverworld
extends Node2D
const PROP = preload("res://scripts/overworld_prop.gd")
const TREE = preload("res://scripts/forest_tree.gd")
const GROUND = preload("res://scripts/overworld_ground.gd")
const CLIFF = preload("res://scripts/region_cliff.gd")
@export var definition: OverworldDefinition = preload("res://data/stillwood_region.tres")
var world_bounds := Rect2()
var generated_actors: Node2D
var world_trees := PackedVector2Array()
var structures: Array[Dictionary] = []
var landmark_nodes: Array[RegionLandmark] = []
var biome_tiles: Array[Dictionary] = []
var segment_buckets: Dictionary = {}
var reservation_buckets: Dictionary = {}
var tree_buckets: Dictionary = {}
var cover_buckets: Dictionary = {}
var _cover_order: int = 0
var preview: bool = false
## Editor-only drawing window. Runtime always builds the complete region.
var preview_bounds_metres := Rect2(-32,-32,64,64)
var blocked_area_estimate: float = 0.0
## Cosmetic work only: collision and map data are ready before gameplay starts.
const DETAIL_CHUNKS_PER_FRAME: int = 2
const DETAIL_BUDGET_USEC: int = 2500
var _detail_queue: Array[Node2D] = []
var _detail_cache: Array[Node2D] = []
var _preview_dressing: Array[Dictionary] = []
var _overview: Node2D
var _detail_builds: int = 0
var _detail_build_usec: int = 0
var _first_detail_batch_reported: bool = false

func _ready() -> void:
	set_process(false)

func _queue_ground_detail(chunk: Node2D) -> void:
	if not _detail_queue.has(chunk): _detail_queue.append(chunk)
	set_process(true)

func _process(_delta: float) -> void:
	var started: int = Time.get_ticks_usec()
	var built: int = 0
	while not _detail_queue.is_empty() and built<DETAIL_CHUNKS_PER_FRAME:
		var pending: Variant = _detail_queue.pop_front()
		if not is_instance_valid(pending): continue
		var chunk: Node2D = pending
		if chunk.is_queued_for_deletion() or not chunk.is_inside_tree(): continue
		if not bool(chunk.get("detail_wanted")): continue
		if not _reserve_detail(chunk):
			_detail_queue.append(chunk)
			break # Low-detail ground stays visible if the view exceeds the budget.
		var complete: bool = bool(chunk.call("prepare_mesh"))
		if not complete: _detail_queue.append(chunk)
		else: _detail_builds += 1
		built += 1
		if Time.get_ticks_usec()-started>=DETAIL_BUDGET_USEC: break
	_detail_build_usec += Time.get_ticks_usec()-started
	# Editor artwork is instantiated a few objects at a time, never thousands on open.
	var dressed: int = 0
	while not _preview_dressing.is_empty() and dressed < 8 and Time.get_ticks_usec()-started < DETAIL_BUDGET_USEC:
		_instantiate_dressing(_preview_dressing.pop_front())
		dressed += 1
	if _detail_queue.is_empty() and _preview_dressing.is_empty():
		set_process(false)
		if not preview and not _first_detail_batch_reported and _detail_builds>0:
			_first_detail_batch_reported = true
			print("[Stillwood] Initial nearby terrain meshes: ",_detail_builds,"; preparation CPU time: ",_detail_build_usec/1000.0," ms (spread across frames)")

func _reserve_detail(chunk: Node2D) -> bool:
	if _detail_cache.has(chunk): return true
	for index in range(_detail_cache.size() - 1, -1, -1):
		if not is_instance_valid(_detail_cache[index]): _detail_cache.remove_at(index)
	var capacity: int = maxi(16, definition.scatter.detail_cache_chunks)
	if _detail_cache.size() >= capacity:
		var victim: int = -1
		for index in _detail_cache.size():
			if not bool(_detail_cache[index].get("detail_wanted")):
				victim = index
				break
		if victim < 0: return false
		_detail_cache[victim].call("discard_detail")
		_detail_cache.remove_at(victim)
	_detail_cache.append(chunk)
	return true

func build(camp: Node2D) -> void:
	preview = Engine.is_editor_hint()
	if definition == null or definition.scatter == null or definition.boundary.size()<3: return
	if not preview:
		var wind_clock: Node = get_node_or_null("/root/EnvironmentWind")
		if wind_clock != null: wind_clock.call("configure", definition.wind)
	var started_msec: int = Time.get_ticks_msec()
	print("[Stillwood] Begin ","local editor preview" if preview else "runtime region")
	var actors := camp.get_node("Actors") as Node2D
	generated_actors = Node2D.new()
	generated_actors.name = "GeneratedRegionDressing"
	generated_actors.y_sort_enabled = true
	generated_actors.set_meta("region_generator",get_instance_id())
	actors.add_child(generated_actors)
	var metre_bounds := Rect2(definition.boundary[0],Vector2.ZERO)
	for point: Vector2 in definition.boundary: metre_bounds = metre_bounds.expand(point)
	world_bounds = Rect2(metre_bounds.position*128,metre_bounds.size*128)
	_collect_authored(actors)
	_index_routes()
	print("[Stillwood] Building terrain")
	if preview:
		_overview = preload("res://scripts/region_editor_overview.gd").new()
		_overview.name = "EditorTerrainOverview"
		_overview.z_index = -2
		add_child(_overview)
		_overview.call("configure", definition, metre_bounds, preview_bounds_metres)
	_build_boundary()
	_roadside_details()
	print("[Stillwood] Placing vegetation")
	_plant_forest(metre_bounds)
	# Cover uses the already indexed tree roots and authored prop footprints.
	_build_ground(metre_bounds)
	print("[Stillwood] Generation complete in ",Time.get_ticks_msec()-started_msec," ms; terrain/boundary nodes: ",get_child_count(),"; generated actors: ",generated_actors.get_child_count())

func clear_generated() -> void:
	_detail_queue.clear()
	_detail_cache.clear()
	_preview_dressing.clear()
	set_process(false)
	if is_instance_valid(generated_actors):
		if generated_actors.get_parent()!=null: generated_actors.get_parent().remove_child(generated_actors)
		generated_actors.queue_free()
		generated_actors = null

func _exit_tree() -> void:
	_detail_queue.clear()
	_detail_cache.clear()
	_preview_dressing.clear()
	if is_instance_valid(generated_actors): generated_actors.queue_free()

func _bucket(at: Vector2) -> Vector2i:
	return Vector2i((at/16.0).floor())

func _index_rect(rect: Rect2, entry: Variant, index: Dictionary) -> void:
	var first: Vector2i = _bucket(rect.position)
	var last: Vector2i = _bucket(rect.end)
	for y in range(first.y,last.y+1):
		for x in range(first.x,last.x+1):
			var key := Vector2i(x,y)
			if not index.has(key): index[key] = []
			index[key].append(entry)

func _collect_authored(node: Node) -> void:
	if node == generated_actors: return
	if node is RegionLandmark or node is RegionCoverZone:
		var record: Dictionary = node.call("cover_record")
		if not record.is_empty():
			_cover_order += 1
			record["order"] = _cover_order
			_index_rect(record.bounds, record, cover_buckets)
	if node.has_method("cover_clearances"):
		for record: Dictionary in node.call("cover_clearances"):
			_index_rect(record.bounds, record, cover_buckets)
	if node is RegionLandmark:
		landmark_nodes.append(node)
		structures.append_array(node.map_floors())
		for rect: Rect2 in node.reserved_rects(): _index_rect(rect,rect,reservation_buckets)
	if node is OverworldProp:
		_register_prop(node)
		var shape: PackedVector2Array = node.map_shape()
		if not shape.is_empty():
			var rect := Rect2(shape[0]/128,Vector2.ZERO)
			for point: Vector2 in shape: rect = rect.expand(point/128)
			_index_rect(rect.grow(1),rect.grow(1),reservation_buckets)
			if node.solid or node.kind in ["pool", "bridge", "stairs"]:
				var polygon := PackedVector2Array()
				for point: Vector2 in shape: polygon.append(point/128.0)
				_index_cover_polygon(polygon, "water" if node.kind == "pool" else "solid")
	if node is CharacterBody2D and node.is_in_group("enemy"):
		var rect := Rect2(node.global_position/128-Vector2(2,2),Vector2(4,4))
		_index_rect(rect,rect,reservation_buckets)
		_index_rect(rect, {"kind":"clear", "bounds":rect}, cover_buckets)
	if node is RegionDressingExclusion:
		var rect: Rect2 = node.world_bounds_metres()
		_index_rect(rect, rect, reservation_buckets)
	if node.get_script()==TREE:
		var tree := node as StaticBody2D
		world_trees.append(tree.global_position)
		_add_tree_bucket(tree.global_position/128)
		var radius: float = float(tree.get("trunk_collision_radius"))
		if radius<=0: radius=17.0*float(tree.get("tree_scale"))
		blocked_area_estimate += PI*pow(radius/128.0,2)*absf(tree.global_scale.x*tree.global_scale.y)
	for child: Node in node.get_children(): _collect_authored(child)

func _index_cover_polygon(polygon: PackedVector2Array, kind: String) -> void:
	if polygon.is_empty(): return
	var bounds := Rect2(polygon[0], Vector2.ZERO)
	for point: Vector2 in polygon: bounds = bounds.expand(point)
	var entry: Dictionary = {"kind":kind, "polygon":polygon, "bounds":bounds}
	_index_rect(bounds.grow(2.5), entry, cover_buckets)

func _register_prop(prop: OverworldProp) -> void:
	var shape: PackedVector2Array = prop.map_shape()
	structures.append({"polygon":shape,"position":prop.global_position,"size":prop.footprint*128,"kind":prop.kind})
	if prop.solid: blocked_area_estimate += RegionGeometry.area(shape)/(128.0*128.0)

func _index_routes() -> void:
	for route: RegionRouteDefinition in definition.routes:
		for i in range(1,route.points_metres.size()):
			var a: Vector2 = route.points_metres[i-1]
			var b: Vector2 = route.points_metres[i]
			var segment: Dictionary = {"a":a,"b":b,"width":route.width_metres,"route":route}
			var rect: Rect2 = Rect2(a,Vector2.ZERO).expand(b).grow(route.width_metres+3)
			_index_rect(rect,segment,segment_buckets)

func _build_ground(metre_bounds: Rect2) -> void:
	var side: int = definition.scatter.chunk_metres
	var draw_bounds: Rect2 = metre_bounds.intersection(preview_bounds_metres) if preview else metre_bounds
	if not draw_bounds.has_area(): return
	var ribbons: Dictionary = {}
	for route: RegionRouteDefinition in definition.routes:
		ribbons[route] = [RegionGeometry.ribbon(route,1.4),RegionGeometry.ribbon(route)]
	for y in range(floori(draw_bounds.position.y/side)-2,ceili(draw_bounds.end.y/side)+2):
		for x in range(floori(draw_bounds.position.x/side)-2,ceili(draw_bounds.end.x/side)+2):
			var at := Vector2(x,y)*side
			var ground := GROUND.new()
			ground.definition = definition
			ground.tile_metres = at
			ground.position = at*128
			ground.seed_value = definition.scatter.seed_value+x*1723+y*631
			ground.z_index = -1
			ground.mesh_requested.connect(_queue_ground_detail)
			var tile_bounds := Rect2(at,Vector2.ONE*side)
			var seen_cover: Array[Dictionary] = []
			for by in range(_bucket(at-Vector2.ONE*4).y,_bucket(at+Vector2.ONE*(side+4)).y+1):
				for bx in range(_bucket(at-Vector2.ONE*4).x,_bucket(at+Vector2.ONE*(side+4)).x+1):
					var key := Vector2i(bx,by)
					for entry: Dictionary in cover_buckets.get(key,[]):
						if not seen_cover.has(entry): seen_cover.append(entry)
					for tree: Vector2 in tree_buckets.get(key,[]): ground.nearby_trees.append(tree)
			# The same overlap order on both sides of every chunk boundary.
			seen_cover.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return int(a.get("order",0))<int(b.get("order",0)))
			ground.cover_contexts = seen_cover
			var candidates: Array[RegionRouteDefinition] = []
			var seen_segments: Dictionary = {}
			for by in range(_bucket(at).y,_bucket(at+Vector2.ONE*side).y+1):
				for bx in range(_bucket(at).x,_bucket(at+Vector2.ONE*side).x+1):
					for segment: Dictionary in segment_buckets.get(Vector2i(bx,by),[]):
						var route: RegionRouteDefinition = segment.route
						if not candidates.has(route): candidates.append(route)
						var signature: String = str([segment.a,segment.b])
						if not seen_segments.has(signature):
							ground.road_segments.append(segment)
							seen_segments[signature]=true
			for route: RegionRouteDefinition in candidates:
				ground.shoulder_polygons.append_array(RegionGeometry.clip_local_polygons(ribbons[route][0],tile_bounds))
				ground.road_polygons.append_array(RegionGeometry.clip_local_polygons(ribbons[route][1],tile_bounds))
			add_child(ground)
			for piece: PackedVector2Array in RegionGeometry.clip_local_polygons(definition.boundary,tile_bounds):
				var world_polygon := PackedVector2Array()
				var colors := PackedColorArray()
				for point: Vector2 in piece:
					var world_metres: Vector2 = point+at
					world_polygon.append(world_metres*128)
					colors.append(definition.soil_at(world_metres).lightened(0.12))
				biome_tiles.append({"polygon":world_polygon,"colors":colors})

func _build_boundary() -> void:
	for i in definition.boundary.size():
		var edge := CLIFF.new()
		edge.from_metres = definition.boundary[i]
		edge.to_metres = definition.boundary[(i+1)%definition.boundary.size()]
		edge.variant = i
		edge.z_index = 4
		add_child(edge)
		blocked_area_estimate += edge.from_metres.distance_to(edge.to_metres)*2.0

func _reserved(at: Vector2) -> bool:
	if Rect2(-33,-25,66,50).has_point(at): return true
	for rect: Rect2 in reservation_buckets.get(_bucket(at),[]):
		if rect.has_point(at): return true
	for segment: Dictionary in segment_buckets.get(_bucket(at),[]):
		if at.distance_to(Geometry2D.get_closest_point_to_segment(at,segment.a,segment.b)) < float(segment.width)*0.5+definition.scatter.route_clearance_metres: return true
	return false

func _add_tree_bucket(at: Vector2) -> void:
	var key: Vector2i = _bucket(at)
	if not tree_buckets.has(key): tree_buckets[key]=[]
	tree_buckets[key].append(at)

func _near_tree(at: Vector2) -> bool:
	var key: Vector2i = _bucket(at)
	for y in range(key.y-1,key.y+2):
		for x in range(key.x-1,key.x+2):
			for other: Vector2 in tree_buckets.get(Vector2i(x,y),[]):
				if at.distance_to(other)<definition.scatter.tree_spacing_metres: return true
	return false

func _plant_forest(metre_bounds: Rect2) -> void:
	var random := RandomNumberGenerator.new()
	random.seed = definition.scatter.seed_value
	var spacing: float = definition.scatter.tree_spacing_metres
	var serial: int = 0
	for y in range(floori(metre_bounds.position.y/spacing),ceili(metre_bounds.end.y/spacing)):
		for x in range(floori(metre_bounds.position.x/spacing),ceili(metre_bounds.end.x/spacing)):
			var at := Vector2(x+random.randf(),y+random.randf())*spacing
			serial += 1
			if not Geometry2D.is_point_in_polygon(at,definition.boundary) or _reserved(at): continue
			var biome: RegionBiomeDefinition = definition.dominant_biome(at)
			if biome == null: continue
			var density: float = definition.tree_density_at(at)*(0.4 if sin(at.x*0.07)+cos(at.y*0.11)<-0.6 else 1.0)
			if random.randf()>density or _near_tree(at): continue
			# Consume the same random values and reserve every accepted tree, even when
			# its artwork is outside the preview. Local preview placement matches runtime.
			var visual_scale: float = random.randf_range(5,7.2)
			var collision_radius: float = random.randf_range(38,56)
			_add_tree_bucket(at)
			# A separate roll changes ART families only; placement RNG/collision stay exact.
			var family_roll: float = fposmod(sin(float(serial)*127.1+at.x*0.31+at.y*0.17)*43758.5453,1.0)
			var art_biome: RegionBiomeDefinition = definition.blended_biome(at, family_roll)
			var record: Dictionary = {"tree": true, "at": at, "scale": visual_scale,
				"family": art_biome.tree_family,
				"variation": serial*31, "radius": collision_radius}
			if preview:
				_overview.call("add_tree", at, int(record.family), visual_scale)
				if not preview_bounds_metres.grow(12).has_point(at): continue
				_preview_dressing.append(record)
				set_process(true)
			else:
				_instantiate_dressing(record)

func _prop(at: Vector2, kind: String, footprint: Vector2, height: float, variant: int) -> void:
	# Reserve complete scenery footprints before planting, not just their centres.
	var occupied := Rect2(at-footprint*0.5,footprint).grow(0.5)
	for point: Vector2 in RegionGeometry.rect_polygon(occupied):
		if not Geometry2D.is_point_in_polygon(point,definition.boundary) or _reserved(point): return
	if _reserved(at) or _near_tree(at): return
	var rect := Rect2(at-footprint*0.5-Vector2.ONE,footprint+Vector2.ONE*2)
	_index_rect(rect,rect,reservation_buckets)
	_index_cover_polygon(RegionGeometry.rect_polygon(Rect2(at-footprint*0.5,footprint)), "solid")
	var record: Dictionary = {"at": at, "kind": kind, "footprint": footprint, "height": height, "variation": variant}
	if preview:
		_overview.call("add_prop", at, footprint)
		if not preview_bounds_metres.grow(12).intersects(occupied): return
		_preview_dressing.append(record)
		set_process(true)
	else:
		_instantiate_dressing(record)

func _instantiate_dressing(record: Dictionary) -> void:
	if not is_instance_valid(generated_actors) or not generated_actors.is_inside_tree(): return
	if record.has("tree"):
		var tree := TREE.new()
		tree.position = Vector2(record.at)*128
		tree.tree_scale = float(record.scale)
		tree.tree_family = int(record.family)
		tree.variation = int(record.variation)
		tree.trunk_collision_radius = float(record.radius)
		tree.reveal_radius = 190
		tree.reveal_edge_softness = 64
		generated_actors.add_child(tree)
		world_trees.append(tree.global_position)
		blocked_area_estimate += PI*pow(tree.trunk_collision_radius/128,2)
	else:
		var prop := PROP.new()
		prop.position = Vector2(record.at)*128
		prop.kind = String(record.kind)
		prop.footprint = Vector2(record.footprint)
		prop.height_metres = float(record.height)
		prop.variation = int(record.variation)
		generated_actors.add_child(prop)
		_register_prop(prop)

func _roadside_details() -> void:
	var serial: int = 0
	for route: RegionRouteDefinition in definition.routes:
		var remaining: float = 32
		for i in range(1,route.points_metres.size()):
			var a: Vector2 = route.points_metres[i-1]
			var b: Vector2 = route.points_metres[i]
			var length: float = a.distance_to(b)
			var along: float = remaining
			while along<length:
				var tangent: Vector2 = (b-a).normalized()
				var side: float = 1.0 if serial%2==0 else -1.0
				var at: Vector2 = a+tangent*along+tangent.orthogonal()*side*(route.width_metres*0.5+5)
				var kinds: Array[String] = ["fallen_tree","grave","rock","camp","rubble"]
				var sizes: Array[Vector2] = [Vector2(4,0.8),Vector2(0.8,0.6),Vector2(3,2),Vector2(2.5,2),Vector2(2,1.4)]
				_prop(at,kinds[serial%5],sizes[serial%5],1.2,serial*17)
				serial += 1
				along += 32+float(serial%4)*4
			remaining = along-length

func map_data() -> Dictionary:
	var routes: Array[Dictionary] = []
	for route: RegionRouteDefinition in definition.routes:
		var points := PackedVector2Array()
		for point: Vector2 in route.points_metres: points.append(point*128)
		routes.append({"points":points,"width":route.width_metres*128})
	var landmarks: Array[Dictionary] = []
	for landmark: RegionLandmark in landmark_nodes: landmarks.append(landmark.map_record())
	var boundary := PackedVector2Array()
	for point: Vector2 in definition.boundary: boundary.append(point*128)
	var woodland: Array[Dictionary] = []
	for key: Vector2i in tree_buckets:
		var count: int = tree_buckets[key].size()
		if count<2: continue
		woodland.append({"rect":Rect2(Vector2(key)*2048,Vector2.ONE*2048),"count":count})
	return {"bounds":world_bounds,"routes":routes,"landmarks":landmarks,"boundary":boundary,"structures":structures,"trees":world_trees,"biomes":biome_tiles,"woodland":woodland,"blocked_area_estimate_m2":blocked_area_estimate}
