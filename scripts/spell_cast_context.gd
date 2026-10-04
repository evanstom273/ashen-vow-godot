class_name SpellCastContext
extends RefCounted
var caster: Node2D
var attribution: Node2D
var target: Node2D
var direction := Vector2.RIGHT
var point := Vector2.ZERO
var origin := Vector2.ZERO
var hand: StringName = &"right"
var faction: StringName = &"ally"
var attributes: AttributeStats
var attack: AttackDefinition
var profile: VFXDefinition
var ownership: StringName
var weapon_token: int = 0
var depth: int = 0
var from_summon: bool = false
var elevation: int = 0
var cross_elevations: bool = false

func branch() -> SpellCastContext:
	var result := SpellCastContext.new()
	for key: String in ["caster", "attribution", "target", "direction", "point", "origin", "hand", "faction", "attributes", "attack", "profile", "ownership", "weapon_token", "from_summon", "elevation", "cross_elevations"]:
		result.set(key, get(key))
	result.depth = depth + 1
	return result
