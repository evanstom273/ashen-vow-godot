# Ashen Vow

A PC-focused, magic-first action RPG built in Godot **4.7.1**, with project-contained SVG artwork, layered scene rigs, procedural terrain/VFX and synthesized audio.

The whole-game rebuild is implemented in source. **It has not been imported, parsed or runtime-tested by Codex.** Visual quality, balance, save-failure handling and performance still require the approved review described below.

## Start here

- [Master roadmap and implementation register](docs/REBUILD_ROADMAP.txt)
- [Whole-game handoff](docs/WHOLE_GAME_HANDOFF.txt)
- [Authoring and architecture guide](docs/AUTHORING_GUIDE.txt)
- [Resource/save migration notes](docs/MIGRATIONS.txt)
- [Current tuning summary](docs/TUNING_SUMMARY.txt) and [machine-readable inventory](docs/LIVE_TUNING.json)
- [Verification status and acceptance checklist](docs/VERIFICATION.txt)
- [Every changed/new asset](docs/CHANGED_ASSETS.json)

The main scene opens the title screen and three local character slots. The opening region remains Stillwood March. A separate `scenes/combat_lab.tscn` provides a disposable debug character without writing character saves.

## Fixed scale and controls

**128 world units = 1 metre.** Human walk/sprint: **4/6 m/s**; Raven flight/sprint: **8/12 m/s**. Movement, acceleration, camera tuning and camp/Fort geography were preserved.

Left/right mouse use the right/left hand. Space taps dodge and holds sprint. Q/R cycle hands, C cycles spells, V cycles utilities, F casts, G uses the utility, B commands orbiters, E interacts, middle mouse locks enemies, and M opens the fullscreen map. Controller bindings and rebinding are available in Settings. Raven remains a utility form and can only be entered outside combat.

No FP, motion blur, boss encounter, extra region, guarding/parrying, randomized gear stats or online/cloud systems were added. Existing mobile code is retained but is not the target of this PC rebuild.

## Authoring

Use `data/game_catalog.tres` for definitions, not character ownership. Add drag-and-drop scenes through the filesystem or World Authoring shelf. Keep manual placements separate from generated preview content. See the guide for units, sockets, status/attack contracts, owned items, rewards, checkpoints, navigation and climate.

Art sources are in `assets/illustrated/`; the editable UI theme is `data/ashen_theme.tres`. Historical root handoff documents describe earlier passes; the current documents above take precedence where implementation has changed.

**Do not run imports or tests automatically.** The replacement acceptance source is opt-in and remains unexecuted.
