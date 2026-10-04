@tool
class_name ElevationMember
extends Node
## Elevation for standalone props, actors or interactions outside a BuildingFloor.
## Floor descendants inherit their floor; standalone nodes can use this component.
@export var definition: ElevationDefinition
@export var target_path: NodePath = NodePath("..")

func _enter_tree() -> void:
	var target: Node = get_node_or_null(target_path)
	if target != null and definition != null:
		target.set_meta(&"elevation_definition", definition)

func _ready() -> void:
	if not Engine.is_editor_hint(): call_deferred("_register")

func _register() -> void:
	var target: Node = get_node_or_null(target_path)
	if not is_instance_valid(target) or not target.is_inside_tree(): return
	Elevation.register_tree(target)
	if target is Node2D: Elevation.register_visual(target)

