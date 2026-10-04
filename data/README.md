# Inspector-editable definitions

This directory contains immutable authored Resources. The current source-level guide is [AUTHORING_GUIDE.txt](../docs/AUTHORING_GUIDE.txt); current values are in [LIVE_TUNING.json](../docs/LIVE_TUNING.json) and [TUNING_SUMMARY.txt](../docs/TUNING_SUMMARY.txt). Older prototype tuning and catalogue-only loadout instructions have been superseded.

## What owns what

- `game_catalog.tres` indexes definitions; it does not grant ownership or spawn content.
- `GameSession` / `CharacterState` own attributes, acquired equipment instances, upgrades, spell/utility uses, discoveries, checkpoints and recovery.
- Classes select starting definitions; actor instances copy mutable runtime values.
- Weapons reference light/charged attacks and optional catalyst basics. Attacks own damage/scaling, action timing, melee geometry, status buildup and feedback.
- Spells select a typed delivery definition. Its VFX profile owns optional visual scenes, palette, particles, trails and lighting. All current spells have one; a missing definition is rejected before spending a use, matching the starting project.
- Status Resources configure buildup/decay/resistance response and triggered payloads. Direct timed effects and Blackflame retain their separate contracts.
- Enemy definitions select perception and move Resources. Scene encounter IDs and transforms own persistent identity and placement.
- Progression, authored rewards, climate/weather, procedural sound/music and the shared UI theme are editable here.

## Units

**128 world units = 1 metre.**

Spell delivery geometry and speeds are world-space; never multiply them again by actor/art scale. Melee reach/radius, legacy enemy AI distances and recoil are actor-local and converted once using actor scale. New enemy move/perception fields labelled metres are converted explicitly. Movement Resources are already world-space. VFX artwork dimensions and screen-space HUD/shake use their own documented boundaries.

Human walk/sprint remains 512/768 units/sec; Raven 1024/1536. Camera tuning is unchanged. The world-scale guide and authoring guide explain the remaining boundaries.

## Safe editing

1. Duplicate a definition and give it a unique stable ID.
2. Make nested Resources unique when the new variant should not change an existing one.
3. Assign the definition to a compatible scene, and register selectable content in the catalogue.
4. Assign acquisition through class-owned starting items or an authored reward; catalogue membership alone does not make an item equippable.
5. Use the explicit Content Audit/editor overlays when you choose to validate authoring. They are diagnostics, not runtime test results.

Keep resource IDs stable for saves. Do not serialize Resources as character state or mutate shared definitions from gameplay. Boss phases, heavy/skill references and equipment load penalties remain explicitly outside the implemented gameplay scope; see the guide's data-only section.

This rebuild has been inspected as source only. Godot imports, automated tests and runtime review have not been run by Codex.
