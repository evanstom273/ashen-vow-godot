@tool
extends StaticBody2D
var elapsed: float = 0.0
var flame_light: PointLight2D

func _ready() -> void:
	if Engine.is_editor_hint(): return
	Feedback.physical_effect(to_global(Vector2(0, -13)), preload("res://data/vfx/brazier_flame.tres"), &"flame", Vector2.UP, 1, self, true)
	Feedback.physical_effect(to_global(Vector2(0, -19)), preload("res://data/vfx/brazier_embers.tres"), &"embers", Vector2.UP, 1, self, true)
	Feedback.physical_effect(to_global(Vector2(0, -25)), preload("res://data/vfx/brazier_smoke.tres"), &"smoke", Vector2.UP, 1, self, true)
	flame_light = PointLight2D.new()
	flame_light.texture = Feedback.light_texture
	flame_light.color = Color("ffbb6e")
	flame_light.texture_scale = 3.8
	flame_light.energy = 0.85
	add_child(flame_light)
	var sound := AudioStreamPlayer2D.new()
	sound.stream = Feedback.sounds.get("fire")
	sound.bus = "Ambience"
	sound.volume_db = -22
	sound.max_distance = 350 * global_scale.x
	add_child(sound)
	if DisplayServer.get_name() != "headless": sound.play()

func _process(delta: float) -> void:
	if Engine.is_editor_hint(): return
	elapsed += delta
	if is_instance_valid(flame_light): flame_light.energy = 0.85 + sin(elapsed * 2.1) * 0.045

func _draw() -> void:
	draw_set_transform(Vector2.ZERO, 0, Vector2(1, 0.55))
	draw_circle(Vector2.ZERO, 31, Color("242923"))
	for i in 10:
		var at: Vector2 = Vector2.RIGHT.rotated(i * TAU / 10.0) * 25
		draw_colored_polygon(PackedVector2Array([at + Vector2(-8, -4), at + Vector2(-4, -8), at + Vector2(7, -5), at + Vector2(9, 3), at + Vector2(-5, 5)]), Color("747468") if i < 5 else Color("4c5148"))
	draw_set_transform(Vector2.ZERO)
	draw_line(Vector2(-17, 6), Vector2(14, -9), Color("493528"), 9)
	draw_line(Vector2(-14, -8), Vector2(16, 8), Color("67452c"), 8)
	draw_line(Vector2(-10, 0), Vector2(11, 2), Color("d78437"), 3)
	if Engine.is_editor_hint():
		draw_colored_polygon(PackedVector2Array([Vector2(-12, 0), Vector2(-7, -19), Vector2(0, -12), Vector2(5, -32), Vector2(11, -9), Vector2(8, 3)]), Color("efac55"))
