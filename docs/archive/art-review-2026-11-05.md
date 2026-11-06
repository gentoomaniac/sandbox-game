# Art review, 2026-11-05

Art-director review of `main` at b16075f (Opus). Screenshots were taken fullscreen
(`godot --path . -f -- --screenshot=...`), because the tiling window manager makes
windowed screenshots portrait.

Measured today: character 14×31 in a 16×32 frame (head ~10×9); oak 25–28 × 38–41; spruce
21×45; pine 26×36; dead tree 18×35; berry bush 24×16; shrub 19×12; sapling 14×16; fern
20×12; stones 13×13 and 15×11; fireplace 19×18; sleeping bag 10×13; turnip 6×4 … 8×9;
house 64×64 on 4×3 with a ~10×16 door; interior bed and table 16×16.

## 1. Scale

Problem: the character is ~31 px (almost 2 tiles) but nearly everything else is 1–2.5
tiles; the oak is only 1.3× the character, the door half its height. Reference range:
person ~1.5–1.75 tiles, mature tree 2–2.5× the person, small house 3–4× the person.

- **Character:** keep the 16×32 frame; figure 27–28 px (~−10 %), feet on the bottom row,
  head top at y≈4. Head 9×8, torso 9–10, legs 7–8. Keep the 2 px walk bob.
- **Trees** (trunk base centred on the standing tile):
  - oak 44–46 × 60–64 (crown ~44 wide, trunk 6–8 wide, ~16 px trunk visible);
  - spruce 26–30 × 62–66 (tallest, narrow);
  - pine 34–40 × 58–62 (long bare trunk ~24 px, flat crown);
  - dead tree 30–34 × 46–50;
  - later: large old oak 64×80 on a 2×2 base.
- **Bushes:** berry bush 26–28 × 20–22; shrub 22–24 × 16–18; fern 18–20 × 14–16; sapling
  12–14 × 20–24 (thin trunk, reads as a young tree).
- **Stones and camp:** small stone stays 13×12; new boulder 28–30 × 22–24 on 2×1 tiles
  (higher harvest level); fireplace 22–24 × 18–20 with 2–3 logs; sleeping bag 14×26 on
  1×2 tiles, lying vertically.
- **Turnip:** seed mound 8×5 with a soil hump; then 10×8, 12×12, ripe 14×14 with the root
  showing.
- **Object atlas:** the 32×48 cell no longer fits. Either one uniform 48×80 cell (standing
  tile = bottom-centre 16×16) or per-row cell sizes (small things 32×32, trees 48×80).
  Update the cell constants, object tileset, `sprite_height`; add a test that each
  `sprite_height` ≥ the opaque height in the atlas; widen the see-through radius to ~2
  tiles.
- **House:** footprint 5×3 (80×48); sprite 80 × ~96 (wall face ~36, roof ~50, ~3 tiles
  above the footprint). Door 14–16 × 24–26 on the middle tile (door_offset (2,2)), at least
  the character's height. Windows 10×10 with sills and a lit night variant. Chimney 8×12.
  Roof in 3/4 view (ridge, slope towards the viewer, eaves 2–3 px over the wall).
- **Interior:** same tile grid and character scale. Back wall a 2-tile (32 px) wall face
  (plaster, wainscot, window, beam); side and front walls 6–8 px top rims. Room 7×5 floor
  plus walls. Furniture: bed 16×32 on 1×2 (or 24×32), table 32×24 on 2×1 with two 10×10
  stools, doormat 16×8, hearth/stove 32×32 (light source), chest 16×16.

## 2. Top improvements to existing assets (most impact first)

1. The scale pass above.
2. **Light colour/strength:** campfire `Color(1.0, 0.6, 0.3)` at energy 3.0 additive turns
   grass lime and bleaches the character. Use ~(1.0, 0.5, 0.22) at energy 1.2–1.6; consider
   a mix/capped mode so lit pixels move towards `flame`/`gold`.
3. **Dusk tint:** 18:30 olive, water grey. Add a small warm additive term at dusk
   (~+0.05 red), lower blue more, darken less. Night blue (0.40, 0.46, 0.74) is good.
4. **Lit windows at night:** gold/cream window variant plus a small point light.
5. **Tilled soil reads as planks:** short broken furrows with clods and damp spots, soft
   irregular edge into grass.
6. **Wetland reads as a dark hole:** lift its value a step, add standing-water pools (water
   palette, foam rim), cattails/reeds with heads, lily pads; the yellow "Y" reeds look like
   cacti.
7. **Grass texture:** fewer, varied, clustered marks; dry grass should shift to yellow hue,
   not darker olive; it dominates whole areas.
8. **House art:** straw/gold thatch with darker rows, 3/4 roof, door frame and step,
   shadow under the eaves.
9. **Character:** keep the outer outline, but coloured inner lines (hair dark, cloth
   shade); hoe in `soil_dark`; nose pixel and arm swing in side views; 4-frame walk.
10. **Oak crown:** 2–3 lobes, sky holes, darker underside.
11. **Water:** lighter shallow band along banks, a few glint pixels (animate later).
12. **HUD:** pixel font at an integer UI scale on a small framed panel; tile highlight as
    corner brackets.
13. **Fern bush and sapling:** fronds; trunk and stake.
14. **Sleeping bag:** rolled pillow end, blanket fold.

## 3. New assets needed next

**P1 (current/next milestones):**
- Tool icons 16×16: hoe, axe, pickaxe, watering can, scythe, seed bag; two tiers as
  palette swaps (copper, iron).
- Held-tool layers and use poses (16×32, 4 facings × 2–3 frames): axe, pickaxe, watering
  can.
- Inventory UI: 9-slice frame (8×8 corners), 20×20 slot with selected/hover, 10-slot
  hotbar, tooltip panel; native UI scale, integer multiples.
- Energy bar (~8×48 frame + fill, 12×12 icon).
- Pixel UI font (5×7 or 6×8 bitmap, generated or open licence).
- Item icons 16×16: turnip, turnip seeds, wood log, stone, fibre, berries, mushroom.
- Stump 20×12 and felled-tree debris.
- Paths (autotiled): dirt, then cobble.
- Fences: wood fence and gate, 16×16, 4-way masks, gate open/closed.
- Watered-soil overlay.

**P2 (building and exploration):**
- Buildings: barn 7×4 (~112×112), workshop/shed 4×3 (64×80), storage chest 16×16;
  placement ghost tints.
- Style variants: thatch/shingle/slate roofs as palette swaps; second door type.
- Interior furniture: hearth with light, chest, shelf, rug 32×32.
- Ore nodes 16×16–20×18 (copper, iron) with a hit state; boulder 28×24.
- Forage sprites 16×16: herbs, mushrooms, wild berries.
- Floodplain debris: driftwood, washed-up crate.
- Next biome: mountain rock and ALttP-style 16 px cliff faces with a lip; snow and ice
  (palette has no snow/ice colours yet); sand/path.

**P3 (life sim and combat later):**
- NPC base on the same layered 16×32 system (body variant, 3–4 hair styles, apron/robe,
  elder body).
- Creatures: bog slime 16×16 (2-frame idle), wolf 32×24 (4 facings), wetland critter;
  hit flash and death puff 16×16 × 4.
- Combat UI: hearts/bar 8×8; damage-number font.
- Torch 8×24 and lantern post 16×32 (world objects with light).
- Magic later: sparks, rune circle, glow orb (16×16/32×32) in `arcane`/`spirit`.

## 4. Style consistency

- **Palette:** 43 colours vs SPEC "about 32". Missing snow/ice (2–3), a berry red distinct
  from `ember`, a cool shadow blue-grey; several near-duplicate greens could merge.
- **Outline rule:** outer outline in the darkest colour of the object's own ramp
  (selective outline); ink only for characters and interactable pickups; no outlines on
  terrain.
- **Light direction:** top-left everywhere; house wall darker on the right, shadow under
  eaves.
- **Ground shadows:** every standing thing gets a 1–2 px contact shadow (`green_deep` /
  `bog_dark`), or none at all.
- **Perspective:** house and interior to ALttP-style 3/4 view like trees and the
  character.
- **Detail density:** trees and the house use 2–4 px clusters like the character, not
  single-pixel noise.
