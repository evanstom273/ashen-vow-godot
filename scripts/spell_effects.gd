class_name SpellEffects
extends Node
var entries: Dictionary = {}
var imbues: Dictionary = {}
var burns: Dictionary = {}

static func apply_attack(actor: Node2D, attack: AttackDefinition, stats: AttributeStats, source: Node) -> void:
	if attack == null or attack.max_health_drain == null: return
	if not attack.max_health_drain.is_valid() or not is_instance_valid(source): return
	if actor.get("max_health") == null or float(actor.get("max_health")) <= 0: return
	of(actor)._apply_burn(attack.max_health_drain, stats, source)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE

func _apply_burn(definition: MaxHealthDrainDefinition, stats: AttributeStats, source: Node) -> void:
	var actor := get_parent() as Node2D
	var duration: float = definition.lifetime(stats)
	var visual: Node2D
	if burns.has(definition.id):
		var previous: Variant = burns[definition.id].visual
		if is_instance_valid(previous): visual = previous as Node2D
	if visual == null and definition.vfx != null:
		visual = Feedback.spell_visual(definition.vfx, {"kind": &"burn", "origin": actor.global_position, "duration": duration, "owner_id": actor.get_instance_id()}, actor)
		if visual is SpellVisual: visual.follow = actor
	# Same ID refreshes rather than stacking; preserve the sub-tick clock.
	var clock: float = float(burns[definition.id].clock) if burns.has(definition.id) else 0.0
	var carry: float = 0.0
	if burns.has(definition.id):
		var previous_entry: Dictionary = burns[definition.id]
		carry = float(previous_entry.carry) + float(previous_entry.total) * float(previous_entry.elapsed) / float(previous_entry.duration) - int(previous_entry.scheduled)
	burns[definition.id] = {"elapsed": 0.0, "duration": duration, "clock": clock, "carry": carry, "scheduled": 0, "total": float(actor.get("max_health")) * definition.total_fraction(stats), "source_id": source.get_instance_id(), "visual": visual}

func _remove_burn(key: Variant) -> void:
	if not burns.has(key): return
	var visual: Variant = burns[key].visual
	if is_instance_valid(visual): visual.queue_free()
	burns.erase(key)

func _tick_burns(delta: float) -> void:
	for key: Variant in burns.keys():
		if not burns.has(key): continue
		var entry: Dictionary = burns[key]
		var source: Node = instance_from_id(int(entry.source_id)) as Node
		if not SpellDeliveryService.alive(source):
			_remove_burn(key)
			continue
		var step: float = minf(delta, maxf(0.0, float(entry.duration) - float(entry.elapsed)))
		entry.elapsed += step
		entry.clock += step
		if entry.clock >= 0.05 or entry.elapsed >= entry.duration:
			entry.clock = fmod(float(entry.clock), 0.05)
			var scheduled: int = roundi(float(entry.carry) + float(entry.total) * minf(1.0, float(entry.elapsed) / float(entry.duration)))
			var amount: int = maxi(0, scheduled - int(entry.scheduled))
			entry.scheduled = scheduled
			if amount > 0:
				var payload := AttackDefinition.new()
				payload.resolved_health_damage = amount
				payload.periodic_damage = true
				payload.poise_damage = 0.0
				payload.knockback = 0.0
				payload.hit_stop = 0.0
				payload.camera_shake = 0.0
				# An already attached burn travels with its receiver, not its caster.
				payload.has_hit_elevation = true
				payload.hit_elevation = Elevation.level(get_parent())
				get_parent().receive_hit(payload, null, source)
		if entry.elapsed >= entry.duration or not SpellDeliveryService.alive(get_parent()): _remove_burn(key)

static func of(actor: Node) -> SpellEffects:
	var existing := actor.get_node_or_null("SpellEffects") as SpellEffects
	if existing != null: return existing
	var result := SpellEffects.new()
	result.name = "SpellEffects"
	actor.add_child(result)
	return result

static func movement(actor: Node) -> float:
	var component := actor.get_node_or_null("SpellEffects") as SpellEffects
	if component == null: return 1.0
	var multiplier: float = 1.0
	for entry: Dictionary in component.entries.values():
		multiplier *= (entry.definition as SpellEffectDefinition).movement_multiplier
	return clampf(multiplier, 0.1, 2.0)

static func defence(actor: Node, base: DefenceProfile) -> DefenceProfile:
	var component := actor.get_node_or_null("SpellEffects") as SpellEffects
	if component == null or component.entries.is_empty(): return base
	var result: DefenceProfile = base.duplicate(true) as DefenceProfile if base != null else DefenceProfile.new()
	for entry: Dictionary in component.entries.values():
		var bonus: DefenceProfile = (entry.definition as SpellEffectDefinition).defence_bonus
		if bonus == null: continue
		for channel: String in ["physical", "magic", "fire", "lightning", "holy"]:
			result.set(channel, clampf(float(result.get(channel)) + float(bonus.get(channel)), -100, 100))
	return result

func apply(definition: SpellEffectDefinition, context: SpellCastContext) -> void:
	for key: Variant in entries.keys():
		var previous: SpellEffectDefinition = entries[key].definition
		if previous.negative:
			for tag: StringName in definition.cleanse_tags:
				if previous.tags.has(tag):
					entries.erase(key)
					break
	_restore(definition.health_restore, definition.stamina_restore)
	if definition.duration > 0:
		var accumulated: float = float(entries[definition.id].tick) if entries.has(definition.id) else 0.0
		entries[definition.id] = {"definition": definition, "remaining": definition.duration, "tick": accumulated, "context": context}

func _restore(hp: int, stamina_amount: float) -> void:
	var actor: Node = get_parent()
	if actor.get("health") != null and int(actor.get("health")) > 0:
		actor.set("health", mini(int(actor.get("max_health")), int(actor.get("health")) + hp))
		if actor.has_signal("health_changed"): actor.emit_signal("health_changed", actor.get("health"), actor.get("max_health"))
	if actor.get("stamina") != null:
		actor.set("stamina", minf(float(actor.get("max_stamina")), float(actor.get("stamina")) + stamina_amount))
		if actor.has_signal("stamina_changed"): actor.emit_signal("stamina_changed", actor.get("stamina"))

func clear() -> void:
	for key: Variant in burns.keys(): _remove_burn(key)
	entries.clear()
	imbues.clear()

func _physics_process(delta: float) -> void:
	if get_parent().get("health") != null and int(get_parent().get("health")) <= 0:
		clear()
		return
	_tick_burns(delta)
	if not SpellDeliveryService.alive(get_parent()):
		clear()
		return
	for key: Variant in entries.keys():
		if not entries.has(key): continue
		var entry: Dictionary = entries[key]
		if not SpellDeliveryService.alive((entry.context as SpellCastContext).attribution):
			entries.erase(key)
			continue
		var definition: SpellEffectDefinition = entry.definition
		var step: float = minf(delta, entry.remaining)
		entry.remaining -= step
		entry.tick += step
		while entry.tick >= definition.interval:
			entry.tick -= definition.interval
			_restore(definition.periodic_heal, 0)
			var context: SpellCastContext = entry.context
			if definition.periodic_attack != null and is_instance_valid(context.attribution):
				get_parent().receive_hit(Elevation.stamp_attack(definition.periodic_attack, Elevation.level(get_parent())), context.attributes, context.attribution)
			if not entries.has(key): break
		if entry.remaining <= 0: entries.erase(key)
	for token: Variant in imbues.keys():
		imbues[token].remaining -= delta
		if imbues[token].remaining <= 0: imbues.erase(token)

func imbue_attack(base: AttackDefinition, token: int) -> AttackDefinition:
	if not imbues.has(token): return base
	var bonus: DamageProfile = imbues[token].damage
	if bonus == null: return base
	var result := base.duplicate(true) as AttackDefinition
	result.unscaled_bonus_damage = bonus.duplicate(true) as DamageProfile
	return result
