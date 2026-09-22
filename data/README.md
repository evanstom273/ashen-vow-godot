# Inspector-editable game definitions

Open **game_catalog.tres** for an index of classes, weapons, enemies, bosses, spells and shrines. The same catalog is exposed as **Main > Game Data**. Expand any entry to edit its nested resources in Godot's Inspector.

## Existing scene assignments

| Scene / actor | Definition |
| --- | --- |
| Player | `classes/ashen_wanderer.tres` |
| Player sword | `weapons/wanderer_sword.tres` |
| Sentinel | `enemies/court_sentinel.tres` |
| Sentinel blade | `weapons/sentinel_blade.tres` |
| Both training dummies | `enemies/training_effigy.tres` |
| Shrine | `interactables/ashen_shrine.tres` |

Player exposes **Character Class** and an optional **Weapon Override**. Enemies, dummies and the shrine expose **Definition**. The scene assignments control what is spawned; the catalog is an authoring index, not a spawner or inventory.

Player health is controlled by `vitals/wanderer_vitals.tres`, not a Main scene override. Changes apply on the next game start/spawn. Stop and restart an existing debug session after editing definitions; live combat hot-reloading is not implemented.

## Current Souls-inspired balance

At starting attributes of 10 and zero damage negation:

| Value | Amount |
| --- | --- |
| Player health / stamina | 650 / 120 |
| Sword damage / stamina cost | 110 / 22 |
| Dodge cost / sprint drain | 24 / 18 per second |
| Stamina regeneration | 45 per second after 0.65 seconds |
| Sentinel health / damage | 560 / 145 |
| Training dummy health | 1,000 |
| Boss template health | 3,200 |
| Spell template magic damage / uses | 180 / 8 |
| Player / sentinel / boss poise | 30 / 60 / 150 |
| Sword / sentinel / spell poise damage | 30 / 45 / 20 |

This gives six unscaled sword hits to defeat the sentinel and five landed sentinel hits to defeat the player. Full stamina buys five sword attacks or five rolls without regeneration. Two consecutive sword hits can stagger the sentinel outside its protected strike. Bosses and spells remain authoring templates, not new encounters or abilities.

Default growth is +30 health per Vigour point, +3 stamina and +1.5 load capacity per Endurance point. Offensive attributes use the existing editable scaling coefficients. These are custom Souls-inspired values, not an exact recreation of another game's formulas. The values have not been playtested.

## What to edit

- **Attributes:** Vigour, Endurance, Strength, Dexterity, Intelligence, Faith and Arcane. All are stored in `AttributeStats` resources.
- **Vitals:** base health, stamina, equipment-load capacity, attribute growth, stamina recovery, poise, poise recovery, stagger duration and damage invulnerability.
- **Weapons:** identity/category, weight, attribute requirements, hand usability, catalyst schools, light/charged attacks and blade colour.
- **Attacks:** physical/magic/fire/lightning/holy damage, attribute scaling, stamina costs, poise damage, knockback, windup/active/recovery timing, reach, hit radius, arc, movement during attacks, lunge, active-frame interruption protection, hit-stop and feedback.
- **Defences:** percentage negation per damage channel; negative values mean vulnerability, 100 means immunity to that channel.
- **Movement:** walk/sprint speed and stamina drain, tap/hold threshold, roll distance/duration/cost/cooldown, invulnerable fractions, input buffering and target/interaction distances.
- **Enemy AI:** approach speed, detection/disengagement distance, attack trigger distance, recoil and sound keys. The current sentinel uses its weapon's light attack. Dummy health and automatic reset delay are resource-driven.
- **Shrine:** interaction text/range, restoration flags, enemy/dummy reset flags, combat lockout, pulse duration and light colour/energy.

Attack and roll pose timings, slash size/fade, target names, health percentages and stamina percentages follow the definitions. No scene-level health/speed exports override these values.

## Stat calculations

These are intentionally simple, editable prototype formulas inspired by the structure of Souls stats; they are not Elden Ring's exact formulas or soft-cap tables.

- Health = base health + (Vigour - reference level) × health growth, rounded and clamped to at least 1.
- Stamina and load capacity use Endurance. There is no separate Mind or focus resource.
- Attack power multiplier = 1 + the sum of each offensive attribute's positive points above the scaling reference × its coefficient.
- Each damage channel is reduced by its negation percentage; the summed, scaled damage is rounded once to an integer. Small scaling edits may not change a 1-damage attack until the rounded result crosses an integer boundary.
- Incoming poise damage subtracts from the actor's current poise. Reaching zero causes a stagger and replenishes poise. Active-frame interruption protection suppresses that stagger during the configured strike window. Poise otherwise regenerates after its delay.
- Weapon requirements currently prevent an attack if they are unmet. Set unused requirements to **0**, or leave the requirements resource empty for no requirements.
- Current HP, stamina, spell uses, utility charges, poise and copied attributes live on each actor. Damaging one enemy never mutates a shared `.tres`.

## Foundations, not additional gameplay

Boss and spell examples are **not placed in the courtyard**. A `BossDefinition` extends `EnemyDefinition`, adding phase resources, health thresholds, music and encounter metadata. `SpellDefinition` adds requirements, a cast attack, delivery metadata, projectile/effect references, speed, lifetime and slots.

Boss phase orchestration/fog gates, status buildup, heavy attacks, skills, guarding, critical attacks, equipment-load penalties and a full inventory/ownership system are not implemented. Shrine loadout preparation is runtime-connected: the player has two right-hand slots, two left-hand slots and three starting spell slots, selected from the temporary game-catalog pool. Spell charges, catalyst requirements, projectile delivery, self-delivery and shrine replenishment are runtime-connected. Weight and load capacity are available for future equipment logic; they do not yet change roll speed.

## Create another definition

1. Duplicate a `.tres`, or choose **New Resource** and select a named type such as `WeaponDefinition`, `ClassDefinition`, `EnemyDefinition`, `BossDefinition` or `SpellDefinition`.
2. Give it a unique ID and display name; assign its nested attribute/vital/attack resources.
3. **Duplicate nested resources too** (or use Make Unique and Save As) when tuning an independent variant. Copying a weapon does not automatically copy its external attack/damage files. Shared resources are useful when changes should affect multiple definitions.
4. Assign the definition to a compatible scene node. Add it to the catalog for easy discovery.

Boss templates inherit the sentinel-compatible base fields, but assigning one to the sentinel does not implement its phase metadata. New classes choose starting stats, vitals, movement and a weapon; there is no class-selection screen yet.

## Playable spell replacements

The prepared loadout and catalog now use Star Shard (Sorcery projectile), Cinder Lance (Incantation projectile), Vow Spear (Arcane projectile), Ember Wave (Arcane area blast), and Mending Light (Arcane self-heal). The deleted four spell templates are not required.

Cycle Q/R to a catalyst, C to a spell, then press F or click the catalyst hand. Pilgrim Wand casts every school; Court Staff supports Sorcery/Arcane; Ashen Seal supports Incantation/Arcane. Casts release once after their windup, independently of melee collision. Projectiles travel toward the mouse or locked target, hit enemies, stop at world geometry, and expire. Spell uses are actor-local and replenish at shrines.

Changed for this spell repair: `scripts/player.gd`, `scripts/spell_projectile.gd`, `scripts/resources/spell_definition.gd`, `data/loadout_spells.tres`, `data/game_catalog.tres`, and this document. Added `scripts/spell_burst.gd` and the five named resources under `data/spells/`. The existing `scenes/spell_projectile.tscn` is reused. Optional custom `cast_effect` and `memory_slots` remain data-only.

No tests or Godot runs were performed for this resource migration or spell repair, as requested. Spawning, collisions, damage, self-healing, catalyst input, and shrine replenishment still require runtime verification.


## Shrine loadout preparation

Resting at the Ashen Shrine now opens a staged loadout editor after the normal restore/reset sequence.

- Right hand starts with 2 equipped slots.
- Left hand starts with 2 equipped slots.
- Spells start with 3 prepared slots.
- Empty slots are valid and are skipped by gameplay cycling.
- Changes are staged until **Apply & Return**; **Discard** restores the live loadout unchanged.
- The temporary available pool comes from `game_catalog.tres`. This is intentionally separate from the equipped runtime arrays so a future ownership/inventory system can replace the catalog pool without redesigning the shrine UI.
- `WeaponLoadoutDefinition.max_slots` owns hand capacity.
- `SpellLoadoutDefinition.base_slots` owns the starting spell capacity. The player stores `spell_slot_bonus` separately, and `get_spell_slot_capacity()` combines it with the base capacity up to the resource maximum. Future memory-stone-equivalent progression should increase that player-owned bonus rather than mutating the shared class/loadout resource.
