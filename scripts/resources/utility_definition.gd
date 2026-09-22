@tool
class_name UtilityDefinition
extends Resource

@export var id: StringName = &"utility"
@export var display_name: String = "Utility"
@export_multiline var description: String = ""
@export var icon: Texture2D
@export_range(0, 99, 1) var charges: int = 1
@export_range(1, 99, 1) var maximum_charges: int = 1
@export_range(0, 100000, 1) var health_restore: int = 0
@export_range(0, 100000, 0.1) var stamina_restore: float = 0.0
@export_range(0, 10, 0.01) var use_time: float = 0.0
@export_range(0, 10, 0.01) var recovery_time: float = 0.0
@export var vfx: PackedScene
@export var sound_key: StringName = &"item"

func starting_charges() -> int:
    return clampi(charges, 0, maximum_charges)
