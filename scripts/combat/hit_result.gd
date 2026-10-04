class_name HitResult
extends RefCounted
## An authoritative receiver decision, not a health comparison made by a caller.
var accepted: bool = false
var reason: StringName = &"invalid_target"
var damage: int = 0
var staggered: bool = false
var killed: bool = false
var applied_effects: Array[StringName] = []

static func reject(why: StringName) -> HitResult:
	var result := HitResult.new()
	result.reason = why
	return result

static func accept(amount: int = 0) -> HitResult:
	var result := HitResult.new()
	result.accepted = true
	result.reason = &"accepted"
	result.damage = maxi(0, amount)
	return result
