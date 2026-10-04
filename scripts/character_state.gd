class_name CharacterState
extends RefCounted
## Serializable character state; definitions are resolved only through the catalogue.
const ATTRIBUTES: Array[String] = ["vigour", "endurance", "strength", "dexterity", "intelligence", "faith", "arcane"]
var class_id: StringName = &"wanderer"
var level: int = 1
var attributes := AttributeStats.new()
var currency: int = 0
var health: int = 1
var stamina: float = 0.0
var equipment: Array[EquipmentInstance] = []
var right_slots: Array[String] = []
var left_slots: Array[String] = []
var prepared_spells: Array[String] = []
var prepared_utilities: Array[String] = []
var known_spells: Array[String] = []
var known_utilities: Array[String] = []
var spell_uses: Dictionary = {}
var utility_uses: Array[int] = []
var utility_pool: Dictionary = {}
var selected: Array[int] = [0, 0, 0, 0]
var memory_bonus: int = 0
var scene: String = "res://scenes/forest_camp.tscn"
var position: Vector2 = Vector2.ZERO
var elevation: int = 0
var last_ground: Vector2 = Vector2.ZERO
var ground_elevation: int = 0
var checkpoint: Dictionary = {}
var recovery: Dictionary = {}
var attuned_shrines: Dictionary = {}
var world_flags: Dictionary = {}
var world_pickups: Dictionary = {}
var next_reward_id: int = 1
var navigation: Dictionary = {}
var materials: Dictionary = {}
var climate: Dictionary = {}
var needs_respawn: bool = false
var next_item_id: int = 1

func add_equipment(definition: WeaponDefinition) -> EquipmentInstance:
	var item := EquipmentInstance.new()
	while find_equipment("equipment_%d" % next_item_id) != null: next_item_id += 1
	item.id = "equipment_%d" % next_item_id
	next_item_id += 1
	item.definition_id = definition.id
	equipment.append(item)
	return item

func find_equipment(identity: String) -> EquipmentInstance:
	for item: EquipmentInstance in equipment:
		if item.id == identity: return item
	return null

func to_record() -> Dictionary:
	var stats: Dictionary = {}
	for key: String in ATTRIBUTES: stats[key] = attributes.get(key)
	var items: Array[Dictionary] = []
	for item: EquipmentInstance in equipment: items.append(item.to_record())
	return {"class": String(class_id), "level": level, "attributes": stats,
		"currency": currency, "health": health, "stamina": stamina, "equipment": items,
		"right": right_slots, "left": left_slots, "spells": prepared_spells,
		"utilities": prepared_utilities, "known_spells": known_spells,
		"known_utilities": known_utilities, "spell_uses": spell_uses,
		"utility_uses": utility_uses, "utility_pool": utility_pool, "selected": selected, "memory_bonus": memory_bonus,
		"scene": scene, "position": point(position), "elevation": elevation,
		"last_ground": point(last_ground), "ground_elevation": ground_elevation,
		"checkpoint": checkpoint, "recovery": recovery, "shrines": attuned_shrines,
		"world_flags": world_flags, "world_pickups": world_pickups, "next_reward_id": next_reward_id,
		"navigation": navigation, "materials": materials, "climate": climate,
		"needs_respawn": needs_respawn, "next_item_id": next_item_id}

static func point(value: Vector2) -> Array[float]:
	return [value.x, value.y]

static func vector(value: Variant, fallback: Vector2 = Vector2.ZERO) -> Vector2:
	if not value is Array or value.size() != 2: return fallback
	if not (value[0] is float or value[0] is int) or not (value[1] is float or value[1] is int): return fallback
	var result := Vector2(float(value[0]), float(value[1]))
	return result if result.is_finite() else fallback

static func from_record(record: Dictionary) -> CharacterState:
	var state := CharacterState.new()
	state.class_id = StringName(record.get("class", "wanderer"))
	state.level = clampi(int(record.get("level", 1)), 1, 999)
	var stats: Dictionary = record.get("attributes", {})
	for key: String in ATTRIBUTES: state.attributes.set(key, clampi(int(stats.get(key, 10)), 0, 99))
	state.currency = clampi(int(record.get("currency", 0)), 0, 2000000000)
	state.health = maxi(0, int(record.get("health", 1)))
	state.stamina = maxf(0.0, float(record.get("stamina", 0.0)))
	for item: Dictionary in record.get("equipment", []):
		var owned: EquipmentInstance = EquipmentInstance.from_record(item)
		if not owned.id.is_empty() and state.find_equipment(owned.id) == null: state.equipment.append(owned)
	for pair: Array in [["right", state.right_slots], ["left", state.left_slots], ["spells", state.prepared_spells], ["utilities", state.prepared_utilities], ["known_spells", state.known_spells], ["known_utilities", state.known_utilities]]:
		for value: Variant in record.get(pair[0], []): pair[1].append(String(value))
	state.spell_uses = record.get("spell_uses", {}).duplicate(true)
	for value: Variant in record.get("utility_uses", []): state.utility_uses.append(maxi(0, int(value)))
	state.utility_pool = record.get("utility_pool", {}).duplicate(true)
	for index in mini(state.prepared_utilities.size(), state.utility_uses.size()):
		if not state.prepared_utilities[index].is_empty(): state.utility_pool[state.prepared_utilities[index]] = state.utility_uses[index]
	var selected_values: Array = record.get("selected", [])
	for index in mini(4, selected_values.size()): state.selected[index] = maxi(0, int(selected_values[index]))
	state.memory_bonus = clampi(int(record.get("memory_bonus", 0)), 0, 100)
	state.scene = String(record.get("scene", state.scene))
	state.position = vector(record.get("position"))
	state.elevation = int(record.get("elevation", 0))
	state.last_ground = vector(record.get("last_ground"), state.position)
	state.ground_elevation = int(record.get("ground_elevation", 0))
	state.checkpoint = record.get("checkpoint", {}).duplicate(true)
	state.recovery = record.get("recovery", {}).duplicate(true)
	state.attuned_shrines = record.get("shrines", {}).duplicate(true)
	state.world_flags = record.get("world_flags", {}).duplicate(true)
	state.world_pickups = record.get("world_pickups", {}).duplicate(true)
	state.next_reward_id = maxi(1, int(record.get("next_reward_id", 1)))
	state.navigation = record.get("navigation", {}).duplicate(true)
	state.materials = record.get("materials", {}).duplicate(true)
	state.climate = record.get("climate", {}).duplicate(true)
	state.needs_respawn = bool(record.get("needs_respawn", false)) or state.health == 0
	state.next_item_id = maxi(int(record.get("next_item_id", 1)), state.equipment.size() + 1)
	return state

static func valid_record(record: Dictionary) -> bool:
	var pool: Variant = record.get("utility_pool", {})
	if not pool is Dictionary or pool.size() > 4096: return false
	for identity: Variant in pool:
		if not identity is String or not _number(pool[identity]): return false
	var climate_state: Variant = record.get("climate", {})
	if not climate_state is Dictionary or climate_state.size() > 8: return false
	for value: Variant in climate_state.values():
		if not _number(value): return false
	if not record.get("class") is String or not record.get("attributes") is Dictionary: return false
	if not record.get("scene") is String or not record.get("needs_respawn") is bool: return false
	for key: String in ["level", "currency", "health", "stamina", "memory_bonus", "elevation", "ground_elevation", "next_item_id"]:
		if not _number(record.get(key)): return false
	for key: String in ["level", "currency", "health", "memory_bonus", "elevation", "ground_elevation", "next_item_id"]:
		if float(record[key]) != floorf(float(record[key])): return false
	if int(record.level) < 1 or int(record.level) > 999 or int(record.next_item_id) < 1: return false
	if int(record.currency) < 0 or int(record.health) < 0 or float(record.stamina) < 0: return false
	if int(record.memory_bonus) < 0 or int(record.memory_bonus) > 100: return false
	if not _point_valid(record.get("position")) or not _point_valid(record.get("last_ground")): return false
	for key: String in ATTRIBUTES:
		var value: Variant = record.attributes.get(key)
		if not _number(value) or float(value) != floorf(float(value)) or float(value) < 0 or float(value) > 99: return false
	for key: String in ["equipment", "right", "left", "spells", "utilities", "known_spells", "known_utilities", "utility_uses", "selected"]:
		if not record.get(key) is Array or record[key].size() > 4096: return false
	for key: String in ["spell_uses", "checkpoint", "recovery", "shrines", "world_flags", "navigation", "materials"]:
		if not record.get(key) is Dictionary or record[key].size() > 4096: return false
	for key: String in ["right", "left", "spells", "utilities", "known_spells", "known_utilities"]:
		for value: Variant in record[key]:
			if not value is String: return false
	var identities: Array[String] = []
	for value: Variant in record.equipment:
		if not value is Dictionary or not value.get("id") is String or not value.get("definition") is String: return false
		if value.id.is_empty() or identities.has(value.id) or not _number(value.get("upgrade")): return false
		if float(value.upgrade) != floorf(float(value.upgrade)) or float(value.upgrade) < 0 or float(value.upgrade) > 25: return false
		identities.append(value.id)
	for key: String in ["right", "left"]:
		for identity: String in record[key]:
			if not identity.is_empty() and not identities.has(identity): return false
	for key: String in ["utility_uses", "selected"]:
		for value: Variant in record[key]:
			if not _number(value): return false
	for key: String in ["spell_uses", "materials"]:
		for value: Variant in record[key].values():
			if not _number(value): return false
	if not _placement_valid(record.checkpoint): return false
	if not record.recovery.is_empty():
		if not _placement_valid(record.recovery) or not _number(record.recovery.get("amount")): return false
	for value: Variant in record.shrines.values():
		if not value is Dictionary or not _placement_valid(value): return false
	for value: Variant in record.world_flags.values():
		if not value is bool: return false
	if not _number(record.get("next_reward_id", 1)): return false
	var pickups: Variant = record.get("world_pickups", {})
	if not pickups is Dictionary or pickups.size() > 4096: return false
	for value: Variant in pickups.values():
		if not value is Dictionary or not _placement_valid(value): return false
		if not _number(value.get("amount")) or not _number(value.get("radius")): return false
		for key: String in ["name", "color", "message"]:
			if not value.get(key) is String: return false
	for value: Variant in record.navigation.values():
		if not value is Dictionary: return false
		if not _point_valid(value.get("pan")) or not _number(value.get("zoom")) or not _number(value.get("active")): return false
		for key: String in ["markers", "discovered", "fades"]:
			if not value.get(key) is Array or value[key].size() > 4096: return false
		for pin: Variant in value.markers:
			if not _point_valid(pin): return false
		for identity: Variant in value.discovered:
			if not identity is String: return false
		for fade: Variant in value.fades:
			if not _number(fade): return false
		var floors: Variant = value.get("floors", [])
		if not floors is Array or floors.size() > 8: return false
		for floor_value: Variant in floors:
			if not _number(floor_value): return false
	return true

static func _number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and absf(float(value)) <= 2000000000.0

static func _point_valid(value: Variant) -> bool:
	return value is Array and value.size() == 2 and _number(value[0]) and _number(value[1])

static func _placement_valid(value: Dictionary) -> bool:
	return value.get("scene") is String and _point_valid(value.get("position")) and _number(value.get("elevation"))
