# Art pipeline

- Assets are created by Claude for now, in a **semi-fantasy/medieval pixel style**.
- They come from a **generator script** (`make assets`). The generated PNGs are
  committed. Hand-drawn PNGs may replace single files later.
- **One fixed palette** (own palette, see Style rules for its size): earthy greens and browns,
  muted blue water, warm accents for fire and light, room for magic colours. All assets
  use only palette colours.
- **Terrain transitions (autotiling)** from the first art pass, so terrains blend
  instead of meeting as hard squares.
- **Style rules** (from the art review):
  - outlines: outer outline in the darkest colour of the object's own colour ramp; ink only
    for characters and interactable pickups, never on vegetation (the dead tree and the trunks
    too are rimmed in their darkest bark); no outlines on terrain; plants with loose blades
    (tall grass, fern, reeds) get a ground shadow, a dense foot in the two darkest shades
    rimmed in the ramp's darkest, and light shades above, never an outline round single blades;
    the helpers are `canvas.outline` and `canvas.outline_edge`, the ramp table `palette.DARKEST_OF`;
  - light from the top left everywhere;
  - every standing thing gets a small contact shadow;
  - houses and interiors in 3/4 view like trees and characters;
  - 2–4 px detail clusters, not single-pixel noise.
- **Palette:** "about 32" is loosened to **up to ~48 colours**, so snow/ice, a berry red and
  a cool shadow grey fit; merge near-duplicate greens. The seasonal looks (spring greens,
  autumn leaves, snow) raise the cap to **about 64** (decided 2026-11-05). The style guide's
  swaps (task 52): `meadow_dark`, `lush`, `crimson` and `frost_light` merged into their
  neighbours; `meadow_light` stays, as the Scots pine's lit needles; `lime` (lime-wash),
  `paint_teal` (doors and shutters), `heather` and `heather_dark` added. `arcane` and
  `spirit` are kept for magic only. 64 of 64 used: a new colour needs a merge first.
- **Variety:** the world must not look tiled.
  - Large-scale colour variation: terrain colour shifts slowly across the world (e.g.
    lusher, drier, yellower patches of grass), driven by low-frequency noise in world
    coordinates.
  - Many variants per terrain, including the edge shapes.
  - A **visual-only decoration layer** (flowers, clover, pebbles, small plants) scattered
    unevenly on top of terrain. It has no gameplay effect and is not a world object.
  - **Flowering meadows** (decided 2026-11-06, task 75): in spring and summer the green
    flowers with the meadow and pasture flowers of the region, in drifts and patches by a
    seeded noise, not evenly sprinkled. Each habitat has its chance and its communities of
    species that bloom one after another (`data/flowers.cfg`): dense on meadow grass and the
    floodplain, heather on the dry Geest, cuckooflower and meadowsweet on wet ground, few
    (wood anemone, red campion) in the woods, none on fields or water. A tile shows its
    species furthest into its bloom, so the species of a drift mix and the drift changes
    colour with the weeks; a species' first and last flowers are small ones. Early spring has
    few, late spring and summer are full, autumn fades and winter has none. When a tile
    blooms nothing, its ordinary decoration shows.
- **Desire paths** (decided 2026-11-06, task 77): ways walked often wear into paths with
  less grass. Every tile the player steps onto outdoors takes a step of wear (a farm animal
  half a step); a tile turns trodden (thin, flattened grass with the earth showing) and then
  a path of bare earth, and each night takes some wear off, so an unused path grows back to
  grass in about two weeks. Numbers in `data/paths.cfg`: trodden from 8 steps, a path from
  24, at most 32, 2 a night; walking the same line about eight times a day makes a path in
  four or five days. Only grass (ordinary, lush, dry) and the floodplain wear; fields,
  wetland, water, buildings (their doors too) and interiors don't. Worn tiles lose their
  flowers and tufts. A path is a look only: no change to speed or farming, and tilling it
  works as on grass (and clears the wear). Drawn as two dual-grid layers over the grass,
  with soft dithered edges, in every season's look and the frost; snow covers paths, with a
  faint trodden track over them; in a bare winter the earth lies dark. The wear is saved
  (only worn tiles, dropped once they have grown back).
- **Floodplain looks fertile:** lush, damp meadow, with a narrow muddy bank right at the
  water. It must not read as barren sand.
