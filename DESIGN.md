---
name: Ashen Vow
description: Project-contained illustrated gothic fantasy with readable magic-first combat
colors:
  amber-focus: "#e3c580"
  parchment-text: "#e7dfc9"
  muted-text: "#878a84"
  forest-ink: "#0b1413"
  lifted-forest: "#192522"
  panel-ink: "#0b1211"
  weathered-border: "#6d6852"
  panel-border: "#8d805b"
typography:
  body:
    fontSize: "17px"
  status-label:
    fontSize: "12px"
rounded:
  control: "0px"
spacing:
  control-x: "14px"
  control-y: "10px"
  panel: "26px"
  vertical-gap: "12px"
  horizontal-gap: "10px"
components:
  button:
    backgroundColor: "{colors.forest-ink}"
    textColor: "{colors.parchment-text}"
    rounded: "{rounded.control}"
    padding: "10px 14px"
  button-hover:
    backgroundColor: "{colors.lifted-forest}"
    textColor: "{colors.parchment-text}"
  panel:
    backgroundColor: "{colors.panel-ink}"
    padding: "26px"
---

# Design System: Ashen Vow

## Overview

**Creative North Star: "Illustrated gothic fantasy"**

Illustrated gothic fantasy built from project-contained SVG parts, Godot scenes, procedural geometry and shaders. The world uses weathered stone, layered foliage and quiet amber guidance; magic is the bright, readable exception.

Menus remain flat, dark and legible around the fixed equipment cross. The source implementation is recorded here, not visually certified: current-game captures and runtime typography/contrast review are still pending.

**Key Characteristics:**

- Eight-direction layered characters and explicit weapon sockets.
- Weathered, asymmetrical environment silhouettes with subdued foliage.
- Gold/amber interaction language around a fixed Souls-style equipment cross.
- Bounded spectacular magic, grounded physical impacts and restrained camera feedback.

Sources: data/ashen_theme.tres, scripts/game_theme.gd, scripts/illustrated_rig.gd,
scripts/shrine_loadout_menu.gd, scripts/equipment_cross.gd, scripts/ui/actor_status_display.gd
and assets/illustrated. See PRODUCT.md for confirmed product constraints.

## Colors

Quiet forest-black surfaces carry parchment text; amber distinguishes active choices.
The palette is extracted from the shared Theme, not a newly invented paint-over.

### Primary

Amber Focus marks focus, hover and selected actions.

### Neutral

Parchment Text carries readable information. Muted Text identifies disabled controls.
Forest Ink is the resting control field; Lifted Forest its interactive state.
Panel Ink separates a menu from the world. Weathered Border and Panel Border retain
subtle frame hierarchy without relying on stacked drop shadows.

**The Meaning before ornament Rule.** Reserve the amber highlight for focus, selection and navigation; rely on silhouette and geometry to distinguish the world.

Spell palettes are authored per VFX profile, not globally forced into the menu palette.

## Typography

The title uses the project-authored SVG wordmark, not an external display font.
Body controls use the shared Theme's native body size. Small status labels use
the recorded label size and must be checked at supported window sizes/UI scales.

The implementation currently falls back to Godot's body font. Some older menu
headings still inherit fallback display styling. That is documented as pending
visual refinement, not established as the future display-face system. No external
font family, weight ramp or tracking scheme is invented by this document.

## Layout

**The One equipment cross Rule.** Spells stay above, right hand right, utilities below and left hand left.

UI scale is configurable from0.75 to1.5 independently of the world camera.
Shared vertical/horizontal separation and control/panel padding are in the tokens.
The loadout menu uses three columns above960logicalpixels and one scrollable column
below; its frame is bounded around1180logicalpixels with at least16px side margins.
Long descriptions and services stay scrollable. Controller focus must remain visible.
Map fills the viewport; its own vignette and marker transitions remain independent.

## Elevation & Depth

World depth is layered artwork, actual actor/Y sorting, foreground reveal and
floor-aware visibility. Ground decoration stays below actors; upper architectural
art and roofs can reveal the player without changing obstacle footprints.
Raven retains its authored above-canopy visual layer.

Menus use flat tonal surfaces and fine borders. Player-health response does not
move the entire HUD. Permanent vignette and transient hit feedback are independent.

**The Art is not collision Rule.** Rebuilt textures and shadows never define reach, floor support, obstacle clearance or damage boundaries.

## Shapes

Controls retain square corners, one-pixel ordinary borders and a two-pixel focus
outline. This is a restrained game UI, not a grid of elevated web cards.
World art uses chipped masonry, irregular crowns, curved leaves and slanted cloth.
The procedural/SVG split follows geometry and deformation needs; it is not a rule
that every visible element must be a texture.

## Components

### Buttons and fields

Resting Forest Ink, parchment text; hover lifts the field and highlights its border.
Focus remains identifiable by the thicker amber edge. Disabled text uses Muted Text.
Use native semantic Button, LineEdit, slider and checkbox nodes with focus support.

### Containers and settings

The reusable settings scene consumes the shared Theme. Settings and shrine services
scroll rather than pushing controls offscreen. Reset/rebinding refresh controls
immediately. Modal ownership belongs to UIFlow; nested services stay under their
existing owner.

### Equipment and status

The retained equipment cross uses actual item/spell icons or retained procedural
icons. Catalyst basics show infinity; finite spells/utilities show remaining uses.
Status meters and direct-effect remaining durations add information without
rearranging the cross. Current small-label legibility is runtime-unverified.

### World and magic

IllustratedRig uses eight authored views and six independently animated parts.
Textures are imported once and reused. SVG weapon scenes expose grip/tip/cast sockets.
Visual setup/update/stop accepts delivery geometry but never applies damage.
Exhausted cosmetic budgets remove embellishment, not silhouettes or hit logic.

## Do's and Don'ts

### Do:

- **Do** keep art sources and procedural presentation inside the project.
- **Do** preserve the equipment cross and readable enemy telegraphs.
- **Do** treat texture bounds, weapon sockets, collision and damage geometry as separate contracts.
- **Do** use local Theme overrides instead of mutating shared Resources.
- **Do** honour Blood, Reduced Effects and the existing visual budgets.

### Don't:

- **Don't** add FP, motion blur, fullscreen fog or a renderer change.
- **Don't** hide important UI behind the permanent vignette or combat feedback.
- **Don't** replace eight-direction views with a mirrored front-facing actor.
- **Don't** create blood or successful-hit feedback for rejected contacts.
- **Don't** claim imported SVGs remain infinite-resolution runtime vectors.
