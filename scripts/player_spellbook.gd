class_name PlayerSpellbook
extends RefCounted
## Compatibility adapter: prepared entries precede virtual, catalyst-owned entries.
## Definitions never own remaining uses. Rebuilding never refills a finite spell.
static func prepared(actor: Node) -> Array[SpellDefinition]:
	var result: Array[SpellDefinition] = []
	for spell: SpellDefinition in actor.spells:
		if spell == null or not spell.is_basic(): result.append(spell)
	return result

static func remember(actor: Node) -> void:
	for index in mini(actor.spells.size(), actor.spell_charges.size()):
		var spell: SpellDefinition = actor.spells[index]
		if spell != null and not spell.is_basic(): actor._spell_use_pool[spell.id] = actor.spell_charges[index]

static func refresh(actor: Node) -> void:
	var selected: SpellDefinition = actor.get_selected_spell()
	remember(actor)
	var next: Array[SpellDefinition] = prepared(actor)
	var basics: Array[StringName] = []
	for hand: StringName in [&"right", &"left"]:
		var catalyst: WeaponDefinition = actor.get_selected_weapon(hand)
		if catalyst == null or not catalyst.is_spell_catalyst or catalyst.basic_spell == null: continue
		var basic: SpellDefinition = catalyst.basic_spell
		if not basic.is_basic() or basics.has(basic.id): continue
		basics.append(basic.id)
		next.append(basic)
	actor.spells.assign(next)
	actor.spell_charges.clear()
	for spell: SpellDefinition in next:
		var remaining: int = 0
		if spell != null:
			remaining = -1 if spell.is_basic() else clampi(int(actor._spell_use_pool.get(spell.id, spell.starting_charges())), 0, spell.maximum_charges)
		actor.spell_charges.append(remaining)
	actor.spell_index = next.find(selected) if selected != null and next.has(selected) else actor._first_filled_spell_index(next)
	actor.loadout_changed.emit(&"spell", actor.spell_index)
