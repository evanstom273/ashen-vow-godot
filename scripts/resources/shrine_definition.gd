@tool
class_name ShrineDefinition
extends Resource
@export var display_name: String = "Ashen Shrine"
@export var interaction_prompt: String = "Rest at the ashen shrine"
@export var rest_message: String = "Vow renewed"
@export var idle_vfx: VFXDefinition = preload("res://data/vfx/shrine_idle.tres")
@export var rest_vfx: VFXDefinition = preload("res://data/vfx/shrine_rest.tres")
## World units; independent of the shrine's local polygon-art scale.
@export_range(1, 2000, 1) var interaction_radius: float = 192.0
@export var restore_health: bool = true
@export var restore_stamina: bool = true
@export var reset_enemies: bool = true
@export var reset_dummies: bool = true
@export var block_during_combat: bool = true
@export_range(0.1, 10, 0.1) var pulse_duration: float = 1.4
@export var light_color: Color = Color("a8dcd3")
@export_range(0, 5, 0.05) var light_energy: float = 0.8
