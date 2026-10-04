# Ashen Vow: world scale and Stillwood March

Updated 4 October 2026 for the larger-region/environmental-art pass and the game-wide spatial audit. This document supersedes the earlier 202-metre fort layout and 42,175 m² region.

## Scale and preserved tuning

**1 metre = 128 Godot world units.** Distance in metres is units / 128; area in m² is square world units / 16,384.

| Metres | World units |
| ---: | ---: |
| 1 | 128 |
| 10 | 1,280 |
| 100 | 12,800 |
| 450 | 57,600 |
| 1,000 | 128,000 |

| Mode | Units/second | Metres/second |
| --- | ---: | ---: |
| Human walk | 512 | 4 |
| Human sprint | 768 | 6 |
| Raven flight | 1,024 | 8 |
| Raven sprint | 1,536 | 12 |

Movement, acceleration, stamina and camera-zoom settings are unchanged by the spatial audit. The current Resources retain human 512/768 and Raven 1,024/1,536 units/second, human zoom 0.25 and the currently authored Raven wheel limits 0.10–0.25. The player scene's base artwork scale is now 4, matching its existing forest instance; this changes neither forest character size nor camera zoom. Camera travel limits follow the containing world. Interaction reach is now a shared 192-world-unit (1.5 m) default, replacing the camp's runtime override.

The camp remains anchored at (0, 0). Its shrine (-2, -2), fire (2.8, 0.5), player spawn (-2, 1.5), clearing dimensions and original trees are retained. Coordinates in this document are metres relative to camp; scene positions are those coordinates multiplied by 128.

## Spatial authoring contract (game-wide audit)

Use `WorldScale.UNITS_PER_METRE` / `WorldScale.metres()` for new metre conversions. Do not multiply every number by four: the game deliberately distinguishes three coordinate spaces.

| Domain | Authoring units | Runtime conversion |
| --- | --- | --- |
| Region routes, biome bounds, landmark layouts | Metres | Multiply by 128 once when building world geometry |
| Spell delivery ranges, radii, widths, linear speeds; summon movement/targeting | World units; speeds in world units/second | None: the resources and defaults have already been migrated |
| Player/Raven locomotion, dodge, lock-on, interaction, pickup, navigation | World units | None; never multiply by actor artwork scale |
| Melee reach/radius/lunge, enemy AI distances, recoil, body/equipment polygons | Actor-local authored units | Actual world-transform scale once; standard actors are 4x |
| VFX profile dimensions, procedural effect silhouettes, particles/lights | Authored artwork units | `VFXDefinition.art_scale` (default 4) for detached/spell visuals; attached physical effects follow their owner scale |
| Spell visual snapshots | World-space positions and lengths | Convert positions with `to_local`; divide lengths by VFX art scale before drawing |
| HUD/map UI, icons, screen wash, camera punch/shake, fonts | Screen-space or dimensionless presentation values | Do not enlarge with the world |

The missed spell geometry was still using the original unit-scale values while forest actors were already 4x. The audit migrates those lengths and linear speeds by four in the Inspector resources and their defaults. It does **not** change damage, percentage burns, uses, costs, lifetimes, channel duration, tick intervals, angles, homing turn rates or counts. Self healing and weapon imbues need no targeting-radius enlargement; their presentation now uses the same artwork conversion. Any leftover `Spell.cast.reach` is melee attack metadata, not the spell's delivery range.

### Effective named spell geometry

These are resolved source values, including inherited defaults and child deliveries, **not playtested balance**. Generic point placement is capped at 1,600 units (12.5 m); touch/controller placement defaults to 720 units (5.625 m). Projectile flight distance is speed × lifetime, not that point-placement limit.

| Spell | Effective world-space geometry |
| --- | --- |
| Star Shard | Speed 2,080/s; 2 s flight = 4,160 (32.5 m); radius 20 |
| Cinder Lance | Speed 1,760/s; 2 s flight = 3,520 (27.5 m); radius 24 |
| Vow Spear | Speed 1,520/s; 2 s flight = 3,040 (23.75 m); radius 40 |
| Ember Wave | Caster-centred radius 420 (3.28125 m) |
| Mending Light | Self healing; no range gate; scaled cast/release presentation |
| Prismatic Ray | Length 1,520 (11.875 m); width 72 |
| Astral Edge | Weapon-bound; uses actual equipped-model tip; bonus unchanged |
| Furnace Breath | Range 640 (5 m); existing 70-degree sector |
| Moon Arc | Speed 1,120/s; distance 1,680 (13.125 m); width 480; thickness 64 |
| Cinder Field | Radius 360 (2.8125 m) |
| Storm Link | Jump radius 720 (5.625 m) |
| Watchful Shards | Orbit radius 160 (1.25 m); child speed 1,400/s, radius 28, 2 s flight |
| Rune Mine | Trigger radius 180 (1.40625 m); child explosion radius 340 (2.65625 m) |
| Falling Stars | Scatter radius 400 (3.125 m); impact radius 140 (1.09375 m) |
| Vowed Wisp | Speed 400/s; follow distance 280; acquisition 1,200; attack 960; child speed 1,400/s, radius 28 |
| Mending Halo | Radius 360 (2.8125 m) |
| Comet Step | Distance 840 (6.5625 m); swept width 104; duration unchanged |
| Soul Thread | Break/effective acquisition range 1,280 (10 m) |
| Blackflame Bond | Cast/break range 1,280 (10 m); burn scaling/timing unchanged |
| Blackflame Shard | Speed 2,080/s; 2 s flight = 4,160 (32.5 m); radius 24 |

The default Target delivery range is also 1,600 world units. All 17 delivery classes were reviewed, including types without a dedicated named spell. Shared child resources are never mutated to apply scale.

### Supporting systems and retained courtyard

Melee hit geometry uses actual actor scale for both hands and every weapon family, including charged attacks. Sentinel AI/lunge/recoil now derive the same scale automatically unless explicitly overridden. Enlarged summons use 40-world-unit collision radii; placement clearance is 48 units, and local navigation defaults use 128-unit cells with 64-unit clearance. Existing forest navigation already used those settings and is not enlarged again.

Feedback now converts detached dust, blood/stains, transformation particles, spell silhouettes and local lights without double-scaling attached effects. World-space GPU emitters use private material copies and identity-scale transforms. Movement effects use transformed foot offsets. Currency artwork is enlarged independently of its 192-unit pickup radius, and drops spawn at actual death positions even beneath scaled parents. Damage totals use screen-readable text anchored above the scaled receiver. Positional one-shot audio reaches 4,800 world units; screen-feedback distance attenuation is enlarged, but shake/punch strength is unchanged. Existing particle/light budgets remain intact.

Reusable player, Sentinel, dummy and shrine scenes now default to 4x artwork. Forest instance overrides remain 4x (overrides replace properties rather than multiplying them). The retained `scenes/main.tscn` courtyard uses a 4x environment root and **explicit 1x actor-instance overrides**, producing 4x global actors, not 16x. Its world-space camera limits and navigation bounds follow the enlarged arena. Equipment itself is not resized.

The already-metric overworld, architecture, trees, collision footprints, bridge/water restrictions, map/compass/marker distances and discovery distances were inspected and left at their current sizes. Reveal defaults now match the existing regional 190-unit radius / 64-unit feathering. Reversion still checks the actual transformed humanoid collision shapes.

Source checks covered 292 scripts/resources/scenes/shaders: referenced file paths and resource IDs resolve, no merge-conflict markers were found, and tracked whitespace diffs were clean. This is **not** a Godot parse/import or runtime validation. No engine, imports or automated/runtime tests were run. Later review must check all deliveries, both hands, impacts/expiry, walls, placement, summons, audio falloff, VFX alignment, pickups, pause/rest/death and the retained courtyard. Visual quality, collision feel, spell balance and performance remain runtime-unverified. `world_scale_audit.json` lists the changed files and numeric migration details for this pass.

## Geography and travel

A continuous region runs from overgrown western gravewood and the chapel, through the camp and forest, across a stream/woodland edge and open meadows, to Fort Greywatch. Northern and southern paths reconnect; landmarks are not a compulsory checklist.

| Landmark | Anchor (m) | Editable scene / role |
| --- | --- | --- |
| Stillwood Camp | (0, 0) | forest_camp.tscn; starting shrine and fire |
| Broken Waystone | (-65, -55) | landmarks/waystone.tscn; northern woodland loop |
| Widow's Pool | (-90, 60) | landmarks/widows_pool.tscn; southern exploration pocket |
| Rootbound Graves | (-165, 0) | landmarks/graveyard.tscn; irregular grave clusters |
| Chapel of the Last Watch | (-200, -35) | landmarks/chapel.tscn; nave, broken apse, Court Sentinel |
| Split Oak Clearing | (75, 25) | landmarks/split_oak.tscn; split trunk and fallen half |
| Ruined Crossing | (185, 15) | landmarks/crossing.tscn; bridge with dry approaches |
| Old Watchtower | (245, -65) | landmarks/watchtower.tscn; northern plains overlook |
| Pilgrim's Rest | (330, 55) | landmarks/pilgrims_rest.tscn; sheltered southern ruin |
| Abandoned Quarry | (365, -70) | landmarks/quarry.tscn; stepped bowl and cut stone |
| Fort Greywatch | (450, 0) | landmarks/fort.tscn; gatehouse, courtyard, roofless hall |

**Camp-origin to fort-anchor distance is exactly 450 m (57,600 units).** The authored principal polyline is **589.4 m**. Ideal travel: 56.25 seconds direct normal Raven flight, 37.5 seconds direct sprint flight; approximately 2 minutes 27 seconds walking the main route, or 1 minute 38 seconds sprinting it.

These are arithmetic, not measured gameplay. They exclude acceleration, turning, collision, stamina depletion, fights, transformation time and exploration. Sprint timings assume uninterrupted sprint.

| Route Resource ID | Centreline length | Width |
| --- | ---: | ---: |
| camp_to_greywatch | 589.4 m | 3.5 m |
| chapel_road | 224.0 m | 2.4 m |
| widows_loop | 236.6 m | 1.8 m |
| waystone_loop | 160.4 m | 1.8 m |
| watchtower_loop | 191.8 m | 2 m |
| pilgrims_loop | 230.4 m | 2.2 m |
| quarry_loop | 178.6 m | 2 m |

The main road has a straight bridge passage with angled approaches outside the deck. The chapel loop approaches its porch from the south; tower and Pilgrim routes pass their accessible sides. Collidable graves, roots, cut blocks and fallen timber sit outside reserved travel corridors. Original camp trees remain clear of those corridors by source-coordinate inspection.

Roadside scenery candidates occur every 32–44 m, alternating sides: fallen trees, memorials, rocks, abandoned shelters and rubble. They are reserved before tree planting. Placements conflicting with authored footprints, other routes or the boundary are skipped; this is not a claim of measured encounter density.

## Region boundary and blocked-area accounting

- Irregular authored boundary area: **152,525 m²** (15.25 hectares).
- Bounds: x = -260 to 515 m, y = -120 to 115 m.
- Bounding rectangle: 775 × 235 m (182,125 m²), **not** the playable area.
- Boundary perimeter: approximately 1,822.5 m.
- Landmark solid footprints: approximately **1253.8 m²** in summed source geometry.
- Two-metre-wide boundary collision strips: approximately **3645.1 m²** total; roughly half lies outside the boundary.
- Preserved camp-tree trunk footprints: approximately **21.5 m²**.
- Known raw footprint sum: approximately **4920.4 m²**, before generated trees and roadside props. This includes overlaps and the exterior part of the boundary strips; it must not be subtracted directly from the enclosed area as an exact walkable-area figure.
- The runtime map-data field `blocked_area_estimate_m2` adds generated prop and trunk footprints to that same raw sum. No runtime value or collision-union measurement has been collected.

The former 25,000–50,000 m² estimate is no longer a cap. Net walkable area, actual traversal density and the human/Raven experience remain runtime-unverified.

## Shared authoring workflow

1. Open **scenes/forest_camp.tscn**. Reopening the scene shows authored camp/landmark nodes only; it no longer automatically generates the full region during editor startup.
2. Edit landmark scene instances under **Actors/Landmarks**, or open their source scenes. Their actual transforms determine map/discovery positions. Do not maintain a second landmark coordinate list in scripts.
3. Edit **data/stillwood_region.tres**: typed routes, six biome profiles and scatter settings. Coordinates and widths are in metres; seed 7319 is the default.
4. Landmarks expose stable IDs, discovery metadata, rectangular decoration reservations, floor rectangles and optional coloured floor polygons. Props expose footprints/heights, flight-blocking and collision settings. Encounter Marker2Ds remain directly editable.
5. Under **Editor Preview** on the camp root, choose **Preview Center Metres** and **Preview Half Extent Metres**, then toggle **Rebuild Region Preview**. The default window is 64 × 64 m centred on camp, with terrain/canopy margins. Half-extent is capped at 64 m; repeated rebuild requests are coalesced. The same seeded placement pipeline is used, preserving off-window reservations and random consumption, but only nearby generated artwork is instantiated. Rebuilding replaces only ownerless generated terrain/dressing; authored landmark instances and manual scene children remain intact. Runtime still builds the full region.
6. Run the scene only when ready for the separately authorised runtime review. Preview does not start enemies, player controls, HUD, audio or gameplay effects. Runtime rebuild invalidates navigation windows; reload the running scene to refresh the HUD's map snapshot after authoring changes.

Generated children have no scene owner and are not baked into the saved scene. Metadata identifies generated roots even after tool-script reload. Do not put manual edits underneath generated preview roots; put them under Actors or within a landmark scene.

Editor recovery note (4 October): full automatic tool-script generation was identified as a likely contributor to the reported “Reopening Scenes” stall, not a confirmed crash diagnosis. Automatic generation was removed; build-stage/timing logs now identify where future explicit builds stop. Recovery was reported by the user. The revised preview has only been statically inspected, not run by the agent.

## Presentation, map and traversal contracts

Soil and vegetation colours blend spatially from biome Resources. Trees cluster with broadleaf, conifer and dead-tree families. Joined road ribbons, continuous chunk-edge ground patches, irregular water banks, grave clusters, masonry kits and connected boundary cliffs replace the earlier regular scatter/rock-ring presentation.

Low walls, graves, trunks, water and rubble use ground collision (layer 1), allowing Raven overflight while preventing invalid human landings. Major cliffs and substantial masonry use layer 17 (ground plus flight blocker). Bridges have a clear dry collision corridor. Obscuring architectural art is separate from footprint collision and uses the existing player reveal. Equipment layering and Raven's above-canopy presentation are untouched.

Map terrain comes from the same biome colours, routes, water/structure polygons, floor shapes and scene transforms. Distant woodland is aggregated, finer trees and small props appear on zoom-in, and important labels get overlap-aware placement. Fort remains known initially; other landmarks require proximity. Fullscreen M map, markers, beacons, arrival fades, transitions and vignette remain.

The top-down camera cannot show a fort hundreds of metres outside its viewport. Distant orientation is deliberately handled by the map/compass plus real approach views, not a fake horizon image or new camera zoom.

Six existing Sentinel-based encounters occupy the chapel, graves, watchtower, Pilgrim's Rest and fort. There is no new enemy archetype or boss. Existing spatial scaling and combat values are retained.

## Performance and lifecycle

Terrain is partitioned into default 16 m drawing chunks. Local route, reservation and tree-neighbour buckets avoid all-route/all-tree scans per placement. Static obstacles stay loaded continuously, including beneath Raven. Offscreen water/reveal processing is suspended; world timers inherit gameplay pause.

Navigation uses shared 64 × 64-cell local windows, 1 m cells, up to eight ready and eight pending windows. At most 256 collision probes run per physics frame. Missing paths return empty and retry while windows build; no actor teleports. The player's neighbourhood is periodically prewarmed and explicit region rebuild invalidates caches.

Existing ambient/transient particle budgets remain 256 / 1,792, or 2,048 combined; temporary lights remain capped at eight. This pass adds no new particle emitters or persistent lights. Existing camp/shrine VFX retain Reduced Effects handling. No motion blur, fullscreen fog, renderer change, spell retuning, progression, loot, boss, fast travel or saving is introduced.

## Verification and remaining review

Completed: source and Resource-reference inspection, typed-array migration, coordinate/footprint clearance inspection, encounter-anchor inspection, boundary and route-length arithmetic, ownership/cleanup review, and diff/whitespace review. The reported Array[RegionRouteDefinition] versus Array[Dictionary] errors are resolved by keeping authored routes typed and explicitly adapting them into map dictionaries.

**Not run:** Godot import, engine parse, automated tests or runtime tests. Static inspection does not establish visual or runtime correctness.

Later review must cover human/Raven traversal on all branches; walls, bridge and landing restrictions; Sentinel/summon navigation; architecture/tree reveal and equipment ordering; map markers/discovery/fades; pause, rest and reload; repeated editor rebuilds; and CPU/GPU performance at the widest Raven zoom.

Visual quality, traversal density, balance and performance are explicitly runtime-unverified. See overworld_handoff.json for the complete changed-asset inventory.
