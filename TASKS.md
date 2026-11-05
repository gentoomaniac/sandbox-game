# Tasks: Prototype

Implements milestone 1 from [SPEC.md](SPEC.md). Each task is small enough for one
developer brief. Do them in order unless "Depends on" says otherwise. When a task is
done, tick it off here.

Rules for every task:

- Use only make targets for build, run, test and lint. A new multi-step command gets a new
  make target.
- Keep game state (world, tiles, buildings, crops, time) in plain GDScript classes with no
  rendering or input code. Scenes only read the state and send actions to it.
- State logic gets GUT tests (`make test`). Rendering and input are checked by hand with
  `make run`.
- `make lint` passes.
- Placeholder art only: flat coloured tiles and simple shapes.

## 1. Project skeleton and make targets

- [x] Done

Set up the Godot 4 project and the make targets.

- Godot project in the repo root, using a clear folder layout, e.g.:
  - `game/state/`: pure game state;
  - `game/world/`: generation and chunks;
  - `game/scenes/`: scenes and the scripts that render them;
  - `maps/`: Tiled files;
  - `tests/`.
- `.godot-version` contains the exact Godot version: `4.7.2`.
- `Makefile` with these targets:
  - `setup`:
    - checks for Godot (exact version from `.godot-version`), Tiled, Python 3 and git.
      The Godot binary name differs between installs (`godot`, `godot4`, an official
      download), so the Makefile uses `GODOT ?= godot` and can be overridden, e.g.
      `make GODOT=~/bin/Godot_v4.7.2 run`;
    - prints what is missing, with an install hint. Give Gentoo package names where they
      exist (e.g. `dev-games/godot`, `games-util/tiled`), plus a generic hint;
    - never installs system packages;
    - creates a project-local venv `.venv/` with gdtoolkit;
    - downloads the GUT and YATI (Tiled importer) addons at pinned versions into
      `addons/`;
    - is safe to run again and skips what is already there;
    - exits non-zero if something is missing.
  - `run`: starts the game.
  - `test`: runs GUT headless, and exits non-zero on a failure.
  - `lint`: runs `gdlint` and `gdformat --check`.
  - `format`: runs `gdformat`.
  - `export`: for now, prints that no export presets exist yet and exits non-zero.
- `.gitignore` covers `.godot/`, `.venv/` and export output. Decide whether to commit the
  downloaded addons or not, and write the reason in the Makefile.
- One trivial GUT test, so `make test` proves the pipeline works.

Done when, on a fresh clone, `make setup && make test && make lint` work, and `make run`
opens an empty window.

## 2. Tile state

- [x] Done

Depends on: 1.

The tile-state model from SPEC.md ("Tile state").

- A tile has:
  - a terrain type. Terrains for now: grass, soil, water, wetland, floodplain;
  - dynamic properties: water level, frozen, snow depth. They are unused for now, but
    they exist and feed into the derived values.
- Derived values come from functions of the state, never from stored flags:
  - `is_walkable`;
  - `is_buildable`: false for water, wetland and floodplain;
  - `is_plantable`.
- A chunk holds a fixed-size square of tiles (size is a constant, e.g. 32×32) and its
  chunk coordinates.
- The world holds its seed, its bounds (a maximum size in chunks, defined as one constant,
  with nothing else assuming a size) and the loaded chunks. It answers "tile at world
  position".
- GUT tests cover the derived values and the world's bounds checks.

## 3. World generation

- [x] Done

Depends on: 2.

- `WorldGenerator.new(seed).generate_chunk(chunk_coords)` returns a chunk. It is deterministic: the same
  seed and coordinates always give the same chunk, in any order.
- Use one biome (grassland), built with Godot's `FastNoiseLite`:
  - mostly grass;
  - a river or a few water bodies;
  - floodplain tiles beside the water;
  - some wetland patches.
- Chunks fit together seamlessly: noise is sampled in world coordinates, not chunk
  coordinates.
- Nothing is generated outside the world bounds.
- GUT tests:
  - determinism: generating twice gives the same chunk, and generating in a different
    order gives the same chunk;
  - nothing is generated out of bounds.

## 4. Chunk streaming and rendering

- [ ] Done

Depends on: 3.

- Display setup per SPEC.md "Lighting and look": internal resolution 384×216, 16×16
  tiles, scaled up by whole numbers only (Godot stretch mode `viewport`, integer scale
  mode), pixel snapping on, nearest-neighbour filtering. The window starts at a size
  that is a whole multiple, e.g. 1920×1080.
- A world scene renders the loaded chunks with `TileMapLayer`, using a placeholder tileset
  with one colour per terrain.
- How a tile looks is derived from its state. When a tile's state changes, its look
  updates.
- Chunks within a radius of a focus point load (generate and render). Chunks beyond a
  larger radius unload.
- The streaming logic itself (which chunks to load and unload for a position) is a pure
  function and has GUT tests.
- Performance: `Chunk.tile_at` allocates a `Tile` per call. For rendering, add direct
  read accessors on `Chunk` (e.g. `terrain_at(local)`), and redraw only chunks or tiles
  that changed, not every frame.
- While there, tidy two review notes from task 2:
  - `Tile.is_buildable` builds an array literal on each call; avoid the allocation;
  - `World.tile_at`: comment that out-of-bounds positions give null because
    `add_chunk` asserts bounds.

Done when: flying a debug camera around with the arrow keys streams chunks smoothly, with
no visible seams.

## 5. World objects: trees and rocks

- [ ] Done

Depends on: 4.

See SPEC.md "World objects (architecture)" and "Resources: trees and minerals".

- A world object has:
  - a type;
  - a tile position;
  - its own state (e.g. growth stage, hits left).
- Object types are data: name, footprint (1×1 for now), blocks walking yes/no, harvest
  level, placeholder look.
- The world stores objects per chunk. It answers "object at tile position" and supports
  adding and removing objects through explicit methods.
- Tile rules take objects into account: a tile with a blocking object is not walkable,
  and no tile with an object is buildable or plantable. Keep `Tile`'s own derived values
  as they are. Add the combined check on `World` (e.g. `World.is_walkable(pos)`).
- Generation places objects deterministically per chunk from the seed:
  - one tree type, e.g. "oak", harvest level 1, in clusters on grass;
  - one rock type, "stone", harvest level 1, scattered;
  - nothing on water, wetland or floodplain.
- Rendering: placeholder shapes on top of the tile layer, streamed with the chunks.
- No harvesting yet: that needs tools and an inventory.
- GUT tests:
  - object generation is deterministic and independent of chunk order;
  - no objects on water, wetland or floodplain;
  - the combined walkable and buildable checks respect objects;
  - adding and removing objects works.

## 6. Player and camp site

- [ ] Done

Depends on: 5.

- A top-down player character that walks in 8 directions and can't enter non-walkable
  tiles.
- The camera follows the player, and chunk streaming follows the player.
- On a new game the generator picks a start position on buildable land near the world
  centre, with no world objects in the way. It places a camp site there: a fireplace and a sleeping bag, as world objects
  in game state.
- The player starts at the camp site.
- The fireplace has a warm point light with a slight flicker, and a subtle glow. Set up
  glow once for the whole game (e.g. a `WorldEnvironment`), so later lights get it too.
- GUT test: the start position is always on buildable land, for several seeds.

## 7. Day counter and sleeping

- [ ] Done

Depends on: 6.

- Game state has a clock: day number and time of day. Time passes while playing; a debug
  key speeds it up.
- An interact key at a bed (the sleeping bag for now) sleeps:
  - each bed type has a fixed sleep duration (sleeping bag: 8 h);
  - the clock advances by that duration;
  - a new day begins whenever midnight is crossed.
- The bed last slept in is stored as the player's home.
- A minimal on-screen display of day and time.
- Day and night tint: the world's colour follows the time of day (warm morning, neutral
  noon, orange dusk, blue night), e.g. with `CanvasModulate` and a colour gradient over
  the day. Point lights from task 6 must still shine at night. The UI is not tinted.
- GUT tests:
  - the clock advances correctly on sleep, including crossing midnight;
  - home is updated.

## 8. Building placement

- [ ] Done

Depends on: 6.

- One preset building, "small house", with a fixed footprint (e.g. 4×3 tiles) and one
  door tile.
- A build mode shows a ghost of the building that follows the cursor or player and snaps
  to tiles.
- Every tile of the footprint is checked with `is_buildable`, and must have no world
  object on it. Blocked tiles are marked,
  and the message "This land doesn't look safe to build on." is shown.
- Confirming places the building in game state, and its tiles become non-walkable except
  the door.
- Customisation options and expansion points are **not** in this task. Model the building
  type as data (footprint, door position, interior map) so they can be added later.
- GUT tests:
  - placement is rejected if any footprint tile is not buildable;
  - after placement, the footprint tiles are occupied.

## 9. Interior map from Tiled

- [ ] Done

Depends on: 8.

- An interior map for the small house, made in Tiled (`maps/interiors/small_house.tmx`)
  and imported with YATI.
- Its tiles use the same terrain types as tile state, set as Tiled custom properties. The
  importer step turns them into tile state, so interiors use the same model as the world.
- Walking into the door of a placed house switches to the interior map. Walking out
  through the interior's exit returns the player to just outside the door.
- The interior has a bed. Sleeping in it works like task 7 (house bed duration: e.g.
  6 h), and makes it the new home.

Done when: you can build a house, walk in, sleep there, and walk out.

## 10. One crop

- [ ] Done

Depends on: 7.

- A crop is a world object (task 5) that keeps its growth state.
- One crop type, with a few growth stages and a number of days per stage.
- An action on a plantable tile turns grass into soil. Another action plants the crop on
  soil.
- When a day begins, every crop advances by one day.
- A fully grown crop can be harvested, which removes it. There's no inventory yet, so
  show or log the harvest count.
- Each crop stage is rendered as a placeholder.
- GUT tests:
  - growth over days;
  - harvesting only when fully grown;
  - planting only on soil.

## Later (not part of the prototype)

World generation notes from the task 3 review:

- The river is measured by vertical distance to its centre line, so it gets thin (about
  2 tiles) in steep bends. Use perpendicular distance, or a smaller meander.
- The wetland noise seed is `seed + 1`, which equals the river noise of the next seed.
  Use a large constant offset.
- More rivers, lakes or biomes: split `terrain_at` into one helper per feature instead of
  growing its if-chain.

Harvesting trees and rocks (tools, harvest levels, regrowth), saving and loading,
inventory, energy, weather, biomes, combat, reputation, building
customisation and expansions, real art.
