# Combat presentation pass

## Authoring

- AttackDefinition > Feedback: assign a CombatFeedbackDefinition for contact.
- Spell > Delivery Definition > VFX: Release Feedback, Impact Feedback and
  Completion Feedback are independently assignable. Child deliveries inherit
  the existing VFX context unless they provide their own.
- EnemyDefinition > Attack Feedback: optional outgoing-contact override,
  inherited by bosses. Null keeps the attack's profile.
- Profiles expose shake strength/duration/frequency/falloff, directional kick,
  zoom punch, hit-stop, colour wash, brightness/contrast pulse, distortion,
  chromatic separation, low/high controller vibration, sound/rumble keys,
  cooldowns, recurring intensity and HUD response.
- Audio keys resolve through Feedback.sounds; existing gameplay audio remains.
  A synthesized one-shot rumble is registered. Custom sounds can be registered
  there without changing delivery or combat code.

## Defaults and bounds

Four reusable assets: data/vfx/feedback_light.tres, feedback_medium.tres,
feedback_heavy.tres, feedback_exceptional.tres. Shake strengths are respectively
0.8, 2.2, 5 and 8 world pixels, with 0.10/0.16/0.22/0.30-second envelopes.
All 20 weapon presentation attacks receive profiles: dagger light uses light,
other light actions medium, charged actions heavy.

All 20 spell VFX profiles now contain explicit impact-feedback subresources.
Rune Mine and Falling Stars use exceptional-style impacts; Ember Wave, Vow Spear,
Moon Arc, Comet Step and Soul Thread use heavy-style impacts. Others use light
impacts. Their colour washes match their VFX palettes. Major spells use medium
release feedback; other spells use light release feedback. Successful full
channels use completion feedback, never on early cancellation. Explosion areas
can request feedback even when no receiver is hit; receiver and area requests
are coalesced by the global gate.

Up to eight active envelopes. Global event spacing is 0.075 seconds for discrete
events, 0.35 seconds for recurring events, plus per-source/profile cooldowns.
Beams/cones/zones/auras/tethers and summon attacks use recurring feedback: default
6–8% intensity, no flash, distortion, vibration, extra audio or hit-stop. Burn
ticks retain their existing completely silent presentation. Health damage and
collision are never budgeted or throttled by this system.

Camera displacement is capped at 12 pixels, punch at 3.5%, wash at 8% opacity,
distortion at 0.003 UV and chromatic separation at 0.002 UV. Existing hit-stop
remains actor-local, not an Engine.time_scale freeze. Profiles override legacy
contact feedback where assigned; unprofiled attacks retain legacy behaviour.

## Screen, settings and lifecycle

The always-on vignette uses a fixed 0.12 maximum opacity and wide clear centre.
It no longer changes with health or combat events. The vignette sits below HUD
widgets. Transient screen effects are on CanvasLayer 40, below HUD layer 50.
HUD damage response is a brief health-bar tint, not a layout move.

Pause settings provide a 0–100% Screen Shake intensity slider (zero also disables
kick/punch). Reduced Effects disables the transient screen overlay, reduces
camera motion to 20% and vibration/HUD response to 30%; normal hit confirmation
and the permanent vignette remain. Settings retain the existing session-only
behaviour; no persistence added.

Explicit elapsed time drives all new animations. Pause, application focus loss,
player death, shrine rest and scene changes clear presentation envelopes and
controller vibration. Camera base zoom and aim bias are restored. No scene
reparenting, particle-budget changes or new persistent lights are introduced.

## Changed asset inventory

New: scripts/resources/combat_feedback_definition.gd;
scripts/combat_presentation.gd; shaders/combat_screen.gdshader;
data/vfx/feedback_{light,medium,heavy,exceptional}.tres; this handoff.

Changed scripts: feedback.gd, player.gd, sentinel.gd, court_hud.gd, shrine.gd,
spell_delivery_service.gd, spell_delivery_runtime.gd; resources/attack_definition.gd,
resources/vfx_definition.gd, resources/enemy_definition.gd.
Changed shader: shaders/atmosphere.gdshader.

Changed attack assets under data/attacks/presentation: both light and charged
for ashen_dagger, ashen_seal, court_shield_bash, court_staff, heavy_iron_mace,
pilgrim_spear, pilgrim_wand, sentinel_blade, sentinel_greatblade, wanderer_sword.

Changed data/vfx_*.tres assets: astral_edge, blackflame_bond, blackflame_shard,
cinder_field, cinder_lance, comet_step, ember_wave, falling_stars, furnace_breath,
mending_halo, mending_light, moon_arc, prismatic_ray, rune_mine, soul_thread,
star_shard, storm_link, vowed_wisp, vow_spear, watchful_shards.

## Verification

Source inspection covered event ownership, accepted-hit routing, recurrent-event
suppression, scene/pause cleanup and resource declarations. 48 resource files
were inspected for declaration ordering and missing referenced files: none
reported. git diff --check passed (line-ending notices only).

No Godot imports, shader compilation, automated tests or runtime tests performed.
Visual strength/readability, screen-texture behaviour on Mobile, combined-event
performance, controller feel, menu sizing, hit-stop feel and lifecycle correctness
remain runtime-unverified. Confirm all of these in-game before treating defaults
as balanced or production-ready.
