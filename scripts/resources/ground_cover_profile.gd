@tool
class_name GroundCoverProfile
extends Resource
## Family weights describe ecological mixes, not uniform individual-plant scatter.
@export var families := PackedStringArray(["grass", "fern", "moss", "litter", "branch", "stone"])
@export var weights := PackedFloat32Array([4, 2, 2, 3, 0.5, 0.5])
@export_range(0.0, 1.0, 0.05) var density: float = 0.8
@export var height_metres := Vector2(0.18, 0.48)
@export var foliage := Color("526244")
@export var dry_foliage := Color("6d6545")
@export var litter := Color("504a36")
@export var stone := Color("687060")
@export_range(0.0, 1.0, 0.05) var wind_response: float = 0.8
## Sparse interior weeds and gravel still leave generous readable bare ground.
@export_range(0.0, 1.0, 0.05) var bare_fraction: float = 0.22
## Optional tint under authored patches; alpha is its strength, never an opaque disc.
@export var soil_tint := Color(0.3,0.3,0.22,0.0)

func family_at(roll: float) -> String:
	var total: float = 0.0
	for weight: float in weights: total += maxf(0.0, weight)
	if families.is_empty() or total <= 0.0: return "grass"
	var cursor: float = clampf(roll, 0.0, 0.99999) * total
	for index in mini(families.size(), weights.size()):
		cursor -= maxf(0.0, weights[index])
		if cursor <= 0.0: return families[index]
	return families[0]
