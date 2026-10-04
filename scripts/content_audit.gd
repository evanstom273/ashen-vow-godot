class_name ContentAudit
extends RefCounted
## Explicitly invoked authoring diagnostics. Does not instantiate scenes or mutate assets.
## Parsing/import errors must be resolved first; this is not a substitute for the editor parser.

static func inspect(catalogue: GameDataCatalog) -> Array[String]:
	var issues: Array[String] = []
	if catalogue == null:
		issues.append("Missing game catalogue")
		return issues
	for collection: StringName in [&"classes", &"weapons", &"enemies", &"bosses", &"spells", &"utilities", &"currencies"]:
		var ids: Dictionary = {}
		for resource: Resource in catalogue.get(collection):
			if resource == null:
				issues.append(String(collection) + ": null catalogue entry")
				continue
			var identity: String = String(resource.get("id"))
			if identity.is_empty() or ids.has(identity): issues.append(String(collection) + ": empty/duplicate ID " + identity)
			ids[identity] = true
			var path: String = resource.resource_path
			if resource is WeaponDefinition:
				_check_attack(resource.light_attack, path + " light", issues)
				_check_attack(resource.charged_attack, path + " charged", issues)
				if resource.equipped_scene != null and not SceneContract.root_is(resource.equipped_scene, &"Node2D"):
					issues.append(path + ": equipment scene needs Node2D root")
				if resource.equipped_scene != null:
					for socket: String in ["Sockets/Grip", "Sockets/Tip", "Sockets/Cast"]:
						if not SceneContract.has_node(resource.equipped_scene, socket): issues.append(path + ": missing equipment " + socket)
				if resource.basic_spell != null and (not resource.is_spell_catalyst or not resource.basic_spell.is_basic()): issues.append(path + ": basic spell needs catalyst/basic-use policy")
			elif resource is SpellDefinition:
				_check_attack(resource.cast, path + " cast", issues)
				var error: String = SpellDeliveryService.validate(resource.delivery_definition) if resource.delivery_definition != null else ""
				if not error.is_empty(): issues.append(path + ": " + error)
				if resource.charges > resource.maximum_charges: issues.append(path + ": starting uses exceed maximum")
				# Existing first-five icons use the retained procedural equipment renderer.
				if resource.icon == null and resource.id not in [&"star_shard", &"cinder_lance", &"vow_spear", &"ember_wave", &"mending_light"]: issues.append(path + ": missing icon")
			elif resource is EnemyDefinition:
				for move: EnemyMove in resource.moves:
					if move == null: issues.append(path + ": null enemy move"); continue
					_check_attack(move.attack, path + " move " + String(move.id), issues)
					if move.minimum_metres < 0 or move.maximum_metres <= move.minimum_metres or move.cooldown < 0: issues.append(path + ": invalid enemy move range/cooldown")
			elif resource is UtilityDefinition:
				if resource.use_time < 0 or resource.recovery_time < 0: issues.append(path + ": invalid use/recovery time")
			elif resource is ClassDefinition and resource.spell_loadout != null:
				var memory: int = 0
				for spell: SpellDefinition in resource.spell_loadout.spells:
					if spell != null: memory += spell.memory_slots
				if memory > resource.spell_loadout.base_slots: issues.append(path + ": starting spells exceed memory capacity")
	var visited: Dictionary = {}
	_scan_resources(catalogue, visited, issues)
	return issues

static func _check_attack(attack: AttackDefinition, label: String, issues: Array[String]) -> void:
	if attack == null:
		issues.append(label + ": missing action")
		return
	for field: StringName in [&"windup", &"active", &"recovery", &"stamina_cost", &"charge_threshold", &"poise_damage", &"knockback"]:
		var value: float = float(attack.get(field))
		if not is_finite(value) or value < 0: issues.append(label + ": invalid " + String(field))
	if attack.reach <= 0 or attack.hit_radius <= 0 or attack.arc_degrees <= 0 or attack.arc_degrees > 360:
		issues.append(label + ": invalid attack geometry")
	if attack.max_health_drain != null and not attack.max_health_drain.is_valid(): issues.append(label + ": invalid health-drain curve")
	if attack.damage != null:
		for channel: StringName in [&"physical", &"magic", &"fire", &"lightning", &"holy"]:
			var amount: float = float(attack.damage.get(channel))
			if not is_finite(amount) or amount < 0: issues.append(label + ": invalid damage channel " + String(channel))
	if attack.vfx != null and not SceneContract.root_is(attack.vfx, &"Node2D"): issues.append(label + ": impact scene needs Node2D root")

static func _scan_resources(resource: Resource, visited: Dictionary, issues: Array[String]) -> void:
	if resource == null or visited.has(resource): return
	visited[resource] = true
	if resource is AttackDefinition: _check_attack(resource, resource.resource_path, issues)
	if resource is StatusDefinition:
		if resource.id.is_empty() or resource.icon == null: issues.append(resource.resource_path + ": status requires identity and icon")
		if not is_finite(resource.threshold) or resource.threshold <= 0: issues.append(resource.resource_path + ": status threshold must be positive")
		if resource.triggered_effect == null and resource.triggered_attack == null: issues.append(resource.resource_path + ": status has no proc payload")
	if resource is StatusApplication:
		if resource.status == null or not is_finite(resource.buildup) or resource.buildup <= 0: issues.append(resource.resource_path + ": invalid status application")
	if resource is VitalStats:
		for key: StringName in resource.status_resistances:
			if not is_finite(resource.status_resistances[key]) or resource.status_resistances[key] <= 0: issues.append(resource.resource_path + ": invalid status resistance " + String(key))
	if resource is SpellEffectDefinition:
		var error: String = resource.validation_error()
		if not error.is_empty(): issues.append(resource.resource_path + ": " + error)
	if resource is VFXDefinition:
		for scene: PackedScene in [resource.cast_scene, resource.delivery_scene, resource.impact_scene]:
			if scene != null and not SceneContract.root_is(scene, &"Node2D"): issues.append(resource.resource_path + ": visual scene needs Node2D root")
	# Follow authored definitions only, not textures, PackedScenes or Script internals.
	if not resource.get_script() is Script: return
	for property: Dictionary in resource.get_property_list():
		if not (int(property.usage) & PROPERTY_USAGE_STORAGE) or property.name == &"script": continue
		var value: Variant = resource.get(property.name)
		if value is Resource: _scan_resources(value, visited, issues)
		elif value is Array:
			for item: Variant in value:
				if item is Resource: _scan_resources(item, visited, issues)
