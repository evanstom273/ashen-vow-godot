extends Node2D
var definition: TransformationDefinition
var elapsed: float = 0.0
var heading: float = 0.0
var sprint_blend: float = 0.0
var flap_phase: float = 0.0

func setup(value: TransformationDefinition) -> void:
	definition = value

func _process(delta: float) -> void:
	elapsed += delta
	var body := get_parent() as CharacterBody2D
	if definition != null:
		var target: float = clampf((body.velocity.length() - definition.movement.walk_speed) / maxf(1.0, definition.sprint_speed - definition.movement.walk_speed), 0.0, 1.0)
		sprint_blend = lerpf(sprint_blend, target, 1.0 - exp(-delta * 8.0))
		flap_phase += delta * 9.0 * lerpf(1.0, definition.sprint_animation_multiplier, sprint_blend)
	if body.velocity.length() > 5:
		heading = lerp_angle(heading, body.velocity.angle() + PI * 0.5, 1.0 - exp(-delta * 10))
	queue_redraw()

func _draw() -> void:
	if definition == null: return
	# Layered translucent ellipses give a soft ground contact without true altitude.
	for layer in range(5, 0, -1):
		var points := PackedVector2Array()
		for i in 24:
			var angle: float = i * TAU / 24.0
			points.append(Vector2(cos(angle), sin(angle)) * definition.shadow_size * (0.65 + layer * 0.1))
		draw_colored_polygon(points, Color(0.015, 0.02, 0.03, definition.shadow_opacity / 5.0))
	var flap: float = sin(flap_phase) * lerpf(1.0, 1.22, sprint_blend)
	draw_set_transform(definition.visual_offset + Vector2(0, flap * 1.8), heading)
	for side in [-1, 1]:
		var wing := PackedVector2Array()
		for point: Vector2 in [Vector2(4, -9), Vector2(16, -17), Vector2(35, -12), Vector2(49, 1), Vector2(37, -1), Vector2(44, 9), Vector2(31, 4), Vector2(34, 15), Vector2(21, 8), Vector2(18, 18), Vector2(7, 11)]:
			wing.append(Vector2(point.x * side * (0.72 + flap * 0.24), point.y + absf(point.x) * flap * 0.13))
		draw_colored_polygon(wing, Color("131723"))
		draw_line(Vector2(side * 7, -6), Vector2(side * (26 + flap * 7), -9 + flap * 5), Color("414657"), 2.0)
	draw_colored_polygon(PackedVector2Array([Vector2(-5, 7), Vector2(-10, 27), Vector2(0, 23), Vector2(10, 27), Vector2(5, 7)]), Color("171925"))
	draw_colored_polygon(PackedVector2Array([Vector2(0, -18), Vector2(-7, -8), Vector2(-6, 10), Vector2(0, 17), Vector2(6, 10), Vector2(7, -8)]), Color("242938"))
	draw_colored_polygon(PackedVector2Array([Vector2(0, -26), Vector2(-5, -17), Vector2(-4, -10), Vector2(5, -12), Vector2(5, -18)]), Color("10131c"))
	draw_colored_polygon(PackedVector2Array([Vector2(-2, -23), Vector2(0, -33), Vector2(4, -23)]), Color("72757c"))
	draw_line(Vector2(-2, -17), Vector2(-1, -18), Color("c4b59b"), 1.2)
	draw_set_transform(Vector2.ZERO)
