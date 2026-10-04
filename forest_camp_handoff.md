# Stillwood camp — metre-scale reference scene

Open scenes/forest_camp.tscn and use F6 for the user's runtime review. No imports or runtime tests were run during implementation. The main-scene selection and courtyard remain unchanged.

## Scale contract

128 Godot world units = 1 metre. Ground drawing is authored directly in metres and converted once by draw_set_transform. Scene node positions, collision shapes and navigation bounds are stored in corresponding world units.

| Reference | Metres | World units |
| --- | --- | --- |
| Bounded reference area | 64 × 48 | 8,192 × 6,144 |
| Irregular camp clearing, nominal | 18 × 14 | 2,304 × 1,792 |
| Mossy clearing shoulder | 21 × 17 | 2,688 × 2,176 |
| West / east / south path width | 2.4 / 3 / 2 | 307.2 / 384 / 256 |
| Shrine–fire separation | approximately 5.4 | approximately 693 |
| Shrine visible stone height | approximately 1.28 | 164 |
| Campfire stone-ring diameter | approximately 0.97 | 124 |
| Mature tree artwork height | approximately 6–9 | roughly 800–1,150 |
| Tree trunk collision diameter | 0.55–0.86 | 70–110 |
| Stepping-stone spacing | 0.65 | 83.2 |
| Bedroll size | 0.65 × 1.75 | 83.2 × 224 |
| Shrine interaction radius | 1.5 | 192 |
| Navigation cell width | 0.5 | 64 |

Tree crowns are roughly 5–7.5 m across, deliberately wider than trunk collision. This is stylised top-down projection, not simulated 3D height. Root flares and ground shadows are decorative, not full obstacle footprints.

## Re-authored composition

53 individually saved trees occupy eight deterministic, irregular clusters, with a tree-free central clearing and path buffers. Three winding approaches retain the west/east/south orientation. Camp anchors are shrine (-2, -2) m and fire (2.8, 0.5) m. A short stepping-stone approach, a mossy shrine ring, two abandoned bedrolls and firewood retain the small-camp identity. Paths match the clearing's earth colour at joins.

No graveyard, chapel, plains, fort, enemy expansion or region connections are implemented. Boundaries are prototype flight blockers at the 64 × 48 m footprint, not the final region perimeter. The background apron prevents uncovered screen pixels at wide Raven zoom; it is not additional playable area.

## Player, camera and gameplay scope

Only this scene's player instance is scaled to 4.0, yielding an approximately human-sized 1.8–2 m silhouette instead of the previous miniature appearance. Held equipment and body collision inherit that scene scale. Existing player and Raven movement speeds, spell ranges, damage, attack timing and other combat balance are unchanged. Those existing combat/VFX distances have not undergone a metre-scale rebalance.

Normal reference camera zoom is 0.5, Inspector-editable on ForestCamp. Raven retains its 0.5–0.25 relative multiplier. Scene-local stride distances are 0.6 m walking and 0.9 m sprinting. Shrine interaction uses a scene-local ShrineDefinition; player interaction reach changes only on a private duplicate of its movement Resource. Shared class/movement assets remain untouched.

Camera limits, tree reveal radius (190 units), canopy softness (64 units), light inheritance and fire effect origins accommodate the new proportions. Raven remains above canopies. Flight masks and invalid landing rules are unchanged.

Navigation uses the existing solver with 64-unit cells and a scene-configured 40-unit probe radius (12,288 cells). The shared solver's default radius remains 12 for other scenes. First-build navigation time and actual path clearance require runtime review.

## Changed files

- scenes/forest_camp.tscn: new authored layout, scale overrides, shrine definition, navigation and boundary dimensions; original scene UID retained.
- scripts/forest_camp.gd: metre-authored terrain, paths, camp detail and scene-only camera/interaction/stride setup.
- scripts/forest_tree.gd: optional independently authored trunk collision radius; existing callers retain their default behaviour.
- scripts/campfire.gd: transformed local effect origins and scale-aware positional audio distance.
- scripts/spell_navigation.gd: exported collision-probe radius, retaining the old default.
- forest_camp_handoff.md: this reference specification.

## Verification

Static source/reference inspection and diff whitespace checks completed. All scene external references resolve to existing files. No Godot imports, automated tests or runtime tests were run.

Unverified: Godot parsing, perceived proportions, camera limits at widest zoom, terrain joins, foliage density, canopy masking, shrine usability, summon navigation/build performance, scaled fire/shrine particles, combat reach versus enlarged actor art, mobile composition and Raven landing. This is the first reference layout, not a claim of playtested scale or balance.
