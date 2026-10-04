@tool
extends Node2D
## Reference scene: every ground-art coordinate below is authored in metres.
const UNITS_PER_METRE: float = 128.0
const CLEARING_RADIUS := Vector2(9, 7)
const SHRINE_METRES := Vector2(-2, -2)
const FIRE_METRES := Vector2(2.8, 0.5)
@export var ground_seed: int = 1731
var overworld: StillwoodOverworld
@export var region_definition: OverworldDefinition = preload("res://data/stillwood_region.tres")
var _preview_rebuild_queued: bool = false
var _region_building: bool = false
@export_group("Editor Preview")
## The editor add-on requests nearby detail after panning settles. Manual scenes
## remain editable; generated terrain/dressing has no owner and is never saved.
@export var preview_follow_viewport: bool = true
## Preview a local area without rebuilding the full region when scenes reopen.
@export var preview_center_metres := Vector2.ZERO
@export_range(16, 64, 1) var preview_half_extent_metres: float = 32.0
## Toggle in the Inspector after editing routes, biomes, or landmark placements.
@export var rebuild_region_preview: bool = false:
	set(value):
		if value and Engine.is_editor_hint() and is_inside_tree() and not _preview_rebuild_queued and not _region_building:
			_preview_rebuild_queued = true
			call_deferred("_rebuild_region")
		rebuild_region_preview = false
var prewarm_time: float = 0.0

func _ready() -> void:
	queue_redraw()
	if Engine.is_editor_hint():
		# Scene restoration must not synchronously generate/draw the entire overworld.
		# Defer the initial preview; detail meshes/vegetation are then queued in batches.
		set_physics_process(false)
		rebuild_region_preview = true
		return
	_rebuild_region()
	var player: PlayerController = $Actors/Player
	player.camera.limit_left = roundi(overworld.world_bounds.position.x)
	player.camera.limit_right = roundi(overworld.world_bounds.end.x)
	player.camera.limit_top = roundi(overworld.world_bounds.position.y)
	player.camera.limit_bottom = roundi(overworld.world_bounds.end.y)
	player.camera.limit_smoothed = true
	var hud := CanvasLayer.new()
	hud.set_script(preload("res://scripts/court_hud.gd"))
	hud.set("area_title", "THE STILLWOOD")
	hud.set("area_subtitle", "A small fire beneath old branches")
	add_child(hud)

func preview_editor_view(world_view: Rect2) -> void:
	if not Engine.is_editor_hint() or not preview_follow_viewport or _region_building: return
	var center: Vector2 = world_view.get_center() / UNITS_PER_METRE
	var extent: float = clampf(maxf(world_view.size.x, world_view.size.y) / (2.0 * UNITS_PER_METRE) + 8.0, 16.0, 64.0)
	# Keep a margin of detailed art; don't rebuild for every pixel of editor panning.
	if is_instance_valid(overworld) and center.distance_to(preview_center_metres) < preview_half_extent_metres * 0.4 and absf(extent - preview_half_extent_metres) < 8.0: return
	preview_center_metres = center.snapped(Vector2.ONE * 16.0)
	preview_half_extent_metres = ceilf(extent / 8.0) * 8.0
	rebuild_region_preview = true

func _rebuild_region() -> void:
	_preview_rebuild_queued = false
	if not is_inside_tree() or _region_building: return
	_region_building = true
	# Tags also recover generated previews after a tool-script reload loses references.
	# Never remove owned/authored children, or the editable landmark scene instances.
	for node: Node in $Actors.get_children():
		if node.owner==null and node.has_meta("region_generator"):
			$Actors.remove_child(node)
			node.queue_free()
	for node: Node in get_children():
		if node.owner==null and node is StillwoodOverworld:
			remove_child(node)
			node.queue_free()
	overworld = StillwoodOverworld.new()
	overworld.name = "StillwoodRegion"
	overworld.definition = region_definition
	if Engine.is_editor_hint():
		var extent: float = clampf(preview_half_extent_metres,16.0,64.0)
		overworld.preview_bounds_metres = Rect2(preview_center_metres-Vector2.ONE*extent,Vector2.ONE*extent*2.0)
	add_child(overworld)
	overworld.build(self)
	_region_building = false
	# All old clearing barriers were removed from the authored scene. Never delete
	# manual nodes by name here: designers can now place their own boundary objects.
	if Engine.is_editor_hint(): return
	var navigation := $SpellNavigation as SpellNavigation
	navigation.bounds = overworld.world_bounds
	navigation.cell_size = 128
	navigation.agent_radius = 64
	navigation.local_windows = true
	navigation.invalidate_windows()

func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint(): return
	prewarm_time -= delta
	if prewarm_time <= 0:
		prewarm_time = 0.5
		($SpellNavigation as SpellNavigation).prewarm($Actors/Player)

func get_world_map_data() -> Dictionary:
	var data: Dictionary = overworld.map_data() if is_instance_valid(overworld) else {}
	data["name"] = "The Stillwood March"
	data["clearing"] = Rect2(-CLEARING_RADIUS * UNITS_PER_METRE, CLEARING_RADIUS * 2 * UNITS_PER_METRE)
	return data

func _patch(at: Vector2, radius: Vector2, color: Color, random: RandomNumberGenerator) -> void:
	var points := PackedVector2Array()
	for i in 16:
		var angle: float = float(i) * TAU / 16.0
		points.append(at + Vector2(cos(angle), sin(angle)) * radius * random.randf_range(0.9, 1.1))
	draw_colored_polygon(points, color)

func _draw() -> void:
	var random := RandomNumberGenerator.new()
	random.seed = ground_seed
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE * UNITS_PER_METRE)
	_draw_clearing_blend()
	# 0.35–0.5 m stepping stones, at comfortable 0.65 m intervals.
	for i in 6:
		var at: Vector2 = SHRINE_METRES + Vector2(0, 0.8 + i * 0.65)
		_patch(at + Vector2(0.03, 0.05), Vector2(0.25, 0.16), Color("252c27"), random)
		_patch(at, Vector2(0.23, 0.14), Color("6b7162"), random)
	_patch(SHRINE_METRES, Vector2(1.3, 0.9), Color("333e35"), random)
	for i in 12:
		var at: Vector2 = SHRINE_METRES + Vector2(cos(i * TAU / 12) * 1.15, sin(i * TAU / 12) * 0.8)
		_patch(at, Vector2(0.12, 0.08), Color("727669"), random)
	# A pair of abandoned bedrolls and firewood: a camp, not a settlement.
	for at: Vector2 in [Vector2(1, 3), Vector2(3, 3.8)]:
		draw_rect(Rect2(at + Vector2(0.04, 0.06), Vector2(0.7, 1.8)), Color("202a25"))
		draw_rect(Rect2(at, Vector2(0.65, 1.75)), Color("655d46"))
		draw_rect(Rect2(at, Vector2(0.65, 0.3)), Color("817458"))
	for i in 4:
		draw_line(Vector2(4.1, 1.8 + i * 0.16), Vector2(5.0, 1.9 + i * 0.16), Color("534632"), 0.12)
	draw_set_transform(Vector2.ZERO)

func _draw_clearing_blend() -> void:
	# Feather the original camp footprint into biome soil, not a hard disc edge.
	var inner := PackedVector2Array()
	var outer := PackedVector2Array()
	for index in 32:
		var angle: float = index*TAU/32.0
		var direction := Vector2.from_angle(angle)
		var irregularity: float = 1.0+sin(angle*5.0+0.4)*0.045+cos(angle*9.0)*0.025
		inner.append(direction*CLEARING_RADIUS*0.78*irregularity)
		outer.append(direction*Vector2(10.5,8.5)*irregularity)
	draw_colored_polygon(inner,Color("48483a"))
	for index in 32:
		var next: int = (index+1)%32
		var ring := PackedVector2Array([inner[index],inner[next],outer[next],outer[index]])
		draw_polygon(ring,PackedColorArray([Color("48483a"),Color("48483a"),Color(0.28,0.28,0.23,0),Color(0.28,0.28,0.23,0)]))
