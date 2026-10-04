@tool
class_name ElevationTransition
extends Node2D
## The middle of an authored corridor is the discrete collision-plane seam.
## Movement is swept to the seam before switching, never repositioned/teleported.
@export var definition: ElevationTransitionDefinition
@export_tool_button("Refresh stair preview") var refresh_preview: Callable = queue_redraw

func _ready() -> void:
	z_index = -9
	if not Engine.is_editor_hint() and valid_configuration(): Elevation.of(self).register_stairs(self)
	queue_redraw()

func valid_configuration() -> bool:
	return definition != null and definition.from_level != definition.to_level and definition.from_metres.distance_to(definition.to_metres) > 0.1 and definition.width_metres > 0

func progress(point: Vector2) -> float:
	if not valid_configuration(): return 0.0
	var at: Vector2 = to_local(point) / WorldScale.UNITS_PER_METRE
	var axis: Vector2 = definition.to_metres - definition.from_metres
	return (at - definition.from_metres).dot(axis) / axis.length_squared()

func contains_world(point: Vector2) -> bool:
	if not valid_configuration(): return false
	var at: Vector2 = to_local(point) / WorldScale.UNITS_PER_METRE
	var axis: Vector2 = definition.to_metres - definition.from_metres
	var p: float = progress(point)
	return p >= 0 and p <= 1 and absf((at - definition.from_metres).dot(axis.normalized().orthogonal())) <= definition.width_metres * 0.5

func supports(value: int, point: Vector2) -> bool:
	return valid_configuration() and value in [definition.from_level, definition.to_level] and contains_world(point)

func allows_actor(actor: Node2D) -> bool:
	if not valid_configuration() or Elevation.level(actor) not in [definition.from_level, definition.to_level]: return false
	# Query a capability, not the concrete player class: that class preloads its
	# loadout, whose spell scenes also use elevation. A type dependency loops back.
	if not definition.allow_airborne and actor.has_method("has_traversal_tag") and bool(actor.call("has_traversal_tag", &"airborne")): return false
	return true

func crossing(actor: CharacterBody2D, motion: Vector2) -> Dictionary:
	if not allows_actor(actor): return {}
	var start: float = progress(actor.global_position)
	var end: float = progress(actor.global_position + motion)
	var current: int = Elevation.level(actor)
	# Tolerate roundoff when reversing exactly on the seam.
	var forward: bool = current == definition.from_level and start <= 0.50001 and end > 0.5 and end > start
	var backward: bool = current == definition.to_level and start >= 0.49999 and end < 0.5 and end < start
	if not forward and not backward: return {}
	var fraction: float = clampf((0.5 - start) / (end - start), 0, 1)
	if not contains_world(actor.global_position + motion * fraction): return {}
	return {"fraction": fraction, "destination": definition.to_level if forward else definition.from_level}

func _get_configuration_warnings() -> PackedStringArray:
	return PackedStringArray() if valid_configuration() else PackedStringArray(["Assign a transition with distinct levels, separated endpoints and positive width."])

func _draw() -> void:
	if not valid_configuration() or not definition.draw_steps: return
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE * WorldScale.UNITS_PER_METRE)
	var axis: Vector2 = definition.to_metres - definition.from_metres
	var side: Vector2 = axis.normalized().orthogonal() * definition.width_metres * 0.5
	draw_colored_polygon(PackedVector2Array([definition.from_metres-side, definition.to_metres-side, definition.to_metres+side, definition.from_metres+side]), definition.step_color.darkened(0.3))
	var count: int = maxi(2, ceili(axis.length() / 0.3))
	for index in count + 1:
		var at: Vector2 = definition.from_metres.lerp(definition.to_metres, float(index) / count)
		draw_line(at-side, at+side, definition.step_color, 0.045, true)
	draw_set_transform(Vector2.ZERO)
