class_name ForegroundReveal
extends Node
## Add as a child of a foreground Node2D. Applies only to that drawing item.
## Children with their own artwork must use use_parent_material or their own component.
@export var target_path: NodePath = NodePath("..")
@export var enabled: bool = true
@export_range(1, 800, 1) var radius: float = 190.0
@export_range(0.1, 400, 0.5) var edge_softness: float = 64.0
@export_range(0, 1, 0.01) var minimum_opacity: float = 0.08
@export_range(0, 0.5, 0.01) var transition_time: float = 0.18
@export var player_offset := Vector2(0, -18)
## Local-space artwork bounds; used only to avoid revealing unrelated objects.
@export var visual_bounds := Rect2(-90, -165, 185, 190)
## Disable for artwork deliberately placed on a higher foreground Z layer.
@export var use_y_sort_test: bool = true
var target: Node2D
var player: Node2D
var reveal_material: ShaderMaterial
var previous_material: Material
var amount: float = 0.0

func _ready() -> void:
	target = get_node_or_null(target_path) as Node2D
	if target == null:
		push_warning("ForegroundReveal requires a Node2D target")
		set_process(false)
		return
	# The integrated canopy shader already has wind; preserve its parameters.
	previous_material = target.material
	var compatible: bool = target.material is ShaderMaterial and (target.material as ShaderMaterial).shader == preload("res://shaders/foreground_reveal.gdshader")
	if target.material != null and not compatible:
		push_warning("ForegroundReveal: target already has a material; integrate the reveal shader explicitly")
		set_process(false)
		return
	reveal_material = target.material.duplicate() as ShaderMaterial if compatible else ShaderMaterial.new()
	reveal_material.shader = preload("res://shaders/foreground_reveal.gdshader")
	target.material = reveal_material
	_update(0.0)

func _process(delta: float) -> void:
	_update(delta)

func _update(delta: float) -> void:
	if not is_instance_valid(target) or reveal_material == null: return
	if not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player") as Node2D
	var obscured: bool = false
	var needs_reveal: bool = true
	if is_instance_valid(player) and player is PlayerController:
		var form_runtime: PlayerTransformation = (player as PlayerController).transformation
		if is_instance_valid(form_runtime) and form_runtime.definition != null:
			needs_reveal = form_runtime.definition.reveal_foreground
	if enabled and needs_reveal and is_instance_valid(player) and player.is_inside_tree() and Elevation.compatible(target, player):
		var center: Vector2 = player.to_global(player_offset)
		reveal_material.set_shader_parameter("reveal_center", center)
		var foreground: bool = not use_y_sort_test or target.global_position.y > player.global_position.y
		# Convert world radius conservatively for locally scaled foreground objects.
		var scale_factor: float = maxf(0.001, minf(absf(target.global_scale.x), absf(target.global_scale.y)))
		obscured = foreground and visual_bounds.grow(radius / scale_factor).has_point(target.to_local(center))
	var desired: float = 1.0 if obscured else 0.0
	amount = move_toward(amount, desired, delta / transition_time) if transition_time > 0 else desired
	reveal_material.set_shader_parameter("reveal_radius", radius)
	reveal_material.set_shader_parameter("edge_softness", minf(edge_softness, radius))
	reveal_material.set_shader_parameter("minimum_opacity", minimum_opacity)
	# Ease both ends of the fade, retaining continuity when movement reverses it.
	reveal_material.set_shader_parameter("reveal_amount", smoothstep(0.0, 1.0, amount))

func _exit_tree() -> void:
	if is_instance_valid(target) and target.material == reveal_material:
		target.material = previous_material
