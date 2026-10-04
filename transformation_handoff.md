# Raven transformation v1

## Controls and tuning

Cycle utilities with V to Raven Form; G / controller utility / mobile USE transforms and attempts reversion. Dedicated T and mobile FORM controls are removed. Form utilities have unlimited uses and no displayed consumable count. The form Resource owns its SVG icon; UtilityDefinition references the form.

The selected utility's transformation Resource selects the form without Raven-specific controller logic. Edit data/raven_transformation.tres: normal speed 420, sprint speed 630, sprint stamina 12/s, acceleration 1500, braking 1900, transition 0.4s, camera zoom 0.94 and velocity lead 0.06. Nested MovementDefinition and VFXDefinition resources are never mutated by the runtime. Visual scenes implement optional setup(TransformationDefinition).

Raven disables melee, spells, cycling, utilities, interactions and ordinary dodge through six independent permission settings. Health, equipment identities, spell charges, currency, stamina and lock target remain on the original player. No unlock menu, Wolf or feline is implemented. Traversal tags are descriptive future extension metadata, not an alternate physics implementation.

## Terrain authoring

Physics layer 1 remains ordinary ground obstacles; Raven ignores it and enemy body layers. Layer 4 is transformed player body. Layer 5 is flight-blocking geometry; both existing scene boundaries now use layers 1 + 5 (mask 17). Layer 6 marks no-landing terrain, water and gaps. Use bodies to block human movement and/or Area2D volumes to forbid landing. Raven's movement mask is 16; human mask is 51; landing checks also include summons (55).

Future low obstacles stay on layer 1. Major barriers use layers 1 + 5. Painted water/gaps need authored layer-6 collision volumes; this pass adds no new terrain.

## Lifecycle

Runtime phases HUMAN / ENTERING / ACTIVE / REVERTING are separate from the existing combat state. Entry requires normal state. Transitions clear combat intent while retaining held sprint, touch movement and velocity when preserve_transition_movement is enabled. Sprint support, speed, VFX frequency, animation response and camera lead are form-configurable. Both silhouettes use an ash-edge dissolve shader with reverse formation, plus feather bursts; no model scaling or motion blur. Landing checks every enabled humanoid body shape using its full transform, includes bodies and areas, excludes self, and checks again on completion. Failed reversion stays Raven with feedback, never teleporting.

Pause freezes timers; hurt cancels entry or returns interrupted reversion to Raven. Active Raven retains form through stagger. Death restores humanoid visuals and saved masks at the death position (no corpse relocation). Scene exit frees visuals and restores masks. Ordinary Raven shrine interaction is disabled; externally requested restore requires valid landing before clearing form.

Equipment and imbue presentation is suppressed while transformed without removing equipment data. Existing VFX budgets, Reduced Effects and effect ownership are reused. No flight shake is requested.

## Inventory

New: scripts/resources/transformation_definition.gd, scripts/player_transformation.gd, scripts/raven_visual.gd, scenes/raven_form.tscn, data/raven_transformation.tres, transformation_handoff.md.

Modified: scripts/player.gd, scripts/player_visuals.gd, scripts/mobile_controls.gd, scripts/courtyard.gd, scenes/forest_camp.tscn, project.godot.

## Verification boundary

Source/reference, permissions, collision masks, lifecycle and diff checks only. No Godot imports, automated tests or runtime tests run.

Runtime-unverified: parsing/import, visuals and transitions, both boundaries, corners and dynamic landing blockers, airborne damage, mobile layout, pause/focus, death/rest/scene replacement, equipment effects returning, camera, Reduced Effects and performance. Combat-enabled future forms require their own animation/presentation; no new form-specific combat is implemented.
