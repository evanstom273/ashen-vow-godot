@tool
class_name ShrineDefinition
extends Resource
@export var display_name: String = "Ashen Shrine"
@export var interaction_prompt: String = "Rest at the ashen shrine"
@export var rest_message: String = "Vow renewed"
@export_range(1, 500, 1) var interaction_radius: float = 54.0
@export var restore_health: bool = true
@export var restore_stamina: bool = true
@export var reset_enemies: bool = true
@export var reset_dummies: bool = true
@export var block_during_combat: bool = true
@export_range(0.1, 10, 0.1) var pulse_duration: float = 1.4
@export var light_color: Color = Color("a8dcd3")
@export_range(0, 5, 0.05) var light_energy: float = 0.8
