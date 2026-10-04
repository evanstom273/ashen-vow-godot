@tool
class_name BuildingFloor
extends Node2D
## Floor-owned collision registration and independently configurable visual layers.
@export var definition: BuildingFloorDefinition
@export_group("Visual paths (relative to this floor)")
@export var floor_art: Array[NodePath] = []
@export var interior_art: Array[NodePath] = []
@export var permanent_walls: Array[NodePath] = []
@export var roof_art: Array[NodePath] = []
@export var upper_facade: Array[NodePath] = []
## Cosmetic-only nodes; never list actor controllers or collision hierarchies.
@export var suspend_when_hidden: Array[NodePath] = []
var _layers: Array[Dictionary] = []
var _cosmetics: Array[Dictionary] = []
var _interior_opacity: float = 0.0
var _duration: float = 0.22
var _occupant_target: float = 0.0
var _initialized: bool = false

func _enter_tree() -> void:
	if definition != null and definition.elevation != null:
		set_meta(&"elevation_definition", definition.elevation)

func _ready() -> void:
	y_sort_enabled = true
	if not Engine.is_editor_hint():
		_cache_layers()
		Elevation.of(self).register_floor(self)
		Elevation.register_tree(self)
	set_process(false)

func storey() -> int:
	return definition.elevation.level if definition != null and definition.elevation != null else 0

static func storey_of(node: Node) -> int:
	return Elevation.level(node)

func content_opacity() -> float:
	return smoothstep(0.0, 1.0, _interior_opacity)

func contains_world(point: Vector2) -> bool:
	if definition == null: return false
	var local_metres: Vector2 = to_local(point) / WorldScale.UNITS_PER_METRE
	for polygon: PackedVector2Array in definition.regions_metres:
		if polygon.size() >= 3 and Geometry2D.is_point_in_polygon(local_metres, polygon): return true
	return false

func _cache_layers() -> void:
	_layers.clear()
	for kind: String in ["floor_art", "interior_art", "permanent_walls", "roof_art", "upper_facade"]:
		var paths: Array[NodePath] = []
		paths.assign(get(kind))
		for path: NodePath in paths:
			var item := get_node_or_null(path) as CanvasItem
			if item == null:
				push_warning("BuildingFloor visual path is missing: " + String(path))
				continue
			_layers.append({"item": weakref(item), "kind": kind, "base": item.modulate, "alpha": 1.0, "target": 1.0})
	for path: NodePath in suspend_when_hidden:
		var cosmetic: Node = get_node_or_null(path)
		if cosmetic != null:
			_cosmetics.append({"node": weakref(cosmetic), "mode": cosmetic.process_mode})

func set_presentation(interior: float, walls: float, roof: float, duration: float, immediate: bool = false) -> void:
	_duration = maxf(0.01, duration)
	_occupant_target = interior
	for layer: Dictionary in _layers:
		match String(layer.kind):
			"roof_art", "upper_facade": layer.target = roof
			"permanent_walls": layer.target = walls
			_: layer.target = interior
		if immediate or not _initialized: layer.alpha = layer.target
	if immediate or not _initialized: _interior_opacity = interior
	_initialized = true
	_apply_layers()
	set_process(not Engine.is_editor_hint())

## Generated encounters remain under the world's existing actor/Y-sort hierarchy.
## Runtime state is independent of parentage, allowing actors to use stairs later.
func attach_occupant(actor: Node2D) -> void:
	if actor is CollisionObject2D: Elevation.set_level(actor, storey())
	else: actor.set_meta(&"elevation_level", storey())
	Elevation.register_visual(actor)

func _process(delta: float) -> void:
	var changing: bool = false
	for layer: Dictionary in _layers:
		layer.alpha = move_toward(float(layer.alpha), float(layer.target), delta / _duration)
		changing = changing or not is_equal_approx(float(layer.alpha), float(layer.target))
	_interior_opacity = move_toward(_interior_opacity, _occupant_target, delta / _duration)
	_apply_layers()
	# Settled floors do not run an idle per-frame loop; actor visibility is shared.
	if not changing and is_equal_approx(_interior_opacity, _occupant_target): set_process(false)

func _apply_layers() -> void:
	for layer: Dictionary in _layers:
		var item: Variant = layer.item.get_ref()
		if not is_instance_valid(item): continue
		var tint: Color = layer.base
		tint.a *= smoothstep(0.0, 1.0, float(layer.alpha))
		item.modulate = tint
	for entry: Dictionary in _cosmetics:
		var cosmetic: Variant = entry.node.get_ref()
		if not is_instance_valid(cosmetic): continue
		cosmetic.process_mode = Node.PROCESS_MODE_DISABLED if _interior_opacity <= 0.001 else int(entry.mode)

func _exit_tree() -> void:
	for layer: Dictionary in _layers:
		var item: Variant = layer.item.get_ref()
		if is_instance_valid(item): item.modulate = layer.base
	for entry: Dictionary in _cosmetics:
		var cosmetic: Variant = entry.node.get_ref()
		if is_instance_valid(cosmetic): cosmetic.process_mode = int(entry.mode)
