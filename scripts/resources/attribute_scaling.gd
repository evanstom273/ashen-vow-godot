@tool
class_name AttributeScaling
extends Resource
## Fractional damage bonus per attribute point ABOVE the reference level.
@export_range(0, 99, 1) var reference_level: int = 10
@export_range(0, 1, 0.001) var strength: float = 0.0
@export_range(0, 1, 0.001) var dexterity: float = 0.0
@export_range(0, 1, 0.001) var intelligence: float = 0.0
@export_range(0, 1, 0.001) var faith: float = 0.0
@export_range(0, 1, 0.001) var arcane: float = 0.0

func multiplier(stats: AttributeStats) -> float:
    if stats == null: return 1.0
    return 1.0 + maxf(0, stats.strength-reference_level)*strength + maxf(0, stats.dexterity-reference_level)*dexterity + maxf(0, stats.intelligence-reference_level)*intelligence + maxf(0, stats.faith-reference_level)*faith + maxf(0, stats.arcane-reference_level)*arcane
