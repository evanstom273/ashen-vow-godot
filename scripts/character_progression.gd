class_name CharacterProgression
extends RefCounted
const RULES: ProgressionDefinition = preload("res://data/progression/wanderer_progression.tres")

static func available() -> bool:
	var actor: PlayerController = GameSession.actor
	return GameSession.character != null and is_instance_valid(actor) and actor._session_ready and actor.health > 0 and not actor.in_combat() and actor.state == PlayerController.PlayerState.NORMAL and actor.transformation.phase == PlayerTransformation.Phase.HUMAN

static func level_attribute(key: String) -> String:
	if not available() or key not in CharacterState.ATTRIBUTES: return "Cannot level during combat or an action."
	var actor: PlayerController = GameSession.actor
	var state: CharacterState = GameSession.character
	if int(actor.attributes.get(key)) >= RULES.attribute_cap: return "Attribute is at its cap."
	var price: int = RULES.level_cost(state.level)
	if actor.current_currency < price: return "Not enough Embers."
	actor.current_currency -= price
	actor.attributes.set(key, int(actor.attributes.get(key)) + 1)
	state.level += 1
	_refresh_vitals(actor)
	GameSession.save_now()
	return "Level %d: %s increased." % [state.level, key.capitalize()]

static func respec(values: AttributeStats) -> String:
	if not available() or values == null: return "Cannot respec now."
	var actor: PlayerController = GameSession.actor
	var minimum: AttributeStats = actor.character_class.attributes
	var spent: int = 0
	for key: String in CharacterState.ATTRIBUTES:
		var value: int = int(values.get(key))
		if value < int(minimum.get(key)) or value > RULES.attribute_cap: return "Keep attributes between class minimums and their cap."
		spent += value - int(minimum.get(key))
	if spent != GameSession.character.level - actor.character_class.starting_level: return "Redistribute every earned point. Levels and Embers are not refunded."
	actor.attributes = values.duplicate(true) as AttributeStats
	_refresh_vitals(actor)
	GameSession.save_now()
	return "Attributes redistributed."

static func upgrade(identity: String) -> String:
	if not available(): return "Cannot upgrade now."
	var state: CharacterState = GameSession.character
	var item: EquipmentInstance = state.find_equipment(identity)
	if item == null: return "This equipment is not owned."
	if item.upgrade_level >= RULES.maximum_upgrade: return "Maximum upgrade reached."
	var next: int = item.upgrade_level + 1
	var price: int = RULES.upgrade_cost(next)
	var materials: int = RULES.material_cost(next)
	if GameSession.actor.current_currency < price: return "Not enough Embers."
	if int(state.materials.get(String(RULES.material_id), 0)) < materials: return "Not enough " + RULES.material_name + "s."
	GameSession.actor.current_currency -= price
	state.materials[String(RULES.material_id)] = int(state.materials.get(String(RULES.material_id), 0)) - materials
	item.upgrade_level = next
	GameSession.actor.currency_changed.emit(GameSession.actor.current_currency)
	GameSession.save_now()
	return "%s +%d" % [GameSession.weapon(identity).display_name, next]

static func multiplier(actor: Node, hand: StringName) -> float:
	if actor != GameSession.actor or GameSession.character == null: return 1.0
	var ids: Array[String] = GameSession.character.right_slots if hand == &"right" else GameSession.character.left_slots
	var index: int = actor.right_hand_index if hand == &"right" else actor.left_hand_index
	if index < 0 or index >= ids.size(): return 1.0
	var item: EquipmentInstance = GameSession.character.find_equipment(ids[index])
	return 1.0 + item.upgrade_level * RULES.damage_per_upgrade if item != null else 1.0

static func attack(base: AttackDefinition, actor: Node, hand: StringName) -> AttackDefinition:
	var result := base.duplicate(true) as AttackDefinition
	result.upgrade_multiplier = multiplier(actor, hand)
	return result

static func _refresh_vitals(actor: PlayerController) -> void:
	actor.max_health = actor.vitals.max_health(actor.attributes)
	actor.max_stamina = actor.vitals.max_stamina(actor.attributes)
	actor.max_equip_load = actor.vitals.max_load(actor.attributes)
	actor.health = mini(actor.health, actor.max_health)
	actor.stamina = minf(actor.stamina, actor.max_stamina)
	actor.health_changed.emit(actor.health, actor.max_health)
	actor.stamina_changed.emit(actor.stamina)
	actor.currency_changed.emit(actor.current_currency)
