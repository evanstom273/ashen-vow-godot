@tool
class_name MovementDefinition
extends Resource
## Locomotion is in world units (128 = 1 metre), never scaled with actor artwork.
@export_group("Locomotion")
@export_range(1, 2000, 1) var walk_speed: float = 512.0
@export_range(1, 5, 0.01) var sprint_multiplier: float = 1.5
## World units per second squared. Braking also handles sharp reversals.
@export_range(1, 10000, 10) var acceleration: float = 2100.0
@export_range(1, 10000, 10) var deceleration: float = 3800.0
@export_range(0, 1000, 0.1) var sprint_stamina_per_second: float = 18.0
@export_range(0.01, 1, 0.01) var sprint_hold_threshold: float = 0.20
@export_group("Combat stamina")
## Stamina is free outside combat. Retain combat briefly after aggression/damage ends.
@export_range(0, 15, 0.1) var combat_exit_delay: float = 3.0
@export_group("Dodge")
@export_range(0.05, 5, 0.01) var dodge_duration: float = 0.45
@export_range(1, 1000, 1) var dodge_distance: float = 350.0
@export_range(0, 10, 0.01) var dodge_cooldown: float = 0.55
@export_range(0, 1000, 0.1) var dodge_cost: float = 24.0
## Fraction of the roll, so invulnerability follows edited duration.
@export_range(0, 1, 0.001) var invulnerability_start: float = 0.133333
@export_range(0, 1, 0.001) var invulnerability_end: float = 0.755556
@export_group("Controls")
@export_range(0, 1, 0.01) var input_buffer: float = 0.12
## Acquisition range in world units (128 units = 1 metre in the overworld).
## Moving beyond this range does not cancel an existing lock.
@export_range(1, 8000, 1) var lock_on_radius: float = 1536.0
## World units. Shared 1.5 m reach replaces scene-local camp overrides.
@export_range(1, 2000, 1) var interaction_radius: float = 192.0
