# Plan for task 185: the ground changes with the seasons gradually, as overlays

## 1. What's there today and why it looks patchy
- `SeasonBlend` gives each tile two fixed random thresholds.
  - The season threshold is a plain hash of the tile's position. During each 4-day blend window, tiles flip one by one between whole looks (SPRING, SUMMER, AUTUMN, BARE).
  - The weather threshold is 55 % hash and 45 % slow noise, about 12 tiles across. It flips whole tiles to SNOW, DUSTING or FROST.
  - A snow cover of 0.3 therefore means about 30 % of tiles fully white and the rest clear. Apart from the thin dusting band, no tile is partly snowed.
- Every look is a separate recoloured atlas made by `tools/art/seasons.py`. It is drawn as a dual-grid overlay TileMapLayer, one per look and per variety layer (about 40 layers). Its edges follow the tile-corner masks, so patches always have tile-shaped outlines.
- The colours themselves cause the "yellow" and "grey":
  - Autumn turns the marsh grass tips olive and the dry Geest grass straw. The dry grass sits in big noise patches, so it shows as yellow areas.
  - BARE (winter without snow) remaps all grass to brown-grey.
  - FROST is a whole-tile pale blue-green.
- The view redraws chunk by chunk every game hour, up to 3 ms per frame, so changes pop in tile by tile.
- Trees, decorations and houses swap their whole picture by the same thresholds. A house is all snow or none.

## 2. The approach
**Base colour.** A ground shader on the grass-type terrain layers (grass, lush, dry, salt marsh, Warft, trodden) mixes the current tile pixel smoothly between two season atlases at the same UV.
- The mix follows a year curve with no steps: spring (fresh), summer, autumn (darker green), winter (deepest green).
- Only the generator's remaps change: autumn and BARE become dark greens instead of olive, straw and grey.
- The salt marsh keeps its red-purple autumn and follows the same smooth curve.
- Not recommended: a CanvasModulate, which would also tint paths, soil and objects and can't do the salt marsh; or palette cycling, which can't fade.

**Overlays: a mix of a coarse cover texture and a fine per-pixel threshold map.**
- *Coarse cover texture.* One texel per tile, held in a fixed-size ring texture: 512² RGBA8, about 1 MB, enough for the 11×11 chunks that can be loaded. It is sampled with bilinear filtering, so it is smooth across tiles. Its four channels:
  - leaf catch: high near broadleaf trees, low on paths;
  - snow catch: lower under trees and in the lee of houses;
  - melt weight: high on paths and open ground;
  - frost shelter: under canopies.

  It is rebuilt only on chunk load, an object change (a tree felled or planted) or a new path.
- *Fine threshold map.* A tileable greyscale texture made by the generator, mixing noise a few tiles across with per-pixel grain. Its histogram is evened, so "cover 0.3" means 30 % of pixels. It is sampled per art pixel.
- *The rule per pixel:*
  - snow shows where `cover × catch − melt × melt_weight` is above the threshold;
  - leaves show where `litter × leaf_catch` is above each leaf's rank;
  - frost shows where `frost × (1 − shelter)` is above the threshold, weighted towards the light blade tips.
- *Per-pixel choice.* Each pixel shows grass, a leaf, rime or snow; nothing is blended, so the art stays crisp and on the palette. Thin cover gives a dusting with organic edges, and no tile grid shows.
- *Colour sources:*
  - Snow and frost colours come from the existing snow and frost atlases at the same UV.
  - Leaves come from a new tileable leaf-litter texture in world space, with a rank per leaf, so leaves arrive one at a time and never fade as a whole.
- *Draw order:* base → leaves → frost → snow.
- *Shared parameters.* One `game/scenes/ground_cover.gdshaderinc` holds them as Godot global shader uniforms, set once per game minute. This is the first use of `shader_globals` in project.godot.

**Frost** stays a function of temperature (`frost_at`). It is now sampled per minute, so the rime builds on cold mornings and shrinks as the day warms, fading faster in sun.

## 3. The state side
- **SeasonBlend**
  - Keeps the blend windows and the per-tree foliage looks.
  - Adds `ground_mix(day)` and `litter(day)`.
  - Drops `weather_look`, `ground_season_look` and the weather threshold.
- **SnowCover**
  - Keeps its hourly integration and `forced`.
  - Adds `melt_at(...)`, the melt since the last snowfall peak, which resets when snow falls.
- **New pure class `GroundCover`**
  - Works out each tile's catch, melt and shelter from the world.
  - Gives `snow_at(tile)` and `is_snowed(tile)`, mirroring the shader rule at the tile centre.
  - Footsteps (task 186), soil wetness, flowers under snow, wildlife and hit effects use it.
- **Removed:** the roughly 40 look-overlay TileMapLayers, ChunkLooks' season and weather bits, and the hourly refresh queue.
- **Saves:** not affected. Everything derives from the seed, world, day and weather.

## 4. Objects
- **Trees and objects:**
  - They keep their per-tree season pictures.
  - The object material adds the same cover rule, sampling a new "snow only" atlas. The generator writes the difference between each object's snow and bare looks, plus a rank channel, so caps grow from the top down.
  - Frost works the same way.
  - Swaying plants, the see-through sprites and the falling-tree sprites get the same material.
- **Decorations:** the decoration-sway shader gets the include, so flowers and tufts get snow gradually.
- **Houses:** each house sprite gets a material that lays its roof-snow-only picture over the season picture. The caps grow from the ridge to the eaves. Turf roofs keep season pictures, with their winter grass dark green.
- **Soil:** on SoilWetness, snowed pixels go transparent, so the snowed soil below shows.

## 5. Both arts
- The rules work per art pixel, so a classic leaf or snow speck is one 16 px art pixel.
- The generator draws the new textures through the existing classic pipeline:
  - the threshold map;
  - leaf litter with ranks;
  - the object and house snow-only atlases;
  - the darker-green ground remaps.
- No new palette colours are needed; the palette is full at 64 of 64.

## 6. Performance
- **CPU:** the hourly per-tile refresh goes away. Each game minute costs a few uniform sets. A chunk load costs filling 32×32 texels plus one upload, about 1 ms or less.
- **GPU:** about 5–7 texture samples per ground pixel, behind uniform branches; about 40 tile layers are removed. A net gain is expected; confirm with `make bench` before and after.
- **Memory:** about +1 MB for the cover texture, plus one snow-only object sheet.

## 7. Open questions for the user
a. **Paths and soil.**
- Trodden grass takes the grass tint.
- Bare path and soil get no tint and fewer leaves, and their snow is trodden or melts first.
- Do fields get leaf litter at all?

b. **Water and ice.** Water stays as is, and the tidal mud stays clear. Should ice be part of this task?

c. **Dry Geest grass in autumn.** Darker olive, or keep a little straw?

d. **Leaf litter.**
- Should it keep the existing "leaves" decoration?
- Should the litter brown and thin through winter?

e. **Colour mix during transitions.** The base colour is a smooth mix that is briefly off the palette, as the day/night tint already is. The alternative is an ordered dither.

f. **The lee needs a wind.** I propose a fixed westerly, not the live wind.

g. **Risks:**
- The CPU mirror can drift from the shader; tests pin the rule.
- The sprite stand-ins (see-through, falling trees) must keep their snow.
- Global shader uniforms are new to the codebase.

## 8. Commits in order
[ART] marks a commit that needs the user's approval of the look.
1. **State.** Season keys, `ground_mix`, `litter`, `melt_at`, the `GroundCover` class and tests. Nothing visible changes.
2. **[ART] Generator.** Dark-green ground remaps, the threshold map, leaf litter with ranks and the snow-only atlases, in both arts, with Python tests.
3. **Plumbing.** Global uniforms, the include and the cover ring texture, tested against `GroundCover`.
4. **[ART] Ground switch.** The terrain material. The look overlays and the refresh queue are removed. The footsteps and snow checks move to `GroundCover`, and soil snow transparency is added.
5. **[ART] Objects.** Object materials, the see-through and falling-tree sprites, and hit effects.
6. **[ART] Houses.** Roof snow builds up through a sprite material.
7. **Clean-up.** Remove DUSTING. Update the docs (seasons-and-weather, architecture, art-style).
8. **[ART] Tuning.** Numbers in seasons.cfg after the screenshot review.

## 9. Tests and screenshots
- **GUT tests:**
  - continuous curves with no yellow or grey targets;
  - more snow gives a superset of snowed tiles;
  - leaves near broadleaf trees, none on water;
  - less snow under trees;
  - paths clear first in a thaw;
  - footsteps on a partly snowed tile.
- **Python tests** for the new textures.
- **New startup options** `--melt` and `--frost`, next to `--snow`.
- **Screenshots** before and after, in both arts:
  - days 15, 45, 70 and 85;
  - day 100 with no snow;
  - frost at 07:00 and at 13:00;
  - snow 0.1, 0.4 and 0.9;
  - a thaw;
  - a farm with trees and a house, and a path.
- **`make bench`** before and after.

Critical files: game/scenes/world_view.gd, game/scenes/terrain_tileset.gd, game/state/season_blend.gd, game/state/snow_cover.gd, tools/art/seasons.py. Also: ambient_motion.gd, building_views.gd, decoration_view.gd, soil_wetness.gd, object_sway.gdshader, data/seasons.cfg, project.godot.

## Second opinion (Sol, 2026-11-11): sound with changes, to be folded in

- **Coverage:** cover reaches paths, soil, floodplain and wetland too, not grass only. Water and tidal mud are excluded.
- **Terrain atlas UVs:** disable texture padding consistently on the affected sources, or convert the coordinates. Anchor the cover in world space, including the dual-grid half-tile offset. Use nearest filtering for art and ranks, and linear only for the coarse cover.
- **Materials don't compose:** add the cover into the existing object, decoration, water and fire shaders rather than overwriting them. SoilWetness's 24 child layers each need it. Keep object snow inside the existing y-sorted draw.
- **Snow-only assets:** explicit masks with ranks, drawn per seasonal picture (bare trees have other silhouettes). Sample at the object's ground anchor, with the same sway UV and falling rotation. Keep occlusion fading, lit windows and roof details.
- **Ring texture:** a validity contract covering positive modulo, the seam, stale slots, teleports, chunks loaded outside the window (`ChunkResidency.require()`) and houses kept outside residency. Treat it as a render cache only. Invalidate a change's whole influence radius.
- **Melt:** drop `melt_at` at first, because SnowCover already melts.
- **GroundCover mirror:** it shares the exact inputs, quantisation and rounding with the shader, and gives a coverage fraction, with an optional position query for footsteps. Gameplay never depends on the art set.
- **Global uniforms:** register them early and reset them between worlds. Budget the samplers, and keep data textures out of colour conversion and palette checks. Measure rendered GPU cost; `make bench` is headless.
- **Additive migration:** first separate the daily vegetation refresh (foliage, flowers, fruit) from weather rendering. Then move the ground, decorations, objects and houses one at a time, and remove the old APIs, overlays and DUSTING last. Update the tests in each commit.

## The user's decisions (2026-11-11)

- Build it as planned with Sol's changes, but later: it stays in the queue, and 186 goes first.
- **Grass colour:** a smooth mix while the grass changes colour (briefly off the palette, like the day/night tint), not a dither.
- **Dry Geest grass in autumn:** it keeps a little straw colour, subtle and even, never in patches.
- **Ice on water:** a separate task later, not part of 185.

## Built (2026-11-12)

Built in the order of section 8. Differences: `thaw_at` stands in for `melt_at` (Sol); step 7 also
removed `SeasonBlend.thresholds` (its weather half and the evening-out table, now
`season_threshold`) and the DUSTING look with the `dusting_band` rule; the build ghost lost its snow
look; the roofs get their snow from a per-house picture, ranked from the ridge down in pack.py.
