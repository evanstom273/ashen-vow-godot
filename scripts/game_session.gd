extends Node
## Persistent ownership lives here, not in a scene or a shared definition.
signal save_completed(success: bool)
signal character_changed
const ALLOWED_SCENES: Array[String] = ["res://scenes/forest_camp.tscn", "res://scenes/main.tscn"]
var character: CharacterState
var actor: PlayerController
var slot: int = 1
var catalogue: GameDataCatalog
var saving_enabled: bool = true
var _save_clock: float = 0.0
var _ground_clock: float = 0.0
var _recovery_node: WeakRef
var _save_queued: bool = false
var development_session: bool = false
var _preserved_character: CharacterState
var _preserved_saving: bool = true

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	catalogue = load("res://data/game_catalog.tres") as GameDataCatalog
	get_tree().auto_accept_quit = false
	var selection: Dictionary = SaveStore.read_document("user://session.json", _valid_selection)
	slot = clampi(int(selection.get("active_slot", 1)), 1, 3)
	var record: Dictionary = SaveStore.read_document(slot_path(slot), _valid_character_record)
	if not record.is_empty() and CharacterState.valid_record(record): character = CharacterState.from_record(record)
	elif not record.is_empty(): saving_enabled = false
	elif not SaveStore.last_error.is_empty(): saving_enabled = false

func slot_path(index: int) -> String:
	return "user://characters/slot_%d.json" % clampi(index, 1, 3)

static func _valid_selection(record: Dictionary) -> bool:
	var value: Variant = record.get("active_slot")
	return (value is int or value is float) and float(value) in [1.0, 2.0, 3.0]

func _resume_scene() -> String:
	var destination: String = String(character.checkpoint.get("scene", character.scene)) if character.needs_respawn else character.scene
	return destination if destination in ALLOWED_SCENES else ALLOWED_SCENES[0]

func _valid_character_record(record: Dictionary) -> bool:
	if not CharacterState.valid_record(record): return false
	if record.scene not in ALLOWED_SCENES or record.checkpoint.scene not in ALLOWED_SCENES: return false
	var class_definition := definition(&"classes", StringName(record["class"])) as ClassDefinition
	if class_definition == null: return false
	var earned: int = 0
	for key: String in CharacterState.ATTRIBUTES:
		var minimum: int = int(class_definition.attributes.get(key))
		if int(record.attributes[key]) < minimum or int(record.attributes[key]) > CharacterProgression.RULES.attribute_cap: return false
		earned += int(record.attributes[key]) - minimum
	if earned != int(record.level) - class_definition.starting_level: return false
	var equipped: Array[String] = []
	var owned_definitions: Dictionary = {}
	for item: Dictionary in record.equipment:
		var weapon_definition := definition(&"weapons", StringName(item.definition)) as WeaponDefinition
		if weapon_definition == null or int(item.upgrade) > CharacterProgression.RULES.maximum_upgrade: return false
		owned_definitions[item.id] = weapon_definition
	for hand: String in ["right", "left"]:
		var hand_loadout: WeaponLoadoutDefinition = class_definition.right_hand_loadout if hand == "right" else class_definition.left_hand_loadout
		if record[hand].size() > (hand_loadout.max_slots if hand_loadout != null else 2): return false
		for identity: String in record[hand]:
			if identity.is_empty(): continue
			if equipped.has(identity): return false
			var equipped_weapon: WeaponDefinition = owned_definitions[identity]
			if hand == "right" and not equipped_weapon.usable_in_right_hand: return false
			if hand == "left" and not equipped_weapon.usable_in_left_hand: return false
			equipped.append(identity)
	for field: String in ["spells", "known_spells", "utilities", "known_utilities"]:
		var collection: StringName = &"spells" if field.ends_with("spells") else &"utilities"
		for identity: String in record[field]:
			if not identity.is_empty() and definition(collection, StringName(identity)) == null: return false
	var memory: int = 0
	for identity: String in record.spells:
		var spell := definition(&"spells", StringName(identity)) as SpellDefinition
		if spell != null:
			if spell.is_basic() or not record.known_spells.has(identity): return false
			memory += spell.memory_slots
	for identity: String in record.utilities:
		if not identity.is_empty() and not record.known_utilities.has(identity): return false
	var loadout: SpellLoadoutDefinition = class_definition.spell_loadout
	var capacity: int = clampi(loadout.base_slots + int(record.memory_bonus), 1, loadout.maximum_slots) if loadout != null else 3 + int(record.memory_bonus)
	if memory > capacity: return false
	return true

func attach_player(player: PlayerController) -> void:
	if not is_instance_valid(player) or not player.is_inside_tree(): return
	if not is_instance_valid(get_tree().current_scene): return
	if bool(get_tree().current_scene.get_meta("development_sandbox", false)) and not development_session:
		development_session = true
		_preserved_character = character
		_preserved_saving = saving_enabled
		character = null
		saving_enabled = false
	if not development_session and character != null and get_tree().current_scene.scene_file_path != _resume_scene():
		actor = null
		get_tree().call_deferred("change_scene_to_file", _resume_scene())
		return
	actor = player
	# Physics registration must finish before validating a restored landing point.
	actor.set_physics_process(false)
	actor.set_process_unhandled_input(false)
	await get_tree().physics_frame
	if not is_instance_valid(player) or not player.is_inside_tree() or player != actor: return
	var starting_character: bool = character == null
	if character == null:
		character = CharacterState.new()
		character.class_id = player.character_class.id
		character.level = player.character_class.starting_level
		for hand: StringName in [&"right", &"left"]:
			var slots: Array[String] = character.right_slots if hand == &"right" else character.left_slots
			var weapons: Array[WeaponDefinition] = player.right_hand_weapons if hand == &"right" else player.left_hand_weapons
			for starting_weapon: WeaponDefinition in weapons:
				slots.append(character.add_equipment(starting_weapon).id if starting_weapon != null else "")
		for retained: WeaponDefinition in player.character_class.starting_owned_weapons:
			if retained != null: character.add_equipment(retained)
		for spell: SpellDefinition in player.spells:
			if spell != null and not spell.is_basic() and not character.known_spells.has(String(spell.id)): character.known_spells.append(String(spell.id))
		for utility: UtilityDefinition in player.utilities:
			if utility != null and not character.known_utilities.has(String(utility.id)): character.known_utilities.append(String(utility.id))
		character.last_ground = actor.global_position
		character.ground_elevation = Elevation.level(actor)
		character.checkpoint = {"id": "origin", "scene": get_tree().current_scene.scene_file_path, "position": CharacterState.point(actor.global_position), "elevation": Elevation.level(actor)}
	else:
		if character.needs_respawn: reset_encounter_flags()
		if not _restore_player():
			saving_enabled = false
			actor.show_message("No safe restore position. Existing save preserved; fix the spawn or choose another slot.", 30.0)
			return
	if not _ground_valid(actor.global_position, Elevation.level(actor)):
		saving_enabled = false
		actor.show_message("The authored player spawn is obstructed. Session remains locked; save preserved.", 30.0)
		return
	_spawn_recovery()
	_spawn_currency_pickups()
	for enemy: Node in get_tree().get_nodes_in_group("enemy"):
		if enemy.has_method("restore_persistent_state"): enemy.restore_persistent_state()
	actor._session_ready = true
	actor.set_physics_process(true)
	actor.set_process_unhandled_input(true)
	if starting_character: capture()
	if development_session: grant_development_catalogue()
	character_changed.emit()
	if saving_enabled: save_now()
	elif development_session: actor.show_message("Combat lab — disposable character; saves disabled", 6.0)
	else: actor.show_message("Save unavailable; existing files have been preserved", 6.0)

func leave_development_session() -> void:
	if not development_session: return
	character = _preserved_character
	saving_enabled = _preserved_saving
	_preserved_character = null
	development_session = false
	actor = null
	_save_queued = false
	_save_clock = 0.0

func weapon(identity: String) -> WeaponDefinition:
	var owned: EquipmentInstance = character.find_equipment(identity) if character != null else null
	return definition(&"weapons", owned.definition_id) as WeaponDefinition if owned != null else null

func definition(collection: StringName, identity: StringName) -> Resource:
	if catalogue == null or identity.is_empty(): return null
	for resource: Resource in catalogue.get(collection):
		if resource != null and resource.get("id") == identity: return resource
	return null

func capture() -> void:
	if not is_instance_valid(actor) or not actor.is_inside_tree() or actor.is_queued_for_deletion() or character == null: return
	if not actor._session_ready: return
	if not is_instance_valid(get_tree().current_scene): return
	character.attributes = actor.attributes.duplicate(true) as AttributeStats
	character.climate = WorldClimate.snapshot()
	character.health = actor.health
	character.stamina = actor.stamina
	character.currency = actor.current_currency
	character.memory_bonus = actor.spell_slot_bonus
	character.position = actor.global_position
	character.elevation = Elevation.level(actor)
	character.scene = get_tree().current_scene.scene_file_path
	_sync_equipment()
	character.prepared_spells.clear()
	for key: Variant in actor._spell_use_pool: character.spell_uses[String(key)] = actor._spell_use_pool[key]
	for index in actor.spells.size():
		var spell: SpellDefinition = actor.spells[index]
		if spell != null and spell.is_basic(): continue
		character.prepared_spells.append(String(spell.id) if spell != null else "")
		if spell != null: character.spell_uses[String(spell.id)] = actor.spell_charges[index]
	character.prepared_utilities.clear()
	for utility: UtilityDefinition in actor.utilities: character.prepared_utilities.append(String(utility.id) if utility != null else "")
	character.utility_uses.assign(actor.utility_charges)
	for index in actor.utilities.size():
		if actor.utilities[index] != null: character.utility_pool[String(actor.utilities[index].id)] = actor.utility_charges[index]
	character.selected.assign([actor.right_hand_index, actor.left_hand_index, actor.spell_index, actor.utility_index])
	var navigation: Node = get_tree().get_first_node_in_group("world_navigation")
	if navigation != null and navigation.has_method("save_navigation"):
		character.navigation[character.scene] = navigation.save_navigation()

func _sync_equipment() -> void:
	var used: Array[String] = []
	for hand: StringName in [&"right", &"left"]:
		var slots: Array[String] = character.right_slots if hand == &"right" else character.left_slots
		var weapons: Array[WeaponDefinition] = actor.right_hand_weapons if hand == &"right" else actor.left_hand_weapons
		var next: Array[String] = []
		for index in weapons.size():
			var selected_weapon: WeaponDefinition = weapons[index]
			if selected_weapon == null:
				next.append("")
				continue
			var match_item: EquipmentInstance = character.find_equipment(slots[index]) if index < slots.size() else null
			if match_item == null or match_item.definition_id != selected_weapon.id or used.has(match_item.id):
				match_item = null
				for owned: EquipmentInstance in character.equipment:
					if owned.definition_id == selected_weapon.id and not used.has(owned.id):
						match_item = owned
						break
			if match_item == null:
				# Definitions alone never confer ownership.
				next.append("")
				continue
			next.append(match_item.id)
			used.append(match_item.id)
		slots.assign(next)

func _restore_player() -> bool:
	var saved_class := definition(&"classes", character.class_id) as ClassDefinition
	if saved_class == null: return false
	if actor.character_class != saved_class:
		actor.character_class = saved_class
		actor.apply_definitions()
	actor.attributes = character.attributes.duplicate(true) as AttributeStats
	actor.spell_slot_bonus = character.memory_bonus
	actor.max_health = actor.vitals.max_health(actor.attributes)
	actor.max_stamina = actor.vitals.max_stamina(actor.attributes)
	actor.max_equip_load = actor.vitals.max_load(actor.attributes)
	for hand: StringName in [&"right", &"left"]:
		var items: Array[WeaponDefinition] = []
		for identity: String in (character.right_slots if hand == &"right" else character.left_slots): items.append(weapon(identity))
		actor.set_weapon_loadout(hand, items)
	var spells: Array[SpellDefinition] = []
	for identity: String in character.prepared_spells: spells.append(definition(&"spells", StringName(identity)) as SpellDefinition)
	actor.set_spell_loadout(spells)
	actor._spell_use_pool.clear()
	for identity: Variant in character.spell_uses: actor._spell_use_pool[StringName(identity)] = int(character.spell_uses[identity])
	for index in actor.spells.size():
		var spell: SpellDefinition = actor.spells[index]
		actor.spell_charges[index] = (-1 if spell.is_basic() else clampi(int(character.spell_uses.get(String(spell.id), spell.starting_charges())), 0, spell.maximum_charges)) if spell != null else 0
	actor.utilities.clear()
	actor.utility_charges.clear()
	for index in character.prepared_utilities.size():
		var utility := definition(&"utilities", StringName(character.prepared_utilities[index])) as UtilityDefinition
		actor.utilities.append(utility)
		actor.utility_charges.append(clampi(character.utility_uses[index], 0, utility.maximum_charges) if utility != null and index < character.utility_uses.size() else 0)
	actor.right_hand_index = clampi(character.selected[0], 0, maxi(0, actor.right_hand_weapons.size() - 1))
	actor.left_hand_index = clampi(character.selected[1], 0, maxi(0, actor.left_hand_weapons.size() - 1))
	actor.spell_index = clampi(character.selected[2], 0, maxi(0, actor.spells.size() - 1))
	actor.utility_index = clampi(character.selected[3], 0, maxi(0, actor.utilities.size() - 1))
	PlayerSpellbook.refresh(actor)
	actor.equipped_weapon = actor.get_selected_weapon(&"right")
	actor.current_currency = character.currency
	actor.health = clampi(character.health, 1, actor.max_health)
	actor.stamina = clampf(character.stamina, 0.0, actor.max_stamina)
	var desired: Vector2 = character.last_ground
	var floor_level: int = character.ground_elevation
	if character.needs_respawn:
		desired = CharacterState.vector(character.checkpoint.get("position"), actor.global_position)
		floor_level = int(character.checkpoint.get("elevation", 0))
	elif character.scene == get_tree().current_scene.scene_file_path:
		desired = character.position
		floor_level = character.elevation
	if _ground_valid(desired, floor_level):
		actor.global_position = desired
		Elevation.set_level(actor, floor_level)
	elif character.scene == get_tree().current_scene.scene_file_path and _ground_valid(character.last_ground, character.ground_elevation):
		actor.global_position = character.last_ground
		Elevation.set_level(actor, character.ground_elevation)
	elif not _ground_valid(actor.global_position, Elevation.level(actor)):
		return false
	if character.needs_respawn:
		actor.restore()
		character.needs_respawn = false
	actor.velocity = Vector2.ZERO
	actor.camera.reset_smoothing()
	for hand: StringName in [&"right", &"left", &"spell", &"utility"]: actor.loadout_changed.emit(hand, 0)
	actor.health_changed.emit(actor.health, actor.max_health)
	actor.currency_changed.emit(actor.current_currency)
	return true

func prepare_weapons(right: Array[String], left: Array[String]) -> bool:
	if not CharacterProgression.available(): return false
	var used: Array[String] = []
	for hand: StringName in [&"right", &"left"]:
		var ids: Array[String] = right if hand == &"right" else left
		if ids.size() > actor.get_weapon_slot_capacity(hand): return false
		for identity: String in ids:
			if identity.is_empty(): continue
			var selected: WeaponDefinition = weapon(identity)
			if selected == null or used.has(identity): return false
			if hand == &"right" and not selected.usable_in_right_hand: return false
			if hand == &"left" and not selected.usable_in_left_hand: return false
			used.append(identity)
	# Save tokens by owned identity before either hand is replaced.
	var tokens: Dictionary = {}
	var enchants: Dictionary = SpellEffects.of(actor).imbues.duplicate()
	for hand: StringName in [&"right", &"left"]:
		actor.weapon_token(hand)
		var previous: Array[String] = character.right_slots if hand == &"right" else character.left_slots
		for i in mini(previous.size(), actor._weapon_tokens[hand].size()):
			if not previous[i].is_empty(): tokens[previous[i]] = actor._weapon_tokens[hand][i]
	character.right_slots.assign(right)
	character.left_slots.assign(left)
	var retained_tokens: Array[int] = []
	for hand: StringName in [&"right", &"left"]:
		var ids: Array[String] = right if hand == &"right" else left
		var definitions: Array[WeaponDefinition] = []
		var next_tokens: Array[int] = []
		for identity: String in ids:
			definitions.append(weapon(identity))
			var token: int = int(tokens.get(identity, 0))
			if token == 0:
				token = actor._next_weapon_token
				actor._next_weapon_token += 1
			next_tokens.append(token)
			retained_tokens.append(token)
		actor.set_weapon_loadout(hand, definitions)
		while next_tokens.size() < actor.get_weapon_slot_capacity(hand):
			next_tokens.append(actor._next_weapon_token)
			actor._next_weapon_token += 1
		actor._weapon_tokens[hand] = next_tokens
	SpellEffects.of(actor).imbues.clear()
	for token: int in retained_tokens:
		if enchants.has(token): SpellEffects.of(actor).imbues[token] = enchants[token]
	return true

func prepare_utilities(ids: Array[String]) -> bool:
	if not CharacterProgression.available() or ids.size() > 4: return false
	var definitions: Array[UtilityDefinition] = []
	var uses: Dictionary = character.utility_pool.duplicate()
	for i in actor.utilities.size():
		if actor.utilities[i] != null: uses[String(actor.utilities[i].id)] = actor.utility_charges[i]
	character.utility_pool = uses.duplicate()
	var unique: Array[String] = []
	for identity: String in ids:
		if identity.is_empty():
			definitions.append(null)
			continue
		if not character.known_utilities.has(identity) or unique.has(identity): return false
		var utility := definition(&"utilities", StringName(identity)) as UtilityDefinition
		if utility == null: return false
		definitions.append(utility)
		unique.append(identity)
	actor.utilities.assign(definitions)
	actor.utility_charges.clear()
	for utility: UtilityDefinition in definitions:
		actor.utility_charges.append(int(uses.get(String(utility.id), utility.maximum_charges)) if utility != null else 0)
	actor.utility_index = 0
	actor.loadout_changed.emit(&"utility", 0)
	save_now()
	return true

func travel(identity: String) -> String:
	if not CharacterProgression.available(): return "Travel requires a safe human state outside combat."
	if not character.attuned_shrines.has(identity): return "Attune this shrine before travelling."
	var destination: Dictionary = character.attuned_shrines[identity]
	if destination.scene not in ALLOWED_SCENES: return "Destination is unavailable."
	if destination.scene == get_tree().current_scene.scene_file_path and not _ground_valid(CharacterState.vector(destination.position), int(destination.elevation)):
		return "The shrine landing is obstructed."
	capture()
	var previous_checkpoint: Dictionary = character.checkpoint.duplicate(true)
	var previous_respawn: bool = character.needs_respawn
	character.checkpoint = destination.duplicate(true)
	character.needs_respawn = true
	if not save_now():
		character.checkpoint = previous_checkpoint
		character.needs_respawn = previous_respawn
		return "Could not save before travel."
	UIFlow.clear()
	get_tree().call_deferred("change_scene_to_file", String(destination.scene))
	return "Travelling to " + String(destination.get("name", "shrine"))

func _ground_valid(at: Vector2, floor_level: int) -> bool:
	if not is_instance_valid(actor): return false
	var navigation := get_tree().current_scene.get_node_or_null("SpellNavigation") as SpellNavigation
	if navigation != null and not navigation.bounds.has_point(at): return false
	if not Elevation.of(actor).support_at(at, floor_level, Elevation.body_radius(actor)): return false
	for child: Node in actor.get_children():
		if not child is CollisionShape2D or child.disabled or child.shape == null: continue
		var query := PhysicsShapeQueryParameters2D.new()
		query.shape = child.shape
		query.transform = child.global_transform
		query.transform.origin += at - actor.global_position
		query.collision_mask = 51
		query.collide_with_areas = true
		query.exclude = [actor.get_rid()]
		if not Elevation.shapes(actor, query, floor_level, 1).is_empty(): return false
	return true

func record_death() -> void:
	if character == null or not is_instance_valid(actor): return
	capture()
	character.needs_respawn = true
	if actor.character_class.lose_currency_on_death:
		_clear_recovery_node()
		# Replacement is unconditional: dying with zero Embers loses the old drop too.
		character.recovery = {}
		if actor.current_currency > 0:
			character.recovery = {"amount": actor.current_currency, "scene": character.scene,
				"position": CharacterState.point(character.last_ground), "elevation": character.ground_elevation}
		actor.current_currency = 0
		character.currency = 0
		actor.currency_changed.emit(0)
		_spawn_recovery()
	save_now()

func recover(drop: CurrencyDrop) -> void:
	if character == null or not drop.is_player_recovery or not is_instance_valid(actor) or actor.health <= 0: return
	var amount: int = int(character.recovery.get("amount", 0))
	drop.amount = 0
	character.recovery.clear()
	actor.add_currency(amount, "Embers recovered")
	_clear_recovery_node()
	save_now()

func register_currency_pickup(drop: CurrencyDrop) -> void:
	if character == null or not is_instance_valid(drop) or drop.is_queued_for_deletion() or drop.is_player_recovery: return
	if drop.reward_id.is_empty():
		drop.reward_id = "reward_%d" % character.next_reward_id
		character.next_reward_id += 1
	character.world_pickups[drop.reward_id] = {"scene": get_tree().current_scene.scene_file_path,
		"position": CharacterState.point(drop.global_position), "elevation": Elevation.level(drop),
		"amount": drop.amount, "name": drop.definition.display_name, "color": drop.definition.color.to_html(),
		"radius": drop.definition.pickup_radius, "message": drop.definition.recovery_message}
	queue_save()

func collect_currency_pickup(identity: String) -> void:
	if character == null: return
	character.world_pickups.erase(identity)
	queue_save()

func _spawn_currency_pickups() -> void:
	for identity: String in character.world_pickups:
		var record: Dictionary = character.world_pickups[identity]
		if record.get("scene", "") != get_tree().current_scene.scene_file_path: continue
		var exists: bool = false
		for existing: Node in get_tree().get_nodes_in_group("currency_drop"):
			if existing is CurrencyDrop and existing.reward_id == identity: exists = true
		if exists: continue
		var drop := preload("res://scenes/currency_drop.tscn").instantiate() as CurrencyDrop
		drop.reward_id = identity
		drop.amount = maxi(0, int(record.get("amount", 0)))
		drop.definition = CurrencyDropDefinition.new()
		drop.definition.delivery_mode = CurrencyDropDefinition.DeliveryMode.PICKUP
		drop.definition.display_name = String(record.get("name", "Embers"))
		drop.definition.color = Color.from_string(String(record.get("color", "e6b968")), Color("e6b968"))
		drop.definition.pickup_radius = clampf(float(record.get("radius", 192.0)), 1.0, 2000.0)
		drop.definition.recovery_message = String(record.get("message", "Embers recovered"))
		drop.set_meta(&"elevation_level", int(record.get("elevation", 0)))
		WorldScale.attach_art(drop, actor.get_parent(), CharacterState.vector(record.get("position")), 1.0)

func record_enemy_death(identity: StringName) -> void:
	if character == null or identity.is_empty(): return
	character.world_flags["defeated:" + String(identity)] = true
	queue_save()

func enemy_defeated(identity: StringName) -> bool:
	return character != null and not identity.is_empty() and bool(character.world_flags.get("defeated:" + String(identity), false))

func reset_encounter_flags() -> void:
	if character == null: return
	for key: Variant in character.world_flags.keys():
		if String(key).begins_with("defeated:"): character.world_flags.erase(key)

func _clear_recovery_node() -> void:
	var previous: Variant = _recovery_node.get_ref() if _recovery_node != null else null
	if is_instance_valid(previous): previous.queue_free()
	_recovery_node = null

func _spawn_recovery() -> void:
	_clear_recovery_node()
	if character.recovery.is_empty() or character.recovery.get("scene", "") != get_tree().current_scene.scene_file_path: return
	var drop := preload("res://scenes/currency_drop.tscn").instantiate() as CurrencyDrop
	drop.is_player_recovery = true
	drop.amount = int(character.recovery.get("amount", 0))
	drop.definition = actor.character_class.death_drop
	drop.set_meta(&"elevation_level", int(character.recovery.get("elevation", 0)))
	WorldScale.attach_art(drop, actor.get_parent(), CharacterState.vector(character.recovery.get("position")), 1.0)
	_recovery_node = weakref(drop)

func attune(shrine: AshenShrine) -> void:
	if character == null or not is_instance_valid(actor): return
	character.checkpoint = {"id": String(shrine.checkpoint_id), "name": shrine.get_display_name(),
		"scene": get_tree().current_scene.scene_file_path, "position": CharacterState.point(actor.global_position), "elevation": Elevation.level(actor)}
	character.attuned_shrines[String(shrine.checkpoint_id)] = character.checkpoint.duplicate(true)
	character.last_ground = actor.global_position
	character.ground_elevation = Elevation.level(actor)
	save_now()

func respawn() -> void:
	if character == null or not is_instance_valid(actor): return
	if actor.health > 0 and (actor.in_combat() or actor.state != PlayerController.PlayerState.NORMAL or actor.transformation.phase != PlayerTransformation.Phase.HUMAN):
		actor.show_message("Return requires clear ground and no active combat or action", 3.0)
		return
	capture()
	character.needs_respawn = true
	save_now()
	UIFlow.clear()
	var destination: String = String(character.checkpoint.get("scene", character.scene))
	if development_session:
		get_tree().change_scene_to_file("res://scenes/combat_lab.tscn")
		return
	if destination not in ALLOWED_SCENES: destination = ALLOWED_SCENES[0]
	get_tree().change_scene_to_file(destination)

func load_slot(index: int) -> bool:
	if development_session:
		if is_instance_valid(actor): actor.show_message("Leave the combat lab through Title before loading a character.", 4.0)
		return false
	if is_instance_valid(actor) and actor._session_ready and not save_now() and saving_enabled: return false
	var record: Dictionary = SaveStore.read_document(slot_path(index), _valid_character_record)
	if record.is_empty() or not CharacterState.valid_record(record):
		if is_instance_valid(actor): actor.show_message("No readable character in that slot", 3.0)
		return false
	character = CharacterState.from_record(record)
	slot = clampi(index, 1, 3)
	saving_enabled = true
	actor = null
	UIFlow.clear()
	get_tree().change_scene_to_file(_resume_scene())
	return true

func new_character() -> bool:
	if development_session:
		if is_instance_valid(actor): actor.show_message("Leave the combat lab through Title before creating a character.", 4.0)
		return false
	var free_slot: int = 0
	for index in range(1, 4):
		if not FileAccess.file_exists(slot_path(index)) and not FileAccess.file_exists(slot_path(index) + ".bak"):
			free_slot = index
			break
	if free_slot == 0:
		if is_instance_valid(actor): actor.show_message("All three character slots are occupied", 3.0)
		return false
	if character != null and saving_enabled and not save_now(): return false
	slot = free_slot
	character = null
	actor = null
	saving_enabled = true
	UIFlow.clear()
	get_tree().change_scene_to_file(ALLOWED_SCENES[0])
	return true

func save_now() -> bool:
	_save_queued = false
	if not saving_enabled or character == null: return false
	capture()
	var success: bool = SaveStore.write_document(slot_path(slot), character.to_record(), _valid_character_record)
	if success: SaveStore.write_document("user://session.json", {"active_slot": slot}, _valid_selection)
	_save_clock = 0.0
	if not success and is_instance_valid(actor): actor.show_message(SaveStore.last_error, 5.0)
	save_completed.emit(success)
	return success

func queue_save() -> void:
	if _save_queued: return
	_save_queued = true
	call_deferred("_flush_queued_save")

func _flush_queued_save() -> void:
	if _save_queued: save_now()

func reward_claimed(identity: StringName) -> bool:
	return character != null and bool(character.world_flags.get("reward:" + String(identity), false))

func grant_reward(identity: StringName, reward: RewardDefinition) -> bool:
	if character == null or not is_instance_valid(actor) or reward == null or identity.is_empty() or reward_claimed(identity): return false
	character.world_flags["reward:" + String(identity)] = true
	for item: WeaponDefinition in reward.weapons:
		if item != null: character.add_equipment(item)
	for spell: SpellDefinition in reward.spells:
		if spell != null and not spell.is_basic() and not character.known_spells.has(String(spell.id)): character.known_spells.append(String(spell.id))
	for utility: UtilityDefinition in reward.utilities:
		if utility != null and not character.known_utilities.has(String(utility.id)): character.known_utilities.append(String(utility.id))
	for material: String in reward.materials:
		character.materials[material] = int(character.materials.get(material, 0)) + maxi(0, reward.materials[material])
	actor.spell_slot_bonus += reward.memory_bonus
	actor.add_currency(reward.embers)
	queue_save()
	return true

func grant_development_catalogue() -> void:
	if not OS.is_debug_build() or (not development_session and not bool(ProjectSettings.get_setting("debug/content/catalogue_mode", false))): return
	var reward := RewardDefinition.new()
	reward.weapons.assign(catalogue.weapons)
	reward.spells.assign(catalogue.spells)
	reward.utilities.assign(catalogue.utilities)
	reward.materials["ember_shard"] = 100
	grant_reward(&"development_catalogue", reward)

func _physics_process(delta: float) -> void:
	if not is_instance_valid(actor) or not actor._session_ready or character == null or actor.health <= 0: return
	_ground_clock += delta
	_save_clock += delta
	if _ground_clock >= 0.25:
		_ground_clock = 0.0
		if actor.transformation.phase == PlayerTransformation.Phase.HUMAN and _ground_valid(actor.global_position, Elevation.level(actor)):
			character.last_ground = actor.global_position
			character.ground_elevation = Elevation.level(actor)
	if _save_clock >= 30.0: save_now()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_now()
		GameSettings.flush()
		get_tree().quit()
