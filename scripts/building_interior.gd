@tool
class_name BuildingInterior
extends Node2D
## One cheap containment check per building when the viewer moves, not per prop.
@export var definition: BuildingDefinition
@export_group("Editor preview")
@export var preview_interior: bool = false:
	set(value):
		preview_interior = value
		if Engine.is_editor_hint() and is_inside_tree(): call_deferred("_refresh_preview")
@export var preview_level: int = 0:
	set(value):
		preview_level = value
		if Engine.is_editor_hint() and is_inside_tree(): call_deferred("_refresh_preview")
@export_tool_button("Refresh building preview") var refresh_preview: Callable = _refresh_preview
var _floors: Array[BuildingFloor] = []
var _viewer: Node2D
var _last_position := Vector2(INF, INF)
var _last_level: int = 0
var _last_airborne: bool = false
var _last_alive: bool = true
var _was_inside: bool = false
var _last_preview: Dictionary = {}

func _ready() -> void:
	y_sort_enabled = true
	_collect_floors(self)
	if definition == null:
		push_warning("BuildingInterior requires a BuildingDefinition")
		set_process(false)
		return
	if Engine.is_editor_hint():
		_refresh_preview()
		set_process(false)
	else:
		_present(false, 0, true)
		process_mode = Node.PROCESS_MODE_PAUSABLE

func _refresh_preview() -> void:
	# Never write preview opacity into scene properties that the editor might save.
	_floors.clear()
	_collect_floors(self)
	for floor_layer: BuildingFloor in _floors:
		for path: NodePath in floor_layer.roof_art:
			var roof := floor_layer.get_node_or_null(path) as BuildingRoof
			if roof != null:
				roof.preview_hidden = preview_interior and floor_layer.storey() >= preview_level
				roof.queue_redraw()

func _collect_floors(root: Node) -> void:
	for child: Node in root.get_children():
		if child is BuildingFloor: _floors.append(child as BuildingFloor)
		elif not child is BuildingInterior: _collect_floors(child)

func _process(_delta: float) -> void:
	if not is_instance_valid(_viewer):
		_viewer = get_tree().get_first_node_in_group("player") as Node2D
		_last_position = Vector2(INF, INF)
	if not is_instance_valid(_viewer):
		if _was_inside:
			_present(false, _last_level)
			_was_inside = false
		return
	var current_level: int = BuildingFloor.storey_of(_viewer)
	var stair_preview: Dictionary = Elevation.of(self).preview(_viewer)
	var airborne: bool = _viewer.has_method("has_traversal_tag") and bool(_viewer.call("has_traversal_tag", &"airborne"))
	var viewer_health: Variant = _viewer.get("health")
	var alive: bool = viewer_health == null or float(viewer_health) > 0
	if _viewer.global_position == _last_position and current_level == _last_level and airborne == _last_airborne and alive == _last_alive and stair_preview == _last_preview: return
	var previous_level: int = _last_level
	_last_position = _viewer.global_position
	_last_level = current_level
	_last_airborne = airborne
	_last_alive = alive
	var inside: bool = false
	if alive and (not airborne or definition.reveal_while_airborne):
		for floor_layer: BuildingFloor in _floors:
			if floor_layer.storey() == current_level and floor_layer.contains_world(_last_position):
				inside = true
				break
	if not stair_preview.is_empty():
		for floor_layer: BuildingFloor in _floors:
			if floor_layer.storey() in [int(stair_preview.from), int(stair_preview.to)] and floor_layer.contains_world(_last_position): inside = alive
	if inside == _was_inside and current_level == previous_level and stair_preview == _last_preview: return
	_was_inside = inside
	_last_preview = stair_preview
	_present(inside, current_level, false, stair_preview)

func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if definition == null: warnings.append("Assign a BuildingDefinition.")
	return warnings

func _present(inside: bool, active_level: int, immediate: bool = false, stair_preview: Dictionary = {}) -> void:
	for floor_layer: BuildingFloor in _floors:
		var opacity: float = definition.outside_interior_opacity
		var walls: float = 1.0
		var roof: float = 1.0
		if floor_layer.definition != null and not floor_layer.definition.enclosed: opacity = 1.0
		if inside:
			opacity = 1.0 if floor_layer.storey() == active_level else (definition.lower_floor_opacity if floor_layer.storey() < active_level else definition.upper_floor_opacity)
			if not stair_preview.is_empty():
				var blend: float = smoothstep(0.0, 1.0, clampf(float(stair_preview.blend), 0, 1))
				if floor_layer.storey() == int(stair_preview.from): opacity = lerpf(1.0, definition.lower_floor_opacity, blend)
				elif floor_layer.storey() == int(stair_preview.to): opacity = lerpf(definition.lower_floor_opacity, 1.0, blend)
			walls = opacity
			roof = 0.0
		floor_layer.set_presentation(opacity, walls, roof, definition.fade_seconds, immediate)
