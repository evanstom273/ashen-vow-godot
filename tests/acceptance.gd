extends Node
## Opt-in rebuild data regressions. Authored, NOT run during implementation.
## Does not instantiate actors, change the active character, or write user save files.
var failures: int = 0

func _ready() -> void:
	if "--rebuild-tests" not in OS.get_cmdline_user_args() and "--foundation-tests" not in OS.get_cmdline_user_args():
		push_warning("Acceptance is opt-in. Read docs/VERIFICATION.txt before running it.")
		return
	call_deferred("_run")

func check(condition: bool, label: String) -> void:
	if condition: print("PASS: ", label)
	else:
		failures += 1
		push_error("FAIL: " + label)

func _run() -> void:
	var catalogue := load("res://data/game_catalog.tres") as GameDataCatalog
	var issues: Array[String] = ContentAudit.inspect(catalogue)
	for issue: String in issues: push_error(issue)
	check(issues.is_empty(), "Catalogue authoring contracts")
	check(DamageProfile.new().total() == 0, "New damage profiles have no hidden physical component")
	check(not HitResult.reject(&"invulnerable").accepted, "Rejected hit is explicit")
	check(HitResult.accept(17).damage == 17, "Accepted hit carries actual damage")
	var sword := load("res://data/weapons/wanderer_sword.tres") as WeaponDefinition
	check(sword.light_attack.charge_threshold > 0, "Light candidate has a valid threshold")
	check(sword.charged_attack.stamina_cost > 0, "Charged sword does not inherit free enemy action")
	var fire := load("res://data/attacks/blackflame.tres") as AttackDefinition
	var stats := AttributeStats.new()
	stats.arcane = 10
	check(is_equal_approx(fire.max_health_drain.total_fraction(stats), 0.02), "Blackflame low fraction")
	check(is_equal_approx(fire.max_health_drain.lifetime(stats), 0.75), "Blackflame low duration")
	stats.arcane = 60
	check(is_equal_approx(fire.max_health_drain.total_fraction(stats), 0.05), "Blackflame capped fraction")
	check(is_equal_approx(fire.max_health_drain.lifetime(stats), 1.25), "Blackflame capped duration")
	stats.arcane = 99
	check(is_equal_approx(fire.max_health_drain.total_fraction(stats), 0.05), "No benefit past Arcane 60")
	check(fire.damage.fire > 0, "Separate ordinary fire damage remains")
	var state := CharacterState.new()
	state.class_id = &"ashen_wanderer"
	state.checkpoint = {"scene": state.scene, "position": CharacterState.point(Vector2.ZERO), "elevation": 0}
	var first: EquipmentInstance = state.add_equipment(sword)
	var second: EquipmentInstance = state.add_equipment(sword)
	state.right_slots.append(first.id)
	state.left_slots.append(second.id)
	state.currency = 123
	state.spell_uses["star_shard"] = 7
	state.utility_pool["healing_flask"] = 1
	var encoded: Variant = JSON.parse_string(JSON.stringify(state.to_record()))
	check(encoded is Dictionary and CharacterState.valid_record(encoded), "JSON schema round trip")
	if encoded is Dictionary and CharacterState.valid_record(encoded):
		var restored := CharacterState.from_record(encoded)
		check(restored.currency == 123 and int(restored.spell_uses.star_shard) == 7, "Currency and uses restored in memory")
		check(restored.right_slots[0] != restored.left_slots[0], "Two weapon copies retain distinct owned IDs")
		check(int(restored.utility_pool.get("healing_flask", -1)) == 1, "Unequipped utility charges survive the record")
		encoded.selected = ["not a number"]
		check(not CharacterState.valid_record(encoded), "Malformed typed boundary rejected")
	var movement := load("res://data/movement/player_movement.tres") as MovementDefinition
	check(is_equal_approx(movement.walk_speed, 512) and is_equal_approx(movement.walk_speed * movement.sprint_multiplier, 768), "Human speed contract")
	var fixed_drop := CurrencyDropDefinition.new()
	fixed_drop.minimum_amount = 12
	fixed_drop.maximum_amount = 12
	check(fixed_drop.roll_amount() == 12, "Equal min/max currency range")
	var wand := load("res://data/weapons/pilgrim_wand.tres") as WeaponDefinition
	check(wand.basic_spell != null and wand.basic_spell.is_basic() and wand.basic_spell.starting_charges() == -1, "Catalyst basic is an unlimited virtual entry")
	check(not (load("res://data/spells/star_shard.tres") as SpellDefinition).is_basic(), "Prepared named spells remain finite")
	var original_damage: int = sword.light_attack.health_damage(stats)
	var upgraded := sword.light_attack.duplicate(true) as AttackDefinition
	upgraded.upgrade_multiplier = 1.8
	check(upgraded.health_damage(stats) >= original_damage and sword.light_attack.upgrade_multiplier == 1.0, "Upgrade multiplier is per-hit, not shared")
	upgraded.resolved_health_damage = 27
	check(upgraded.health_damage(stats) == 27, "Percentage-health exact payload is not upgraded")
	for path: String in ["res://data/statuses/poison.tres", "res://data/statuses/bleed.tres", "res://data/statuses/frost.tres"]:
		var status := load(path) as StatusDefinition
		check(status != null and status.threshold > 0 and status.icon != null, "Status authoring: " + path.get_file())
	var malformed: Dictionary = state.to_record()
	malformed.attributes = malformed.attributes.duplicate(true)
	malformed.attributes.arcane = 10.5
	check(not CharacterState.valid_record(malformed), "Fractional attributes rejected at save boundary")
	check(GameSettings._valid_settings({"bindings": {"cast_spell": [{"kind": "key", "code": 70}]}}), "Valid typed rebind record")
	check(not GameSettings._valid_settings({"bindings": {"cast_spell": [{"kind": "axis", "code": 0, "sign": 0}]}}), "Neutral controller binding rejected")
	var climate := load("res://data/environment/climate.tres") as ClimateDefinition
	check(is_equal_approx(climate.day_seconds, 1440.0), "Pausable authored 24-minute day")
	var invalid_effect := SpellEffectDefinition.new()
	invalid_effect.interval = 0.0
	check(not invalid_effect.validation_error().is_empty(), "Malformed periodic interval cannot enter a tick loop")
	print("REBUILD DATA CHECKS COMPLETE: ", failures, " failures. Gameplay, visuals and performance are NOT covered.")
	get_tree().quit(failures)
