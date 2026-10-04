@tool
class_name DashDelivery
extends SpellDeliveryDefinition
@export var distance: float = 720.0
@export var steering: float = 0.0
@export var hit_width: float = 96.0
@export var invulnerable: bool = false
@export var invulnerability_start: float = 0.0
@export var invulnerability_end: float = 1.0

func _init() -> void:
	duration = 0.35

func kind() -> StringName:
	return &"dash"
