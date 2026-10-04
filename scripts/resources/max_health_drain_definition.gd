@tool
class_name MaxHealthDrainDefinition
extends Resource
@export var id: StringName = &"blackflame"
@export var vfx: VFXDefinition
## Total damage, not damage per tick. Arcane is snapshotted by the cast context.
@export var starting_arcane: int = 10
@export var arcane_cap: int = 60
@export_range(0.01, 10, 0.01) var curvature: float = 2.0
@export_range(0, 1, 0.001) var starting_fraction: float = 0.02
@export_range(0, 1, 0.001) var capped_fraction: float = 0.05
@export_range(0.01, 60, 0.01) var starting_duration: float = 0.75
@export_range(0.01, 60, 0.01) var capped_duration: float = 1.25

func progress(stats: AttributeStats) -> float:
	var arcane: int = stats.arcane if stats != null else starting_arcane
	var x: float = clampf(float(arcane - starting_arcane) / maxi(1, arcane_cap - starting_arcane), 0.0, 1.0)
	return log(1.0 + curvature * x) / log(1.0 + curvature)

func total_fraction(stats: AttributeStats) -> float:
	return lerpf(starting_fraction, capped_fraction, progress(stats))

func lifetime(stats: AttributeStats) -> float:
	return lerpf(starting_duration, capped_duration, progress(stats))

func is_valid() -> bool:
	return arcane_cap > starting_arcane and curvature > 0 and starting_duration > 0 and capped_duration >= starting_duration and starting_fraction >= 0 and capped_fraction >= starting_fraction and capped_fraction <= 1
