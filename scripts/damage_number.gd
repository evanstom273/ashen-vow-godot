class_name DamageNumber
extends Node2D
## One rolling total per receiver, independent of particle budgets.
var receiver_ref: WeakRef
var total: int = 0
var age: float = 0.0
var label: Label
var height_offset: float = 232.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	z_as_relative = false
	z_index = 100
	add_to_group("damage_numbers")
	label = Label.new()
	var unshaded := CanvasItemMaterial.new()
	unshaded.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	label.material = unshaded
	label.position = Vector2(-50, -58)
	label.size = Vector2(100, 24)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", Color("f4dc9b"))
	label.add_theme_color_override("font_outline_color", Color("16131a"))
	label.add_theme_constant_override("outline_size", 4)
	add_child(label)

func add_damage(amount: int, receiver: Node2D) -> void:
	if age >= 0.8: total = 0
	total += amount
	age = 0.0
	modulate.a = 1.0
	receiver_ref = weakref(receiver)
	height_offset = 58.0 * WorldScale.actor_scale(receiver)
	global_position = receiver.global_position
	label.text = str(total)
	label.add_theme_color_override("font_color", Color("eea59d") if receiver.is_in_group("player") else Color("f4dc9b"))

func _process(delta: float) -> void:
	age += delta
	var receiver: Variant = receiver_ref.get_ref() if receiver_ref != null else null
	if is_instance_valid(receiver) and receiver is Node2D:
		global_position = receiver.global_position
	# Text remains a readable screen size; its anchor follows the scaled body.
	var camera: Camera2D = get_viewport().get_camera_2d()
	var screen_zoom: float = maxf(0.01, camera.zoom.x) if camera != null else 1.0
	global_scale = Vector2.ONE / screen_zoom
	label.position.y = -height_offset * screen_zoom - minf(age, 0.4) * 10.0
	modulate.a = clampf((1.3 - age) / 0.5, 0.0, 1.0)
	if age >= 1.3: queue_free()
