extends Node2D
var radius: float = 80.0
var tint: Color = Color("9fc8ff")
var elapsed: float = 0.0

func _ready() -> void:
    z_index = 35
    z_as_relative = false

func _process(delta: float) -> void:
    elapsed += delta
    if elapsed >= 0.55:
        queue_free()
        return
    queue_redraw()

func _draw() -> void:
    var progress: float = clampf(elapsed / 0.55, 0, 1)
    var reach: float = radius * (0.2 + 0.8 * progress)
    draw_circle(Vector2.ZERO, reach, Color(tint, (1.0 - progress) * 0.2))
    draw_arc(Vector2.ZERO, reach, 0, TAU, 64, Color(tint, 1.0 - progress), 3.0, true)
