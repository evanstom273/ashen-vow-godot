class_name HitRequest
extends RefCounted
## Ephemeral per-contact data. Never stored in a Resource or a save file.
var target: Node2D
var source: Node
var attack: AttackDefinition
var attributes: AttributeStats
var check_obstruction: bool = false
var origin: Vector2

func resolve() -> HitResult:
	if attack == null: return HitResult.reject(&"missing_attack")
	var rejected: StringName = rejection(target, attack, source)
	if not rejected.is_empty(): return HitResult.reject(rejected)
	if check_obstruction and is_instance_valid(source):
		var query := PhysicsRayQueryParameters2D.create(origin, target.global_position, 1)
		var excluded: Array[RID] = []
		if source is CollisionObject2D: excluded.append(source.get_rid())
		if target is CollisionObject2D: excluded.append(target.get_rid())
		query.exclude = excluded
		var obstruction: Dictionary = Elevation.ray(target, query, Elevation.level(source), attack.cross_elevations)
		if not obstruction.is_empty(): return HitResult.reject(&"obstruction")
	var outcome: Variant = target.call("receive_hit", attack, attributes, source)
	var effect_only: bool = outcome is HitResult and outcome.reason in [&"no_damage", &"no_effect"] and not attack.statuses.is_empty()
	if outcome is HitResult and (outcome.accepted or effect_only) and is_instance_valid(target) and SpellDeliveryService.alive(target):
		for application: StatusApplication in attack.statuses:
			if ActorStatuses.of(target).add(application, source, attributes):
				outcome.accepted = true
				outcome.reason = &"accepted"
				outcome.applied_effects.append(application.status.id)
		outcome.killed = not SpellDeliveryService.alive(target)
	if OS.is_debug_build() and bool(ProjectSettings.get_setting("debug/combat/trace_hits", false)):
		var defence: DefenceProfile
		var vitals: Variant = target.get("vitals")
		if vitals is VitalStats: defence = SpellEffects.defence(target, vitals.defence)
		elif target is SpellSummon: defence = SpellEffects.defence(target, target.definition.defence)
		print("[Combat] ", attack.explain_damage(attributes, defence), " receiver=", target.name,
			" accepted=", outcome.accepted if outcome is HitResult else false,
			" reason=", outcome.reason if outcome is HitResult else &"legacy_receiver")
	if outcome is HitResult: return outcome
	return HitResult.reject(&"legacy_receiver_without_result")

## Effect-only hostile contacts share receiver eligibility, but cause no fake hit.
static func rejection(receiver: Node2D, payload: AttackDefinition, instigator: Node) -> StringName:
	if not is_instance_valid(receiver) or not receiver.is_inside_tree() or receiver.is_queued_for_deletion(): return &"invalid_target"
	if not receiver.has_method("receive_hit") or not receiver.has_method("hit_rejection"): return &"unsupported_receiver"
	if not Elevation.accepts_hit(receiver, instigator, payload): return &"elevation"
	return StringName(receiver.call("hit_rejection", instigator, payload))

static func deliver(receiver: Node2D, payload: AttackDefinition, stats: AttributeStats, instigator: Node, obstruction: bool = false) -> HitResult:
	if not is_instance_valid(receiver): return HitResult.reject(&"invalid_target")
	var request := HitRequest.new()
	request.target = receiver
	request.source = instigator
	request.attack = payload
	request.attributes = stats
	request.check_obstruction = obstruction
	request.origin = instigator.global_position if is_instance_valid(instigator) and instigator is Node2D else receiver.global_position
	return request.resolve()
