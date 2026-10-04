extends Node2D
## Navigation-only light column: no collision, gameplay light or particle allocation.
@export var beam_height: float = 680.0
@export var ground_radius: float = 90.0
@export var tint := Color("b5e5d8")
var elapsed: float = 0.0
var marker_number: int = 1

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	z_as_relative = false
	z_index = 8
	var unshaded := CanvasItemMaterial.new()
	unshaded.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	material = unshaded

func _process(delta: float) -> void:
	elapsed += delta
	queue_redraw()

func _draw() -> void:
	var pulse: float = 1.0 if Feedback.reduced_effects else 0.92 + sin(elapsed * 1.7) * 0.08
	# Transparent outer column, narrow luminous core; readable without washing out terrain.
	for i in range(4, 0, -1):
		var half_width: float = float(i) * 14.0
		var points := PackedVector2Array([Vector2(-half_width, 0), Vector2(-half_width * 0.22, -beam_height), Vector2(half_width * 0.22, -beam_height), Vector2(half_width, 0)])
		var colors := PackedColorArray([Color(tint, 0.045 * pulse), Color(tint, 0), Color(tint, 0), Color(tint, 0.045 * pulse)])
		draw_polygon(points, colors)
	draw_line(Vector2.ZERO, Vector2(0, -beam_height * 0.8), Color(tint, 0.42 * pulse), 3, true)
	draw_set_transform(Vector2.ZERO, 0, Vector2(1, 0.48))
	draw_arc(Vector2.ZERO, ground_radius, 0, TAU, 64, Color(tint, 0.65), 3, true)
	draw_arc(Vector2.ZERO, ground_radius * 0.75, 0, TAU, 48, Color(tint, 0.23), 2, true)
	for i in 8:
		var direction := Vector2.from_angle(TAU * float(i) / 8.0)
		draw_line(direction * ground_radius * 0.84, direction * ground_radius, Color(tint, 0.6), 3, true)
	draw_set_transform(Vector2.ZERO)
	if not Feedback.reduced_effects:
		for i in 10:
			var travel: float = fposmod(elapsed * 0.2 + float(i) / 10.0, 1.0)
			var at := Vector2(sin(float(i) * 2.4 + elapsed) * 32, -travel * beam_height)
			draw_circle(at, 3, Color(tint, sin(travel * PI) * 0.6))
	var crest := Vector2(0, -beam_height * 0.62)
	draw_circle(crest, 27, Color("10231f"))
	draw_arc(crest, 27, 0, TAU, 32, Color(tint, 0.85), 2, true)
	var label: String = str(marker_number)
	var label_width: float = ThemeDB.fallback_font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 28).x
	draw_string(ThemeDB.fallback_font, crest + Vector2(-label_width * 0.5, 10), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 28, tint)
