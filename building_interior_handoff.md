# Seamless buildings and logical elevation — 2026-10-04

## Status

Implemented in source following approval to connect collision, combat and
navigation. This replaces the earlier partial/blocked handoff. **No Godot import,
launch, automated test or runtime test was performed.** Engine parsing and all
in-game acceptance remain unverified.

Also fixed the reported flood from `building_floor.gd:38`: optional
`elevation_definition` metadata is checked with `has_meta()` before reading.
Unmarked objects inherit their nearest explicit level, otherwise ground level 0.
The fix addresses the lookup itself, not merely logging frequency.

Fixed a further resource-loading cycle found during the user's editor review:
elevation → stairs → PlayerController → starting loadout → shared spell visuals.
Building helpers now query the actor's `has_traversal_tag()` capability rather
than importing the concrete player/transformation classes. The shared VFX scene
exists; its downstream spell-resource errors were not missing spell assets.

## Runtime connections

- Reusable building, floor and procedural roof components, with independent roof,
  facade, wall, floor-art and interior-art paths. Chapel entry/exit targets a
  configurable 0.22-second fade; rapid reversal changes the target rather than
  queuing tweens. Death/removal closes an open exterior; pause pauses fades.
- Signed integer logical floors, with no fixed storey count. Ground physics
  categories remain unchanged. Nonzero floors use a shared raised category bank,
  plus incompatible-body exceptions and filtered physics queries. Levels are
  actor-owned runtime metadata, not writes to shared Resources.
- Player, Sentinel, summons, dummies, interactables and floor-owned colliders
  register explicitly. `ElevationMember` covers standalone objects. Saved semantic
  masks support transformation/reversion, corpse reset and body reparenting.
  Additional configured levels allow a structural collider to span storeys.
- Generic stairs/ramps use an authored corridor and a midpoint collision-plane
  seam. Movement is swept to the seam, destination occupancy is checked, then
  movement continues on the destination plane. No teleport or room loading.
  Upper/basement floors require authored support; unsupported motion is stopped.
  Scene-entered actors must start on a valid authored landing.
- Same-floor lock-on, melee, receiver-side damage checks, enemy acquisition,
  interactions and shrine combat checks. Dropped currency retains its origin
  floor. Target selection remains same-floor by default.
- Spell contexts snapshot their launch floor. Projectiles, chains, areas, fields,
  traps, rain and summon attacks filter targets and walls by that floor.
  Attached channels/aura/orbiters/dashes cancel on a caster floor change.
  Interrupted windups cannot release on a different plane. Already-applied burns
  and periodic effects remain attached to their receiver.
- Attacks and deliveries expose `cross_elevations` for deliberately cross-floor
  payloads. Child deliveries preserve attribution and floor context. Per-hit
  copies carry resolved floor information without modifying shared attack assets.
- Navigation windows are keyed by region sector AND floor. Unsupported cells and
  incompatible-storey collision are excluded. Local builds retain the
  256-probe-per-physics-frame ceiling and invalidate on geometry registration.
- Actor, damage-number, impact, stain, spell and top-level particle presentation
  follows floor visibility; temporary lights attenuate with it. Detached fading
  spell tails retain their last floor. Screen-impact feedback respects the event
  floor instead of the caster's later position.
- Optional cosmetic-only nodes can suspend while interiors are hidden. Collision
  and actor state are not unloaded. Settled floor fades stop processing.

## Chapel integration

The existing chapel remains single-storey. Its nave/apse are covered by an opaque,
faceted slate roof with panel courses, weathering and trim. Entry reveals the
interior and upper entrance facade; leaving restores them. Original wall
foreground-reveal materials and collision geometry remain in place.

The 17 existing prop/encounter blocks retain their authored properties and
positions, with only parent paths changed under identity, Y-sorted groups.
Generated Sentinel placement inherits the encounter marker's floor while retaining
the world's actor hierarchy. Map footprints still come from the same descendant
props. Raven's existing Z 6 presentation remains above the roof's Z 5; airborne
movement does not reveal the interior by default.

Fort Greywatch was not expanded or edited. No movement/camera resources, combat
damage/timings, region placements or starting loadouts were retuned in this pass.

## Authoring a structure

1. Add a `BuildingInterior` Node2D and assign a `BuildingDefinition`.
2. Instance `scenes/buildings/floor.tscn` for each storey. Make its definition and
   nested elevation resource unique before changing them in the Inspector.
   Set the signed level and local metre polygons; 128 units = 1 metre.
   Add floor art, walls, props and optional roof/facade art to the indicated groups.
3. Put moving actors in `Occupants`, NOT beneath a fading art group. Their own
   visibility follows their current floor; a faded ancestor would otherwise
   continue hiding them after they leave it. Keep these groups Y-sorted.
   Generated encounters can use floor-parented markers or
   `floor.attach_occupant(actor)`; custom spawners should assign level metadata
   before adding the actor to the scene.
4. Instance `scenes/buildings/stairs.tscn` beneath the building. Set from/to levels,
   local metre endpoints and width. Endpoints must overlap supported floor space.
   Leave both floor collision footprints clear through the corridor and seam.
   Disable `draw_steps` for a ramp with custom art. Rotation/translation is allowed;
   avoid scaling the structure as a substitute for metre-authored dimensions.

The generic floor template is an 8×8 m starter footprint, not a finished room.
Add a `BuildingRoof`/roof Resource or custom CanvasItems to RoofArt. The chapel
provides the finished roof example. Custom scene art fades at runtime; the editor
cutaway preview specifically targets procedural BuildingRoof nodes.

Use `ElevationMember` for standalone raised platforms, props or interactions.
Author collision in the existing semantic categories (bits 1–8); runtime owns
the parallel bits 9–16, with named channels 9–14 in Project Settings. Do not author
storey numbers as physics-bit numbers. Do not set arbitrary new raw masks on
registered actors: use `Elevation.set_masks()`.

`Preview Interior`, `Preview Level` and `Refresh building preview` operate on
procedural roof preview state without saving preview alpha into scene properties.
No gameplay starts in editor preview. Runtime structural rebuilding must remove
old owned floors/colliders so their registrations and navigation caches invalidate.

## Boundaries / authoring obligations

- This is logical elevation, not 3D flight/falling. Off-floor movement is blocked
  unless an authored transition supplies support. Raven retains its traversal
  masks and does not take stairs unless the transition permits airborne actors.
- AI navigation is floor-local, not a cross-storey route planner. Enemies do not
  hunt through ceilings; companions idle/retry when their caster is on another
  floor. Future stair-seeking AI is not included.
- Current actors use CollisionShape2D. Support clearance uses conservative bounds
  plus perimeter samples; highly irregular custom bodies/floor edges need manual
  traversal review. This is not a continuous geometric support solver.
- Custom Area2D overlap callbacks, new actor controllers or new physics queries
  must use the shared compatibility/query helpers. Body exceptions do not filter
  arbitrary Area2D signals automatically.
- Visual suppression is effect/actor-owned, not per-pixel room clipping. Very long
  beams, wide particles and custom top-level descendants spanning several rooms
  still require visual review. Existing ground-level map/compass behaviour is
  unchanged; there is no floor-selection map UI in this pass.
- Floors should have unique levels within one structure. Different structures can
  reuse a level. Markers/spawn positions and landing footprints remain authored
  responsibilities; this pass does not auto-build doors, void rails or stairs.

## Changed-asset inventory

New building/elevation assets:

- `scripts/elevation.gd`, `scripts/elevation_member.gd`,
  `scripts/elevation_transition.gd`
- `scripts/building_interior.gd`, `scripts/building_floor.gd`,
  `scripts/building_roof.gd`
- `scripts/resources/elevation_definition.gd`,
  `scripts/resources/elevation_transition_definition.gd`
- `scripts/resources/building_definition.gd`,
  `scripts/resources/building_floor_definition.gd`,
  `scripts/resources/building_roof_definition.gd`
- `data/buildings/chapel.tres`, `data/buildings/chapel_ground_floor.tres`,
  `data/buildings/chapel_roof.tres`
- `scenes/buildings/floor.tscn`, `scenes/buildings/stairs.tscn`
- This handoff, `building_interior_handoff.md`

Existing gameplay/presentation integrations changed:

- `scenes/landmarks/chapel.tscn`, `project.godot`
- `scripts/stillwood_overworld.gd`, `scripts/foreground_reveal.gd`
- `scripts/player.gd`, `scripts/player_transformation.gd`, `scripts/sentinel.gd`
- `scripts/targetable.gd`, `scripts/training_dummy.gd`
- `scripts/interactable.gd`, `scripts/shrine.gd`, `scripts/currency_drop.gd`
- `scripts/resources/attack_definition.gd`,
  `scripts/resources/spell_delivery_definition.gd`
- `scripts/spell_cast_context.gd`, `scripts/spell_delivery_service.gd`,
  `scripts/spell_delivery_runtime.gd`, `scripts/spell_projectile.gd`
- `scripts/spell_summon.gd`, `scripts/spell_effects.gd`,
  `scripts/spell_navigation.gd`, `scripts/spell_visual.gd`
- `scripts/feedback.gd`, `scripts/combat_presentation.gd`

Other pre-existing worktree changes were retained, not reverted.

## Verification and next manual review

Source/reference/diff inspection only. Check in Godot before treating this as
runtime-verified: class/resource parsing; chapel doorway fades in both directions;
outside Sentinel occlusion; canopy/wall reveal; overlapping positive/negative
floors; stairs forwards/backwards and when blocked; dodge and dash at seams;
cross-floor targeting, body collisions and spells; burns across transitions;
Raven reversion; summons and navigation windows; death/rest/reset; pause; detached
VFX; scene reload and editor preview. Visual quality and performance are unmeasured.
