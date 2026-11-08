# 32x32 art resolution mockup (2026-11-08)

The same 20x11-tile scene (a Kate, a path, a wheat and cabbage field, a pollard willow, a stream
with reeds and tall grass, the player, a villager, a horse, a cow, a chicken, a cat, a mouse and
a frog), drawn twice:

- **A, today** (`a_today_640x360.png`): put together from the committed assets (terrain atlas
  dual grid as in `terrain_tileset.gd`, objects atlas, crops, `kate.png`, character layers,
  wildlife sheets) at 320x180, then nearest-neighbour x2.
- **B, 32x32** (`b_32px_640x360.png`): every piece in view redrawn at 32 px per tile, at a native
  640x360. Same 64-colour palette (checked: no pixel outside it), same light from the top left,
  same outlines and materials as `docs/art-style.md`.
- `compare.png` shows them side by side, `compare_detail.png` has three close-ups (A above B) at
  x3, and `*_1920x1080.png` are both at x3 for a monitor.

Re-run: `/home/marco/git-private/sandbox-game/.venv/bin/python make.py` (deterministic).
Nothing in the repo was changed.

## What was redrawn for B

| Piece | 16 px today | 32 px in B |
|---|---|---|
| Grass, lush and dry grass, path, trodden grass, tilled soil, water | 16x16 tiles, dual grid | Per pixel with the same dual-grid layering. Grass tufts are little fans with a dark root and lit tips, gathered into calm and thick patches. Clover, daisies and buttercups in drifts. The path has a pale worn middle, clog dents and pebbles with their own shadow. Soil has 4 ridges per tile, each with a lit crest and a dark furrow, plus clods. Water has a shaded bank, a shallow edge, ripples and grass hanging over the bank |
| Kate | 80x96 | 160x192. Thatch in courses 7 px high, each with a lit top, reed ends of mixed lengths and a ragged shadow line under it. Rolled eaves 12 rows deep. Moss, crossed ridge sticks, an eyebrow dormer with panes, windows with 3x3 real panes and a glint, braced shutters with hinges, a split Klöntür with strap hinges and a brass knob, round fieldstones each shaded on its own, rain splash at the foot of the wall |
| Pollard willow | 48x80 cell | 112x150: a furrowed trunk with a hollow, a head of knobs, about 70 rods with narrow leaves in a loose crown, a few silver leaf undersides |
| Reeds, tall grass | ~16x24 | 44x60 and 36x44: two-pixel blades with a lit edge, bending over; velvet bulrush heads; grass seed heads |
| Wheat, cabbage | 16x32, 16x16 | 32x64: 10 stalks, ears of paired grains with awns. 32x32: a head with wrapper leaves, outer leaves with midribs and veins |
| Player, villager | 16x32 | 32x64. Eyes with a glint, brows, a nose shadow, cheeks and a mouth. Hat brim casting a shadow on the forehead. Collar, a waistcoat with buttons and pockets, gathered sleeves, knee buttons, stockings, clogs with a lit top. The villager is in profile: coif with frill, a laced bodice, a skirt in folds, an apron, a bent arm |
| Horse | 44x36 | 88x76. Legs with forearm, knee, cannon, fetlock and hoof, and a hind leg with gaskin and hock. Black points, mane strands, forelock, blaze, an eye with a glint, nostril, jowl, muscle lines, gleam on croup and shoulder |
| Cow | 32x24 | 64x48. Straight back, hip and pin bones, ribs, pied coat shaded with the body, white face with dark eye patch, horns, ear, pink muzzle with nostrils, udder, cloven hooves, a tail with a tuft |
| Chicken, cat, mouse, frog | 12x12, 16x12, 12x7, 12x8 | 26x26, 34x26, 24x14, 22x16, drawn larger than life. Chicken: scalloped wing feathers, comb, wattle, beak, toes. Cat: tabby stripes, ringed tail, ears pink inside, green eyes, whiskers. Mouse: round pink ear, beady eye, bare tail. Frog: gold eye ring, barred thigh, pale throat |

B adds no shadows that A lacks, except what the generators already draw (ground shadows under
trees and houses).

## Effort compared with the 16 px version (rough)

This is measured on making this mockup, one frame per piece, with the 16 px generators to start
from:

- **Procedural pieces** (ground, thatch, willow, reeds, grass, crops): about **1.3-1.5x** the
  effort at 16 px. The algorithms carry over with doubled constants (the Kate's roof is
  `buildings.thatch_roof` with 7-px courses and deeper eaves). What takes the extra time is
  redesigning the textures so the new pixels show something: tuft shapes, reed ends, clods.
  These took 1-3 passes each.
- **Hand-placed figures** (people, animals): about **2-3x per frame**. The shapes and shading
  can be generated, but faces, joints, heads and coat marks are placed by hand, and a 32 px
  frame has 4x the pixels to get right. The horse took 3 passes and the cow 4: its head ended
  up hand-drawn, because generated heads read badly. The small animals and the people took
  1-2 passes.
- **Animation** is the big unknown. B has one standing frame per creature. Today a farm animal
  has 14 frames (cats 23), and a character layer has 20 frames plus collapse and riding. Doubled
  frames need more in-betweening care (a 2-px leg swing shows where 1 px hid it), so count
  2-3x per frame there too.

## What a full switch would touch

- **Art, `tools/art/`**: 33 modules, ~11,800 lines. They produce 522 PNGs (the seasonal
  variants are derived from these, so they cost little once the base art is done). Everything
  uses `canvas.TILE = 16` or fixed pixel coordinates:
  - Object cells go from 48x80 to 96x160, characters from 16x32 to 32x64, wildlife frames double.
  - The hand-written ASCII sprites (character layers, animals in `livestock.py` and `animals.py`,
    `villagers.py`, the riding and collapse sheets) cannot be scaled. They have to be redrawn.
    That is the bulk of the work, perhaps 60-70% of it.
  - Item icons (16 px), ground items (8 px) and UI slots (20 px) need a decision: keep or double.
  - The 32x32 portraits already exist.
- **Game code**:
  - `TILE_SIZE` appears in 31 files (85 uses). Mostly mechanical, if everything derives from one
    constant.
  - About 36 hard-coded pixel `Vector2`s in 12 files.
  - Frame sizes in `wildlife_sprites.gd`.
  - `window_lights` pixel positions in `data/buildings.cfg`.
  - The atlas cell sizes in `terrain_tileset.gd` and the object code.
  - The tests that pin these sizes.
- **Viewport, `game/scenes/view_math.gd`**: `DEFAULT_VISIBLE_HEIGHT = 180` and `VIEWPORT_SIZE` of
  640x360 plus margins. **The key decision is here.** B at a native 640x360 shows 20x11 tiles,
  the area of today's zoom 1. Fully zoomed out, the user sees 40x22 tiles today. Keeping that
  view at 32 px needs 1280x720 art px, which is a non-integer 1.5x on a 1080p monitor (shimmer
  when scrolling) and a clean 2x on 1440p. The other choice is to accept a closer camera:
  MIN_ZOOM 1, i.e. 640x360 art px at x3 on 1080p.
- **UI scale**: the UI has its own 640x360 base (`project.godot`, canvas_items stretch) and its
  own scale setting, so it does not have to change. Its 16 px icons would look coarse next to
  32 px art, though.
- **Pictures**: 35 screenshots in `docs/screenshots`, the README, and the review shots would all
  need to be taken again.

**Rough size**: the code side is 3-5 tasks of today's size. The art side is about 20-30 tasks,
one per generator family. Characters and their layers, and the animals with all their actions,
are the largest, a few tasks each. The ground, the buildings and the plants are cheaper because
their algorithms carry over. Expect the art to cost roughly a third to a half of what building
the current art took, plus 2-3x on every future animation frame.

## The Settlers 1 target

Settlers 1 ran at 320x200, with settlers about 12-16 px tall. They read at a glance because of
strong outlines, clothes in a few bright colours, ground lower in contrast than the figures, and
constant motion.

**How close B gets**: in detail B goes well past it. Our people are about 60 px tall at
640x360, and the horse, cow, chicken and cat show faces, joints and coat at a glance. The mouse
reads at 24 px because it is drawn larger than life. The frog reads but is the weakest: an olive
animal on green grass. It needs a lighter back or more contrast in its outline. On legibility, B
falls short in one way: the ground is busier than Settlers' ground (tufts, flowers, pebbles), so
it competes with small figures more than it should.

**To get closer**:

1. A calmer ground with lower contrast, keeping the strong values for figures and buildings.
2. Small contact shadows under creatures.
3. Slightly more saturated clothing accents per villager role.
4. Animation, which did most of the readability work in Settlers.

None of that needs a style change: we stay top-down 3/4 with our palette.
