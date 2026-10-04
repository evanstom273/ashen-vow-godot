@tool
class_name RegionDressingExclusion
extends Node2D
## An editable reservation for generated trees/roadside props. No collision.
@export var bounds_metres := Rect2(-4, -4, 8, 8):
	set(value):
		bounds_metres = value
		queue_redraw()

func world_bounds_metres() -> Rect2:
	var corners: PackedVector2Array = RegionGeometry.rect_polygon(bounds_metres)
	var result := Rect2(to_global(corners[0] * 128) / 128, Vector2.ZERO)
	for corner: Vector2 in corners: result = result.expand(to_global(corner * 128) / 128)
	return result

func _draw() -> void:
	if not Engine.is_editor_hint(): return
	var rect := Rect2(bounds_metres.position * 128, bounds_metres.size * 128)
	draw_rect(rect, Color(0.8, 0.65, 0.3, 0.06))
	draw_rect(rect, Color(0.8, 0.65, 0.3, 0.5), false, 3.0)
