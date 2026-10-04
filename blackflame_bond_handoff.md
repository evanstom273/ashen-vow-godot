# Blackflame Bond

New shrine-selectable Arcane tether; starting loadouts and Soul Thread unchanged.
Reusable attack asset: `data/attacks/blackflame.tres`. Assign it to a spell's
Delivery Definition > Attack (including projectile child attacks), or a weapon's
attack slot. To retain an existing attack's normal damage, copy the Blackflame
Max Health Drain subresource into that attack's same field. Make unique before
changing per-spell tuning. Cast costs/timing remain on the spell's Cast resource.
10 shrine-replenished uses, 20 stamina upfront, 0.3s windup/recovery, 320 range.
The tether channels for up to two seconds, independently of burn duration.
Existing release, interruption, death, pause, range and sight-break rules end
the tether. First contact applies one burn; keeping the link held does not
reapply or multiply damage. The accepted burn finishes even after severing.
All deliveries and melee apply an actor-owned burn after receiver acceptance;
it persists after the original delivery ends. Same effect ID refreshes instead
of stacking. It clears on target/source death, actor removal, and shrine reset.
Burn particles follow the target. Drain ticks cannot recursively apply burns.

## Curve and damage

Snapshot caster Arcane at cast acceptance and target maximum health at contact.
Let x = clamp((Arcane - 10) / 50, 0, 1), p = ln(1 + 2x) / ln(3).
Total fraction = 0.02 + 0.03p; duration = 0.75 + 0.5p seconds.
10 or less: 2% / 0.75s. 60 or more: 5% / 1.25s.
These are total percentages, not per-second damage rates.

Schedule uniform damage in 0.05s slices and flush the final partial interval.
Cumulative integer rounding keeps the full total within half a health point;
small health pools may have zero-damage slices. Defence and ordinary attack
scaling do not change the percentage. Existing receiver invulnerability remains
authoritative: rejected slices are lost, never banked or refunded. A burn already
applied to the target does not need continuing line of sight.
The shared attack now also deals 120 fire damage on contact, mitigated by fire
defence. Both Shard and Bond use it; Bond only applies the contact attack once.
No completion bonus, stagger, knockback or lifesteal.

Shrine details now use a vertically expanding ScrollContainer with horizontal
scrolling disabled and a wrapping child Label. Long descriptions cannot increase
the menu's minimum height; changing selections resets scrolling to the top.
These layout and balance changes have source-only verification, not runtime tests.

## Damage numbers follow-up

`scripts/damage_number.gd` displays one warm-gold rolling damage total per target
(muted red for the player). Hits within 0.8 seconds accumulate; after a pause the
next hit starts a new total. Fade finishes 1.3 seconds after the last hit.
Receivers report actual health lost, capped to remaining health, after all
invulnerability gates. Pure status application and rejected hits show no number.
Numbers are independent of blood/particle budgets, pause with gameplay, linger
at a removed target's last position, and clear on shrine rest/scene replacement.
Hooks: Feedback, player, sentinel, training dummy, summon, shrine. Runtime and
visual checks remain unperformed; source and whitespace diff inspection only.

## Assets and code

New:
- scripts/resources/max_health_drain_definition.gd — Inspector-editable curve.
- data/spells/blackflame_bond.tres — spell and nested drain/tether resources.
- data/attacks/blackflame.tres — shared attack with nested Arcane burn settings.
- data/vfx_blackflame_bond.tres — budgeted dark-flame presentation.
- blackflame_bond_handoff.md — this handoff.

Changed:
- scripts/resources/tether_delivery.gd — consumes its attack's shared drain.
- scripts/resources/attack_definition.gd — optional drain and resolved tick value.
- scripts/spell_effects.gd — actor-owned refreshable percentage burn and visuals.
- scripts/sentinel.gd, scripts/training_dummy.gd, scripts/spell_summon.gd —
  accepted-hit application; enemy/dummy reset cleanup.
- scripts/spell_delivery_runtime.gd — snapshotted duration and drain scheduling.
- scripts/spell_delivery_service.gd — drain configuration validation.
- scripts/player.gd — pre-cost receiver validation and scaled channel timer.
  Also applies attack burns after its existing invulnerability gates.
- scripts/resources/vfx_definition.gd — appended DARK_FLAME style.
- scripts/spell_visual.gd — alpha-composited dark/pale flame strands, crimson
  embers, target ring; line emitters now align with their resolved endpoint.
- data/game_catalog.tres — selectable spell registration.

Existing spell scenes, particle materials, cosmetic budgets, Reduced Effects,
paused clocks and cleanup paths are reused. No new scene or shader required.

## Verification

Source inspection and git diff --check only; no Godot import, parser run,
automated test or runtime test. Runtime-unverified: integer damage totals across
frame rates, all Arcane endpoints, cancellation/invulnerability, shrine selection,
both catalyst hands, VFX appearance, budgets/performance and cleanup.
