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
	draw_texture_rect(preload("res://assets/illustrated/campfire.svg"), Rect2(-36, -24, 72, 48), false)
	if Engine.is_editor_hint():
		draw_colored_polygon(PackedVector2Array([Vector2(-12, 0), Vector2(-7, -19), Vector2(0, -12), Vector2(5, -32), Vector2(11, -9), Vector2(8, 3)]), Color("efac55"))
