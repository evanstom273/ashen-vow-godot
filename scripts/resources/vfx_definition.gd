@tool
class_name VFXDefinition
extends Resource
## Local polygon/profile units to world units. Gameplay delivery geometry is
## already in world units and must not receive this multiplier again.
@export_range(0.01, 16, 0.01) var art_scale: float = 4.0
@export_group("Screen and impact feedback")
@export var release_feedback: CombatFeedbackDefinition
@export var impact_feedback: CombatFeedbackDefinition
@export var completion_feedback: CombatFeedbackDefinition
## Optional cosmetic-only Node2D scenes. Never attach damage or collision logic.
@export_group("Visual Scenes")
@export var cast_scene: PackedScene
## Attached to the delivery; may implement update_delivery(delivery) for geometry.
@export var delivery_scene: PackedScene
@export var impact_scene: PackedScene
@export_group("Palette, Particles and Lighting")
enum Style { CRYSTAL, FIRE, RADIANT, WAVE, HEAL, FLESH, METAL, WOOD, STONE, DARK_FLAME }
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
@export_group("Spell Spectacle")
## Enables the reusable spell presentation; combat/blood profiles stay unchanged.
@export var spell_visuals: bool = false
@export var particle_material: ParticleProcessMaterial
@export var particle_texture: Texture2D
@export_range(0, 256, 1) var emission_amount: int = 48
@export_range(0.05, 3, 0.05) var particle_lifetime: float = 0.65
@export_range(0, 500, 1) var emission_speed: float = 80.0
@export_range(0, 180, 1) var emission_spread: float = 180.0
@export_range(0.1, 12, 0.1) var particle_scale: float = 2.0
@export_range(0.1, 64, 0.1) var ribbon_width: float = 12.0
@export_range(0.05, 2, 0.05) var ribbon_fade: float = 0.45
@export_range(0, 4, 0.05) var glow_strength: float = 1.0
@export var accent_color: Color = Color("b397ff")
@export_group("Physical Effects")
@export_enum("Arc", "Thrust", "Smear") var trail_shape: String = "Arc"
@export_range(0, 1, 0.05) var trail_inner_fraction: float = 0.55
@export_range(0, 1, 0.05) var release_dust: float = 0.0
@export_range(0, 500, 1) var gravity: float = 180.0
@export_range(0.1, 20, 0.1) var fragment_size: float = 3.0
@export var additive: bool = false
