@tool
class_name RegionCoverZone
extends Node2D
## Optional local ground-cover override. No collision, navigation or tree exclusion.
@export var profile: GroundCoverProfile
@export var bounds_metres := Rect2(-10, -10, 20, 20):
	set(value):
		bounds_metres = value
		queue_redraw()
@export var bare_rects_metres: Array[Rect2] = []
@export var show_editor_bounds: bool = false:
	set(value):
		show_editor_bounds = value
		queue_redraw()

func _draw() -> void:
	if Engine.is_editor_hint() and show_editor_bounds:
		draw_rect(Rect2(bounds_metres.position*128.0,bounds_metres.size*128.0),Color(0.64,0.73,0.46,0.45),false,3.0)

func cover_clearances() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for rect: Rect2 in bare_rects_metres:
		var world := Rect2(to_global(rect.position*128.0)/128.0,Vector2.ZERO)
		for point: Vector2 in RegionGeometry.rect_polygon(rect): world = world.expand(to_global(point*128.0)/128.0)
		result.append({"kind":"clear", "bounds":world})
	return result

func cover_record() -> Dictionary:
	if profile == null: return {}
	var transform_metres := Transform2D(global_transform.x, global_transform.y, global_position/128.0)
	var rect := Rect2(transform_metres * bounds_metres.position, Vector2.ZERO)
	for point: Vector2 in RegionGeometry.rect_polygon(bounds_metres): rect = rect.expand(transform_metres * point)
	return {"kind":"profile", "profile":profile, "rect":bounds_metres, "inverse":transform_metres.affine_inverse(), "bounds":rect.grow(3.0)}
