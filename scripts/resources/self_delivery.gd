@tool
class_name SelfDelivery
extends SpellDeliveryDefinition

func _init() -> void:
	target_filter = "Caster"

func kind() -> StringName:
	return &"self"
