@tool
class_name VFXDefinition
extends Resource
enum Style { CRYSTAL, FIRE, RADIANT, WAVE, HEAL, FLESH, METAL, WOOD, STONE }
@export var style: Style = Style.CRYSTAL
@export var color: Color = Color("70cfff")
@export var core_color: Color = Color("edfbff")
@export_range(1, 64, 1) var particle_count: int = 24
@export_range(0.1, 4.0, 0.05) var lifetime: float = 0.7
@export_range(1, 120, 1) var visual_size: float = 12.0
@export_range(0, 64, 1) var trail_points: int = 24
@export_range(0.05, 2.0, 0.05) var trail_lifetime: float = 0.3
@export_range(0, 3, 0.05) var light_energy: float = 0.7
@export_range(0, 512, 1) var light_radius: float = 110.0
@export var smoke: bool = false
