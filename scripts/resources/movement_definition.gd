@tool
class_name MovementDefinition
extends Resource
@export_group("Locomotion")
@export_range(1, 2000, 1) var walk_speed: float = 220.0
@export_range(1, 5, 0.01) var sprint_multiplier: float = 1.65
@export_range(0, 1000, 0.1) var sprint_stamina_per_second: float = 18.0
@export_range(0.01, 1, 0.01) var sprint_hold_threshold: float = 0.20
@export_group("Dodge")
@export_range(0.05, 5, 0.01) var dodge_duration: float = 0.45
@export_range(1, 1000, 1) var dodge_distance: float = 145.0
@export_range(0, 10, 0.01) var dodge_cooldown: float = 0.55
@export_range(0, 1000, 0.1) var dodge_cost: float = 24.0
## Fraction of the roll, so invulnerability follows edited duration.
@export_range(0, 1, 0.001) var invulnerability_start: float = 0.133333
@export_range(0, 1, 0.001) var invulnerability_end: float = 0.755556
@export_group("Controls")
@export_range(0, 1, 0.01) var input_buffer: float = 0.12
@export_range(1, 2000, 1) var lock_on_radius: float = 220.0
@export_range(1, 500, 1) var interaction_radius: float = 54.0
