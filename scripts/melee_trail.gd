class_name MeleeTrail
extends Node2D
## World-space geometry samples, never gameplay reach or collision.
var profile: VFXDefinition
var tips: Array[Vector2] = []
var roots: Array[Vector2] = []
var ages: Array[float] = []
var tint: Color = Color.WHITE

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	add_to_group("physical_trails")
	z_as_relative = false
	z_index = 2
	top_level = true
	global_transform = Transform2D.IDENTITY
	var mat := CanvasItemMaterial.new()
	mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	material = mat

func sample(_grip: Vector2, _tip: Vector2, _selected: VFXDefinition, _color: Color = Color.WHITE) -> void:
	# Compatibility entry point; historical weapon geometry is no longer rendered.
	clear()

func clear() -> void:
	tips.clear()
	roots.clear()
	ages.clear()
	queue_redraw()

func _process(delta: float) -> void:
	if profile == null: return
	for i in ages.size(): ages[i] += delta
	var lifetime: float = clampf(profile.ribbon_fade, 0.15, 0.25) * (0.6 if Feedback.reduced_effects else 1.0)
	while not ages.is_empty() and ages.back() >= lifetime:
		ages.pop_back()
		tips.pop_back()
		roots.pop_back()
	queue_redraw()

func _draw() -> void:
	if profile == null: return
	var lifetime: float = clampf(profile.ribbon_fade, 0.15, 0.25) * (0.6 if Feedback.reduced_effects else 1.0)
	for i in range(1, tips.size()):
		var fade: float = maxf(0, 1.0 - ages[i] / lifetime)
		var inner_a: Vector2 = roots[i - 1]
		var inner_b: Vector2 = roots[i]
		if profile.trail_shape == "Thrust":
			var normal: Vector2 = (tips[i - 1] - roots[i - 1]).normalized().orthogonal()
			inner_a = tips[i - 1] - normal * profile.ribbon_width * fade
			inner_b = tips[i] - normal * profile.ribbon_width * fade
		var color: Color = profile.color * tint
		_triangle(tips[i - 1], tips[i], inner_b, Color(color, fade * 0.23))
		_triangle(tips[i - 1], inner_b, inner_a, Color(color, fade * 0.16))
		draw_line(tips[i - 1], tips[i], Color(profile.core_color * tint, fade * 0.8), maxf(0.5, profile.ribbon_width * fade * 0.16), true)

func _triangle(a: Vector2, b: Vector2, c: Vector2, color: Color) -> void:
	if absf((b - a).cross(c - a)) > 0.01:
		draw_colored_polygon(PackedVector2Array([a, b, c]), color)
