@tool
extends Node2D
## Drag-and-drop decorative patch. A single wind-animated mesh; never a collider.
@export var profile: GroundCoverProfile:
	set(value):
		if profile != null and profile.changed.is_connected(_rebuild): profile.changed.disconnect(_rebuild)
		profile = value
		if profile != null: profile.changed.connect(_rebuild)
		_rebuild()
@export var radius_metres := Vector2(1.5,1.0):
	set(value):
		radius_metres = value.max(Vector2.ONE*0.1)
		_rebuild()
@export_range(1,128,1) var item_count: int = 36:
	set(value):
		item_count = value
		_rebuild()
@export var seed_value: int = 319:
	set(value):
		seed_value = value
		_rebuild()
var art: MeshInstance2D

func _ready() -> void:
	_rebuild()

func _rebuild() -> void:
	if not is_inside_tree() or profile == null: return
	if not is_instance_valid(art):
		art = MeshInstance2D.new()
		art.name = "BatchedCover"
		art.z_index = -9
		art.material = preload("res://data/environment/ground_cover_material.tres")
		add_child(art)
	art.mesh = GroundCoverBuilder.new().build_patch(profile,radius_metres,item_count,seed_value)
