class_name TransformationDefinition
extends Resource
## Immutable form configuration; runtime state belongs to PlayerTransformation.
@export var id: StringName
@export var display_name: String = "Form"
@export var icon: Texture2D
@export var visual_scene: PackedScene
@export_group("Movement")
@export var movement: MovementDefinition
@export var preserve_transition_movement: bool = true
@export var allow_sprint: bool = false
## World units per second; independent of the form's artwork size.
@export_range(1, 2000, 1) var sprint_speed: float = 600.0
@export var sprint_vfx: VFXDefinition
@export_range(0.05, 2, 0.01) var sprint_vfx_interval: float = 0.1
@export_range(1, 2, 0.05) var sprint_animation_multiplier: float = 1.4
@export_range(1, 2, 0.05) var sprint_camera_lead_multiplier: float = 1.15
@export_flags_2d_physics var collision_layer: int = 8
@export_flags_2d_physics var collision_mask: int = 16
@export_flags_2d_physics var landing_mask: int = 55
@export var traversal_tags: Array[StringName] = []
@export_group("Permissions")
@export var allow_melee: bool = false
@export var allow_spells: bool = false
@export var allow_interaction: bool = false
@export var allow_cycling: bool = false
@export var allow_utilities: bool = false
@export var allow_dodge: bool = false
@export_group("Presentation")
## Relative to the player; ground forms stay at zero, airborne forms clear canopies.
@export var visual_z_index: int = 0
@export var reveal_foreground: bool = true
@export_range(0.05, 1, 0.01) var transition_duration: float = 0.24
@export var transform_vfx: VFXDefinition
@export var revert_vfx: VFXDefinition
@export var movement_vfx: VFXDefinition
@export_range(0.05, 2, 0.01) var movement_vfx_interval: float = 0.18
## Actor-local artwork units; the player's transform supplies world scale.
@export var shadow_size: Vector2 = Vector2(19, 8)
@export var shadow_opacity: float = 0.22
@export var visual_offset: Vector2 = Vector2(0, -24)
@export var camera_lead: float = 0.06
## Multiplier of the normal camera zoom. Below 1 widens the view.
@export_range(0.25, 1.2, 0.01) var camera_zoom: float = 0.94
## When enabled, zoom and wheel limits are absolute Camera2D zoom values.
@export var camera_zoom_absolute: bool = false
@export var wheel_zoom_enabled: bool = false
@export_range(0.1, 2.0, 0.05) var camera_blend_duration: float = 0.7
@export_range(0.1, 1.2, 0.01) var camera_zoom_min: float = 0.25
@export_range(0.1, 1.2, 0.01) var camera_zoom_max: float = 0.5
@export_range(0.01, 0.25, 0.01) var camera_zoom_step: float = 0.05
