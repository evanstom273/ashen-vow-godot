class_name SpellDeliveryService
extends RefCounted
static var validation_cache: Dictionary = {}

static func validated(definition: SpellDeliveryDefinition) -> String:
	if definition == null: return "Missing delivery"
	var identity: int = definition.get_instance_id()
	if validation_cache.has(identity):
		var entry: Dictionary = validation_cache[identity]
		if is_instance_valid(entry.resource.get_ref()): return str(entry.error)
	var error: String = validate(definition)
	if validation_cache.size() >= 512: validation_cache.clear()
	_track_definition(definition, {})
	validation_cache[identity] = {"resource": weakref(definition), "error": error}
	return error

static func _invalidate_validation() -> void:
	validation_cache.clear()

static func _track_definition(resource: Resource, visited: Dictionary) -> void:
	if resource == null or visited.has(resource) or not resource.get_script() is Script: return
	visited[resource] = true
	if not resource.changed.is_connected(_invalidate_validation): resource.changed.connect(_invalidate_validation)
	for property: Dictionary in resource.get_property_list():
		if not (int(property.usage) & PROPERTY_USAGE_STORAGE) or property.name == &"script": continue
		var value: Variant = resource.get(property.name)
		if value is Resource: _track_definition(value, visited)
		elif value is Array:
			for child: Variant in value:
				if child is Resource: _track_definition(child, visited)

static func alive(actor: Node) -> bool:
	return is_instance_valid(actor) and actor.is_inside_tree() and (actor.get("health") == null or int(actor.get("health")) > 0)

static func on_plane(context: SpellCastContext, actor: Node) -> bool:
	return is_instance_valid(actor) and (context.cross_elevations or Elevation.occupies(actor, context.elevation))

static func targets(context: SpellCastContext, filter: String = "Hostile", center: Vector2 = Vector2.INF, radius: float = 0.0) -> Array[Node2D]:
	var result: Array[Node2D] = []
	if not alive(context.caster): return result
	if filter == "Caster":
		if on_plane(context, context.caster): result.append(context.caster)
		return result
	# Conditional array literals lose their element type in GDScript.
	var groups: Array[String] = []
	if context.faction == &"enemy":
		if filter == "Hostile":
			groups.append("player")
			groups.append("spell_ally")
		else:
			groups.append("enemy")
	elif filter == "Hostile":
		groups.append("targetable")
	else:
		groups.append("player")
		groups.append("spell_ally")
	var candidates: Array[Node2D] = []
	if center.is_finite() and radius > 0.0: candidates = ActorRegistry.nearby(center, radius + 256.0)
	else: candidates = ActorRegistry.registered()
	for group: String in groups:
		for actor: Node2D in candidates:
			if not actor.is_in_group(group): continue
			if not actor is Node2D or not alive(actor) or result.has(actor): continue
			if not on_plane(context, actor): continue
			if filter == "Hostile" and actor.has_method("is_targetable") and not actor.is_targetable(): continue
			if filter == "Hostile" and (actor == context.caster or (context.faction == &"ally" and actor.is_in_group("spell_ally"))): continue
			result.append(actor)
	return result

static func wall_end(context: SpellCastContext, start: Vector2, end: Vector2) -> Vector2:
	var query := PhysicsRayQueryParameters2D.create(start, end, 1)
	if context.caster is CollisionObject2D: query.exclude = [(context.caster as CollisionObject2D).get_rid()]
	var ray_result: Dictionary = Elevation.ray(context.caster, query, context.elevation, context.cross_elevations)
	return ray_result.position if not ray_result.is_empty() else end

static func visible(context: SpellCastContext, start: Vector2, end: Vector2) -> bool:
	return wall_end(context, start, end).distance_to(end) < 2.0

static func target_radius(actor: Node2D) -> float:
	# Existing receiver padding is actor-local, not a fixed ten world units.
	return 10.0 * WorldScale.actor_scale(actor)

static func placement_clear(context: SpellCastContext, point: Vector2, radius: float = 48.0) -> bool:
	if not Elevation.of(context.caster).support_at(point, context.elevation, radius): return false
	var shape := CircleShape2D.new()
	shape.radius = radius
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(0, point)
	query.collision_mask = 1
	if context.caster is CollisionObject2D: query.exclude = [(context.caster as CollisionObject2D).get_rid()]
	return Elevation.shapes(context.caster, query, context.elevation, 1).is_empty()

static func validate(definition: SpellDeliveryDefinition, visited: Array = [], in_summon: bool = false) -> String:
	if definition == null: return "Missing delivery"
	if visited.has(definition) or visited.size() >= 8: return "Cyclic or excessively nested delivery"
	if definition.kind() == &"abstract": return "Choose a concrete delivery resource"
	if in_summon and (definition.is_channel() or definition is DashDelivery or definition is ImbueDelivery): return "Summon attacks must be independent deliveries"
	if definition.duration <= 0 or definition.tick_interval <= 0 or definition.max_instances < 1 or definition.max_instances > 16: return "Invalid duration, interval or instance limit"
	if definition.cast_range <= 0 or definition.cast_range > 8000: return "Invalid cast range (1–8000 world units)"
	if definition.attack != null and definition.attack.max_health_drain != null and not definition.attack.max_health_drain.is_valid():
		return "Invalid attack maximum-health burn"
	var path: Array = visited.duplicate()
	path.append(definition)
	for property: Dictionary in definition.get_property_list():
		var field: String = property.name
		var value: Variant = definition.get(field)
		if field in ["count", "target_count", "trigger_count"] and (int(value) < 1 or int(value) > 32): return "Delivery count must be 1–32"
		if field in ["fire_interval", "impact_interval", "jump_delay", "rearm_interval"] and float(value) <= 0: return "Delivery intervals must be positive"
		if field in ["radius", "width", "thickness", "length", "distance", "hit_width", "trigger_radius", "break_range", "jump_radius", "orbit_radius", "impact_radius", "placement_distance"] and (float(value) <= 0 or float(value) > 8000): return "Delivery dimensions must be 0–8000 world units"
		if field in ["speed", "turn_rate", "steering", "initial_delay", "arming_delay", "telegraph_duration"] and float(value) < 0: return "Negative delivery parameter"
		if field == "pierce_count" and (int(value) < 0 or int(value) > 32): return "Pierce count must be 0–32"
		if field == "child":
			var error: String = validate(value as SpellDeliveryDefinition, path, in_summon)
			if not error.is_empty(): return error
	for effect: SpellEffectDefinition in definition.effects:
		if effect == null: return "Missing effect"
		if not effect.validation_error().is_empty(): return effect.validation_error()
	if definition is OrbitingDelivery and not definition.child is ProjectileDelivery: return "Orbiters require a projectile child"
	if definition is ImbueDelivery and (definition.bonus_damage == null or definition.recipient not in ["opposite", "left", "right"]): return "Invalid weapon imbue"
	if definition is DashDelivery and (definition.invulnerability_start < 0 or definition.invulnerability_end > 1 or definition.invulnerability_start > definition.invulnerability_end): return "Invalid dash invulnerability window"
	if definition is ConeDelivery and (definition.angle_degrees <= 0 or definition.angle_degrees > 360): return "Invalid cone angle"
	if definition is ChainDelivery and (definition.damage_falloff < 0 or definition.damage_falloff > 1): return "Invalid chain falloff"
	if definition is TetherDelivery:
		var drain: MaxHealthDrainDefinition = definition.drain_definition()
		if drain != null:
			if not drain.is_valid():
				return "Invalid maximum-health drain curve"
		for effect: SpellEffectDefinition in definition.completion_effects:
			if effect == null: return "Missing completion effect"
			if not effect.validation_error().is_empty(): return effect.validation_error()
	if definition is SummonDelivery:
		if in_summon: return "Summons cannot summon"
		var summon: SummonDefinition = definition.summon
		if summon == null or summon.health <= 0 or summon.attack_interval <= 0: return "Invalid summon"
		if summon.delivery != null and (summon.delivery.is_channel() or summon.delivery is DashDelivery or summon.delivery is ImbueDelivery): return "Summon attacks must be independent deliveries"
		if summon.scene != null and not SceneContract.inherits_script(summon.scene, &"SpellSummon"):
			return "Summon scene requires SpellSummon"
		return validate(summon.delivery, path, true)
	return ""

static func launch(definition: SpellDeliveryDefinition, context: SpellCastContext) -> Node2D:
	if definition == null or context == null: return null
	if not alive(context.caster) or context.depth > 8: return null
	context.cross_elevations = context.cross_elevations or definition.cross_elevations
	var payload: AttackDefinition = definition.attack if definition.attack != null else context.attack
	if payload != null: context.cross_elevations = context.cross_elevations or payload.cross_elevations
	var siblings: Array[Node] = []
	for node: Node in context.caster.get_tree().get_nodes_in_group("spell_delivery"):
		if node.get("context").ownership == context.ownership and node.get("context").caster == context.caster and node.get("context").depth == context.depth:
			siblings.append(node)
	while siblings.size() >= definition.max_instances and context.depth == 0:
		var oldest: Node = siblings.pop_front()
		oldest.call("cancel")
	var instance := Node2D.new()
	instance.set_script(load("res://scripts/spell_delivery_runtime.gd"))
	instance.set("definition", definition)
	instance.set("context", context)
	instance.set_meta(&"elevation_level", context.elevation)
	WorldScale.attach_art(instance, context.caster.get_tree().current_scene, context.origin, 1.0)
	return instance

static func hit(definition: SpellDeliveryDefinition, context: SpellCastContext, actor: Node2D, multiplier: float = 1.0) -> HitResult:
	if not alive(actor): return HitResult.reject(&"invalid_target")
	var outcome := HitResult.accept()
	var attack: AttackDefinition = definition.attack if definition.attack != null else context.attack
	var cross: bool = context.cross_elevations or definition.cross_elevations or (attack != null and attack.cross_elevations)
	if not cross and not Elevation.occupies(actor, context.elevation): return HitResult.reject(&"elevation")
	if definition.target_filter == "Hostile":
		var payload: AttackDefinition = attack.duplicate(true) as AttackDefinition if attack != null else AttackDefinition.new()
		payload.has_hit_elevation = true
		payload.upgrade_multiplier = context.upgrade_multiplier
		payload.hit_elevation = context.elevation
		payload.cross_elevations = cross
		payload.recurring_feedback = definition.kind() in [&"beam", &"cone", &"zone", &"aura", &"tether"] or context.from_summon
		if payload.feedback == null and context.profile != null: payload.feedback = context.profile.impact_feedback
		if payload.recurring_feedback:
			payload.hit_stop = 0.0
			payload.camera_shake = 0.0
		elif payload.feedback != null:
			payload.hit_stop = payload.feedback.hit_stop
			payload.camera_shake = 0.0
		if payload.damage != null:
			for channel: String in ["physical", "magic", "fire", "lightning", "holy"]:
				payload.damage.set(channel, float(payload.damage.get(channel)) * multiplier)
		if attack != null:
			outcome = HitRequest.deliver(actor, payload, context.attributes, context.attribution)
			# A zero-damage slow/curse is still a contact, but must pass the same
			# dodge, protection, death and floor gates before attaching an effect.
			if outcome.reason == &"no_damage" and not definition.effects.is_empty(): outcome = HitResult.accept()
		else:
			var rejected: StringName = HitRequest.rejection(actor, payload, context.attribution)
			if not rejected.is_empty(): return HitResult.reject(rejected)
			if definition.effects.is_empty(): return HitResult.reject(&"no_payload")
		if not outcome.accepted or not alive(actor): return outcome
	for effect: SpellEffectDefinition in definition.effects:
		if effect == null: continue
		if SpellEffects.of(actor).apply(effect, context): outcome.applied_effects.append(effect.id)
	return outcome

static func clear_owned(caster: Node) -> void:
	Feedback.clear_spell_visuals(caster.get_instance_id())
	for instance: Node in caster.get_tree().get_nodes_in_group("spell_delivery"):
		if instance.get("context").attribution == caster or instance.get("context").caster == caster: instance.call("cancel")
	for ally: Node in caster.get_tree().get_nodes_in_group("spell_ally"):
		if ally.get("context").attribution == caster: ally.queue_free()
