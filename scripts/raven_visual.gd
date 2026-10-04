extends Node2D
const WING: Texture2D = preload("res://assets/illustrated/raven_wing.svg")
const BODY: Texture2D = preload("res://assets/illustrated/raven_body.svg")
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
		draw_set_transform(definition.visual_offset + Vector2(0, flap * 1.8), heading, Vector2(side * (0.72 + flap * 0.24), 1.0))
		draw_texture_rect(WING, Rect2(0, -19, 52, 39), false)
	draw_set_transform(definition.visual_offset + Vector2(0, flap * 1.8), heading)
	draw_texture_rect(BODY, Rect2(-10, -34, 20, 62), false)
	draw_set_transform(Vector2.ZERO)
