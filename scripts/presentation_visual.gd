class_name PresentationVisual
extends Node2D
## Shared cosmetic contract for SVG, polygon, particle and shader scenes.
## Snapshots carry resolved world geometry; this class never performs gameplay.
func setup(_profile: VFXDefinition, _snapshot: Dictionary) -> void:
	pass

func update_visual(_snapshot: Dictionary) -> void:
	pass

func stop() -> void:
	queue_free()

func safe_tail_parent() -> Node:
	if not is_inside_tree() or is_queued_for_deletion(): return null
	var scene: Node = get_tree().current_scene
	if not is_instance_valid(scene) or not scene.is_inside_tree() or scene.is_queued_for_deletion(): return null
	return scene
