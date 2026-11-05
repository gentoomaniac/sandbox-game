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

- [ ] Done

Depends on: 2.

- `generate_chunk(seed, chunk_coords)` returns a chunk. It is deterministic: the same
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

## 5. Player and camp site

- [ ] Done

Depends on: 4.

- A top-down player character that walks in 8 directions and can't enter non-walkable
  tiles.
- The camera follows the player, and chunk streaming follows the player.
- On a new game the generator picks a start position on buildable land near the world
  centre. It places a camp site there: a fireplace and a sleeping bag, as world objects
  in game state.
- The player starts at the camp site.
- GUT test: the start position is always on buildable land, for several seeds.

## 6. Day counter and sleeping

- [ ] Done

Depends on: 5.

- Game state has a clock: day number and time of day. Time passes while playing; a debug
  key speeds it up.
- An interact key at a bed (the sleeping bag for now) sleeps:
  - each bed type has a fixed sleep duration (sleeping bag: 8 h);
  - the clock advances by that duration;
  - a new day begins whenever midnight is crossed.
- The bed last slept in is stored as the player's home.
- A minimal on-screen display of day and time.
- GUT tests:
  - the clock advances correctly on sleep, including crossing midnight;
  - home is updated.

## 7. Building placement

- [ ] Done

Depends on: 5.

- One preset building, "small house", with a fixed footprint (e.g. 4×3 tiles) and one
  door tile.
- A build mode shows a ghost of the building that follows the cursor or player and snaps
  to tiles.
- Every tile of the footprint is checked with `is_buildable`. Blocked tiles are marked,
  and the message "This land doesn't look safe to build on." is shown.
- Confirming places the building in game state, and its tiles become non-walkable except
  the door.
- Customisation options and expansion points are **not** in this task. Model the building
  type as data (footprint, door position, interior map) so they can be added later.
- GUT tests:
  - placement is rejected if any footprint tile is not buildable;
  - after placement, the footprint tiles are occupied.

## 8. Interior map from Tiled

- [ ] Done

Depends on: 7.

- An interior map for the small house, made in Tiled (`maps/interiors/small_house.tmx`)
  and imported with YATI.
- Its tiles use the same terrain types as tile state, set as Tiled custom properties. The
  importer step turns them into tile state, so interiors use the same model as the world.
- Walking into the door of a placed house switches to the interior map. Walking out
  through the interior's exit returns the player to just outside the door.
- The interior has a bed. Sleeping in it works like task 6 (house bed duration: e.g.
  6 h), and makes it the new home.

Done when: you can build a house, walk in, sleep there, and walk out.

## 9. One crop

- [ ] Done

Depends on: 6.

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

Saving and loading, inventory, energy, weather, biomes, combat, reputation, building
customisation and expansions, real art.
