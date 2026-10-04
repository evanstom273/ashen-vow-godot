class_name ActorStatuses
extends Node
## Actor-owned meters. Status Resources remain immutable, including proc attacks.
var meters: Dictionary = {}

static func of(actor: Node) -> ActorStatuses:
	var component := actor.get_node_or_null("ActorStatuses") as ActorStatuses
	if component != null: return component
	component = ActorStatuses.new()
	component.name = "ActorStatuses"
	actor.add_child(component)
	return component

func add(application: StatusApplication, source: Node, stats: AttributeStats) -> bool:
	if application == null or application.status == null or application.buildup <= 0: return false
	var definition: StatusDefinition = application.status
	var actor := get_parent() as Node2D
	var vitals: Variant = actor.get("vitals")
	var resistance: float = 1.0
	if vitals is VitalStats:
		if vitals.status_immunities.has(definition.id): return false
		resistance = clampf(float(vitals.status_resistances.get(definition.id, 1.0)), 0.1, 10.0)
	if not meters.has(definition.id):
		meters[definition.id] = {"definition": definition, "value": 0.0, "delay": 0.0, "cooldown": 0.0, "threshold": definition.threshold * resistance}
	var entry: Dictionary = meters[definition.id]
	if entry.cooldown > 0: return false
	entry.value = minf(float(entry.threshold), float(entry.value) + application.buildup)
	entry.delay = definition.decay_delay
	if entry.value < entry.threshold: return true
	entry.value = 0.0
	entry.cooldown = definition.retrigger_delay
	var context := SpellCastContext.new()
	context.caster = source as Node2D if is_instance_valid(source) else actor
	context.attribution = context.caster
	context.attributes = stats.duplicate(true) as AttributeStats if stats != null else AttributeStats.new()
	context.elevation = Elevation.level(actor)
	if definition.triggered_effect != null: SpellEffects.of(actor).apply(definition.triggered_effect, context)
	if definition.triggered_attack != null:
		var payload := definition.triggered_attack.duplicate(true) as AttackDefinition
		payload.statuses.clear() # A proc cannot recursively build itself.
		payload.periodic_damage = true
		payload.accepted_contact_child = true
		payload.has_hit_elevation = true
		payload.hit_elevation = Elevation.level(actor)
		HitRequest.deliver(actor, payload, context.attributes, context.attribution)
	if definition.vfx != null and (definition.vfx.style != VFXDefinition.Style.FLESH or Feedback.blood_enabled):
		var visual: Node2D = Feedback.spell_effect(actor.global_position, definition.vfx, &"burst", actor)
		if is_instance_valid(visual) and definition.vfx.style == VFXDefinition.Style.FLESH: visual.add_to_group("blood_fx")
	Feedback.play("status", actor.global_position, 0.0, actor)
	return true

func cleanse(tags: Array[StringName]) -> void:
	for key: Variant in meters.keys():
		var definition: StatusDefinition = meters[key].definition
		for tag: StringName in tags:
			if definition.tags.has(tag):
				meters.erase(key)
				break

func clear() -> void:
	meters.clear()

func _physics_process(delta: float) -> void:
	if not SpellDeliveryService.alive(get_parent()):
		clear()
		return
	for key: Variant in meters.keys():
		var entry: Dictionary = meters[key]
		var definition: StatusDefinition = entry.definition
		entry.cooldown = maxf(0.0, float(entry.cooldown) - delta)
		var decay_step: float = maxf(0.0, delta - float(entry.delay))
		entry.delay = maxf(0.0, float(entry.delay) - delta)
		entry.value = maxf(0.0, float(entry.value) - definition.decay_per_second * decay_step)
		if entry.value <= 0 and entry.cooldown <= 0: meters.erase(key)
