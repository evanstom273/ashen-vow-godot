@tool
class_name DamageProfile
extends Resource
## Attack power by damage channel. Health damage is rounded once after mitigation.
@export_range(0, 100000, 0.1) var physical: float = 110.0
@export_range(0, 100000, 0.1) var magic: float = 0.0
@export_range(0, 100000, 0.1) var fire: float = 0.0
@export_range(0, 100000, 0.1) var lightning: float = 0.0
@export_range(0, 100000, 0.1) var holy: float = 0.0

func total() -> float:
    return physical + magic + fire + lightning + holy

func mitigated(defence: DefenceProfile) -> float:
    if defence == null: return total()
    return physical*(1-defence.physical/100.0) + magic*(1-defence.magic/100.0) + fire*(1-defence.fire/100.0) + lightning*(1-defence.lightning/100.0) + holy*(1-defence.holy/100.0)
