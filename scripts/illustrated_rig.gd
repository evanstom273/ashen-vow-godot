@tool
class_name IllustratedRig
extends Node2D
## Six independently animated parts, eight authored views in a project SVG atlas.
const PARTS: Array[String] = ["Body", "Head", "LeftArm", "RightArm", "LeftLeg", "RightLeg"]
@export var atlas: Texture2D = preload("res://assets/illustrated/wanderer_rig.svg"):
	set(value):
		atlas = value
		if is_inside_tree(): _build()
@export_range(0, 7, 1) var preview_facing: int = 2:
	set(value):
		preview_facing = value
		if Engine.is_editor_hint() and is_inside_tree(): face(Vector2.RIGHT.rotated(value * PI / 4.0))
var facing_index: int = -1
var parts: Array[Sprite2D] = []

func _ready() -> void:
	_build()

func _build() -> void:
	parts.clear()
	for index in PARTS.size():
		var joint := get_node_or_null(PARTS[index]) as Node2D
		if joint == null:
			joint = Node2D.new()
			joint.name = PARTS[index]
			add_child(joint)
			joint.position = [Vector2.ZERO, Vector2(0,-25), Vector2(-13,-9), Vector2(13,-9), Vector2(-6,8), Vector2(6,8)][index]
		for child: Node in joint.get_children():
			if child is Polygon2D: child.visible = false
		var sprite := joint.get_node_or_null("Illustration") as Sprite2D
		if sprite == null:
			sprite = Sprite2D.new()
			sprite.name = "Illustration"
			joint.add_child(sprite)
			sprite.material = ShaderMaterial.new()
			(sprite.material as ShaderMaterial).shader = preload("res://shaders/actor_surface.gdshader")
		sprite.texture = atlas
		sprite.region_enabled = true
		parts.append(sprite)
	facing_index = -1
	face(Vector2.RIGHT.rotated(preview_facing * PI / 4.0))

func face(direction: Vector2) -> void:
	if direction.length_squared() < 0.01 or parts.size() != 6: return
	var next: int = posmod(roundi(direction.angle() / (PI / 4.0)), 8)
	if next == facing_index: return
	facing_index = next
	for index in parts.size(): parts[index].region_rect = Rect2(next * 64, index * 64, 64, 64)
	var back: bool = next in [5, 6, 7]
	var order: Array[String] = []
	if back: order.assign(["LeftLeg", "RightLeg", "LeftArm", "RightArm", "Body", "Head"])
	else: order.assign(["LeftLeg", "RightLeg", "Body", "Head", "LeftArm", "RightArm"])
	if next in [0, 1]: order.assign(["LeftLeg", "RightLeg", "LeftArm", "Body", "Head", "RightArm"])
	elif next in [3, 4]: order.assign(["RightLeg", "LeftLeg", "RightArm", "Body", "Head", "LeftArm"])
	for part: String in order: move_child(get_node(part), -1)
	var narrow: float = 0.65 if next in [0,4] else 0.9 if next in [1,3,5,7] else 1.0
	get_node("LeftArm").position.x = -13.0 * narrow
	get_node("RightArm").position.x = 13.0 * narrow

func flash(amount: float) -> void:
	for sprite: Sprite2D in parts:
		if sprite.material is ShaderMaterial: sprite.material.set_shader_parameter("flash", amount)

func animate_stride(phase: float, moving: float, aiming: Vector2) -> void:
	face(aiming)
	get_node("LeftLeg").rotation = sin(phase) * moving * 0.4
	get_node("RightLeg").rotation = -sin(phase) * moving * 0.4
	get_node("LeftArm").rotation = -sin(phase) * moving * 0.2
	get_node("RightArm").rotation = sin(phase) * moving * 0.2
