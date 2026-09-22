@tool
class_name AttributeStats
extends Resource
## Primary attributes. Runtime actors copy these; the asset is never levelled in place.
@export_range(0, 99, 1) var vigour: int = 10
@export_range(0, 99, 1) var endurance: int = 10
@export_range(0, 99, 1) var strength: int = 10
@export_range(0, 99, 1) var dexterity: int = 10
@export_range(0, 99, 1) var intelligence: int = 10
@export_range(0, 99, 1) var faith: int = 10
@export_range(0, 99, 1) var arcane: int = 10

func meets(requirements: AttributeStats) -> bool:
    if requirements == null: return true
    return vigour >= requirements.vigour and endurance >= requirements.endurance and strength >= requirements.strength and dexterity >= requirements.dexterity and intelligence >= requirements.intelligence and faith >= requirements.faith and arcane >= requirements.arcane
