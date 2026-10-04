@tool
class_name BuildingRoof
extends Node2D
## Opaque exterior artwork. Geometry is cached by CanvasItem, not rebuilt per frame.
@export var definition: BuildingRoofDefinition:
	set(value):
		if definition != null and definition.changed.is_connected(queue_redraw):
			definition.changed.disconnect(queue_redraw)
		definition = value
		if definition != null: definition.changed.connect(queue_redraw)
		queue_redraw()
var preview_hidden: bool = false

func _ready() -> void:
	# Above ground actors/architecture, below the existing airborne presentation (6).
	z_as_relative = false
	z_index = 5

func _polygon(points: PackedVector2Array, tint: Color) -> void:
	if points.size() >= 3 and not Geometry2D.triangulate_polygon(points).is_empty():
		draw_colored_polygon(points, tint)

func _draw() -> void:
	if Engine.is_editor_hint() and preview_hidden: return
	if definition == null or definition.outline_metres.size() < 3: return
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE * WorldScale.UNITS_PER_METRE)
	var outline: PackedVector2Array = definition.outline_metres
	_polygon(outline, definition.slate_color)
	for index in definition.panels_metres.size():
		var tint: Color = definition.panel_colors[index] if index < definition.panel_colors.size() else definition.slate_color
		_polygon(definition.panels_metres[index], tint)
	var bounds := Rect2(outline[0], Vector2.ZERO)
	for point: Vector2 in outline: bounds = bounds.expand(point)
	# Clip horizontal slate courses against the authored silhouette; handles concavity.
	var row: int = 0
	var spacing: float = maxf(0.2, definition.course_spacing_metres)
	var y: float = bounds.position.y + spacing
	while y < bounds.end.y:
		var intersections: Array[float] = []
		for index in outline.size():
			var a: Vector2 = outline[index]
			var b: Vector2 = outline[(index + 1) % outline.size()]
			if (a.y <= y and b.y > y) or (b.y <= y and a.y > y):
				intersections.append(lerpf(a.x, b.x, (y - a.y) / (b.y - a.y)))
		intersections.sort()
		for index in range(0, intersections.size() - 1, 2):
			var left: float = intersections[index] + 0.09
			var right: float = intersections[index + 1] - 0.09
			if right <= left: continue
			draw_line(Vector2(left, y), Vector2(right, y), Color("161e22"), 0.025, true)
			draw_line(Vector2(left, y + 0.045), Vector2(right, y + 0.045), Color(0.65, 0.69, 0.64, 0.12), 0.028, true)
			var x: float = left + (0.38 if row % 2 == 0 else 0.12)
			while x < right:
				var tip: float = y - spacing * 0.7
				if Geometry2D.is_point_in_polygon(Vector2(x, tip), outline):
					draw_line(Vector2(x, y), Vector2(x - 0.08, tip), Color(0.04, 0.06, 0.07, 0.6), 0.018, true)
					if posmod(roundi(x * 10) + row * 13 + definition.variation, 11) == 0:
						draw_line(Vector2(x - 0.18, y - 0.05), Vector2(x, tip + 0.15), Color("485142"), 0.045, true)
				x += 0.68
		row += 1
		y += spacing
	var border: PackedVector2Array = outline.duplicate()
	border.append(outline[0])
	draw_polyline(border, Color("10191c"), 0.22, true)
	draw_polyline(border, definition.trim_color.darkened(0.3), 0.07, true)
	if definition.ridge_metres.size() >= 2:
		draw_polyline(definition.ridge_metres, Color("161e21"), 0.34, true)
		draw_polyline(definition.ridge_metres, definition.trim_color, 0.14, true)
	draw_set_transform(Vector2.ZERO)
