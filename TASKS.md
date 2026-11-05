# Tasks: Prototype

Implements milestone 1 from [SPEC.md](SPEC.md). Each task is small enough for one
developer brief. Tasks whose dependencies are done can run in parallel. The
coordinator ticks a task off here when it is merged.

Parallel plan:

1. Tasks 6 and 7 together.
2. Tasks 8 and 9 together.
3. Tasks 10 and 11 together.
4. Tasks 12 and 13 together.

Rules for every task:

- Use only make targets for build, run, test and lint. A new multi-step command gets a new
  make target.
- Keep game state (world, tiles, buildings, crops, time) in plain GDScript classes with no
  rendering or input code. Scenes only read the state and send actions to it.
- State logic gets GUT tests (`make test`). Rendering and input are checked by hand with
  `make run`.
- `make lint` passes.
- Visuals come from the art generator (task 5 on). Until a task adds art for something,
  use simple placeholder shapes in palette colours.

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
    - downloads the GUT addon at a pinned version into
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

- [x] Done

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

## 5. Art pass 1: palette and terrain tiles

- [x] Done

Depends on: 4.

See SPEC.md "Art pipeline" and "Lighting and look".

- **Generator:**
  - a Python script under `tools/art/`, using Pillow (pinned, installed into `.venv` by
    `make setup`);
  - `make assets` regenerates all PNGs under `assets/`. The output is committed;
  - output is deterministic: fixed random seeds, so a re-run gives identical files.
- **Palette:** about 32 colours, semi-fantasy/medieval: earthy greens and browns, muted
  blue water, warm fire and light accents, a few spare colours for magic later.
  - Defined once in the generator.
  - Also written as `assets/palette.png` (one swatch per colour) and a `.gpl` file, so
    drawing tools can use it.
  - Every generated pixel uses a palette colour. A test or check in `make assets`
    enforces this.
- **Terrain tiles, 16×16**, with texture rather than flat fills:
  - grass: tufts and colour variation, several variants so it doesn't look tiled;
  - soil: tilled rows;
  - water: wave highlights;
  - floodplain: damp, muddy-sandy bank;
  - wetland: dark wet ground with reeds.
- **Transitions:** use a layered dual-grid approach:
  - terrains have a priority, bottom to top: water, floodplain, wetland, grass, soil;
  - each terrain has its own `TileMapLayer`, ordered by priority and offset by half a
    tile (dual grid);
  - each dual-grid cell looks at its 4 surrounding world tiles. For layer L, the 4-bit
    mask is "which of the 4 tiles have terrain priority ≥ L". That gives 16 shapes per
    terrain (empty, corners, edges, full), with irregular, natural pixel edges;
  - the bottom layer (water) is a full fill;
  - this needs no tiles per terrain pair: 16 tiles per terrain, and adding a terrain adds
    16 tiles.
- **Renderer:**
  - replace the placeholder tileset;
  - the state → look mapping stays in one place;
  - when a tile changes, redraw the 4 dual-grid cells around it;
  - when a chunk loads, also redraw the dual-grid cells on its borders with loaded
    neighbours, so edges between chunks blend;
  - re-measure chunk load time (now several layers), and lower the per-frame cap if a
    frame goes over budget.
- Lighting and objects are not part of this task.

Done when `make run` shows textured terrain with soft transitions and no visible chunk
seams. Include a screenshot of the running game in the report (e.g. via
`get_viewport().get_texture().get_image().save_png(...)` in a debug run).

Art round 2 (branch `task-05b-terrain-art-2`, done): fertile-looking floodplain, narrower
floodplain band, irregular grass edges, lush/dry grass variety, edge variants, decoration
layer.

## 6. World objects: trees and rocks

- [x] Done

Depends on: 5.

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
- Rendering: oak and stone sprites from the art generator (add them there), drawn on top
  of the terrain and streamed with the chunks.
- No harvesting yet: that needs tools and an inventory.
- GUT tests:
  - object generation is deterministic and independent of chunk order;
  - no objects on water, wetland or floodplain;
  - the combined walkable and buildable checks respect objects;
  - adding and removing objects works.

## 7. Clock and day/night tint

- [x] Done

Depends on: 4.

- Game state has a clock: day number and time of day.
  - Time passes while playing, at a rate set by one constant.
  - A debug key speeds it up.
  - The clock can be advanced by a duration (sleeping in task 8 uses this). A new day
    begins whenever midnight is crossed, and the clock emits a "new day" signal for
    crops and other daily systems.
- A minimal on-screen display of day and time. It is not tinted.
- Day and night tint: the world's colour follows the time of day (warm morning, neutral
  noon, orange dusk, blue night), e.g. with `CanvasModulate` and a colour gradient over
  the day. Point lights (task 8) must still shine at night: check with a temporary test
  light, then remove it.
- Set up glow once for the whole game (e.g. a `WorldEnvironment`), so later lights get
  it. Keep it subtle.
- GUT tests:
  - the clock advances correctly, including crossing midnight and several days;
  - the "new day" signal fires once per new day.

## 8. Player, camp site and sleeping

- [x] Done

Depends on: 6, 7.

- A top-down player character that walks in 8 directions and can't enter non-walkable
  tiles (including tiles with blocking world objects).
- The camera follows the player, and chunk streaming follows the player. The debug
  camera from task 4 goes.
- On a new game the generator picks a start position on buildable land near the world
  centre, with no world objects in the way. It places a camp site there: a fireplace and
  a sleeping bag, as world objects in game state, with sprites from the art generator.
- The player starts at the camp site.
- The fireplace has a warm point light with a slight flicker. It gets the glow from
  task 7.
- An interact key at a bed (the sleeping bag for now) sleeps:
  - each bed type has a fixed sleep duration (sleeping bag: 8 h);
  - the clock advances by that duration (task 7).
- The bed last slept in is stored as the player's home.
- GUT tests:
  - the start position is always on buildable land with no objects, for several seeds;
  - sleeping advances the clock by the bed's duration;
  - home is updated.

## 9. Building placement

- [x] Done

Depends on: 6.

- One preset building, "small house", with a fixed footprint (e.g. 4×3 tiles) and one
  door tile.
- A build mode, toggled by a key, shows a ghost of the building that follows the mouse
  cursor and snaps to tiles. (The player isn't needed for this, so it can run in
  parallel with task 8.)
- Every tile of the footprint is checked with `is_buildable`, and must have no world
  object on it. Blocked tiles are marked, and the message "This land doesn't look safe
  to build on." is shown.
- Confirming places the building in game state, and its tiles become non-walkable except
  the door.
- The house gets a sprite from the art generator.
- Customisation options and expansion points are **not** in this task. Model the building
  type as data (footprint, door position, interior map) so they can be added later.
- GUT tests:
  - placement is rejected if any footprint tile is not buildable or has an object;
  - after placement, the footprint tiles are occupied.

## 10. Interior map from Tiled

- [x] Done

Depends on: 8, 9.

- An interior map for the small house, made in Tiled (`maps/interiors/small_house.tmx`)
  and imported with YATI (now read by InteriorLoader).
- Its tiles use the same terrain types as tile state, set as Tiled custom properties. The
  importer step turns them into tile state, so interiors use the same model as the world.
- Walking into the door of a placed house switches to the interior map. Walking out
  through the interior's exit returns the player to just outside the door.
- The interior has a bed. Sleeping in it works like task 8 (house bed duration: e.g.
  6 h), and makes it the new home.

Done when: you can build a house, walk in, sleep there, and walk out.

## 11. One crop

- [x] Done

Depends on: 6, 7, 8.

- A crop is a world object (task 6) that keeps its growth state.
- One crop type, with a few growth stages and a number of days per stage.
- An action on a grass tile turns it into soil. This is the first real tile mutation:
  give `World` an explicit mutation method that emits a change signal, and let
  `WorldView` redraw the tile from it (instead of callers remembering `redraw_tile`).
  Weather will use the same path later.
- Another action plants the crop on
  soil.
- When a day begins (the clock's "new day" signal, task 7), every crop advances by one
  day.
- A fully grown crop can be harvested, which removes it. There's no inventory yet, so
  show or log the harvest count.
- Each crop stage is rendered as a placeholder.
- GUT tests:
  - growth over days;
  - harvesting only when fully grown;
  - planting only on soil.

## 12. Two-stage rendering, camera and stepless zoom

- [x] Done

Depends on: 10, 11.

See SPEC.md "Lighting and look".

- The world (terrain, objects, player, lights, tint, glow) renders into a `SubViewport`
  at one art pixel per render pixel, sized for the widest zoom (about 640×360 plus a
  margin for sub-pixel camera offsets).
- The viewport's texture is drawn to the screen scaled steplessly, with a
  sharp-bilinear shader (sharp pixels, one blended screen pixel at pixel edges). The
  camera's sub-pixel offset is applied in this final step, so scrolling is smooth.
- UI (clock, messages, build-mode HUD) renders at native resolution, outside the world
  viewport.
- Mouse input that needs a world position (build mode) converts through both stages.
- Default view about 320×180 art pixels. The window may have any size; the final scale
  follows from it.
- A camera controller with an explicit API:
  - follow a target;
  - move to a point over a duration;
  - zoom to a value over a duration;
  - chain these into a sequence (for cutscenes later);
  - the mouse wheel zooms steplessly between 0.5× and about 2× (clamped), around the
    player.
- Remove the old 384×216 / integer-scale settings.
- Tests for the pure parts (zoom clamping, sequence timing, coordinate conversion).

Done when zooming with the mouse wheel and walking look smooth and sharp at any zoom,
and light still sits on the pixel grid.

## 13. Layered 16×32 character

- [x] Done

Depends on: 10, 11. Can run in parallel with 12.

See SPEC.md "Player" (character sprite).

- The player sprite becomes 16×32 (one tile wide, two tall), drawn from layers: body,
  clothes, head/hair, held item. Each layer is its own sprite sheet with the same frame
  layout (4 facings × idle and walk frames).
- The art generator draws each layer; one or two variants per layer to prove swapping
  works (e.g. two shirts).
- `PlayerView` stacks the layers and animates them in sync. Which layers and variants
  the player wears is plain data in player state, so gear can be added later.
- The collision body stays at the feet; y-sorting stays correct with the taller sprite.
- Tests for the pure parts (layer list from player data, frame selection).

## 14. See-through occluders

- [x] Done

Depends on: 12, 13 (works in the new render pipeline, and the circle is sized for the
16×32 character).

See SPEC.md "Lighting and look" (see-through occluders).

- When an object or building is in front of the player (sorted after the player) and its
  sprite overlaps the player, it fades inside a soft circle around the player's centre.
- Objects behind the player must not fade.
- Suggested approach: objects are drawn by a `TileMapLayer`, which can't fade single
  cells. For the few occluders near the player, hide their cell and draw them as a
  `Sprite2D` with a fade shader (circle centre, radius, opacity as uniforms) while they
  occlude; buildings are sprites already. Keep it to one small helper.
- Fade in and out over a short time, so it doesn't pop.
- Tests for the pure part (which objects occlude the player).

# Milestone 2

## 15. Saving and loading

- [x] Done

See SPEC.md "Saving (first version)" and "World edits (architecture)".

- One explicit serializer (`to_dict` / `from_dict` style) for each state class that needs
  it: GameState, World (seed, terrain and object edits, buildings), Building (incl. its
  interior if created), Interior, WorldObject (type, position, state), PlayerState
  (position, facing, current map, home bed and map, appearance), GameClock, harvest count.
- JSON file per world under `user://saves/`, with a format version number.
- Autosave after sleeping and when the game quits; load on start if a save exists;
  `--new-game` forces a new game.
- Loading regenerates chunks from the seed and replays the edits, as streaming already
  does.
- Tests: round trip (save → load → equal state) for every class, including a crop's growth,
  a removed tree, tilled soil, a building with a visited interior, home in the interior
  bed; loading an older/unknown version fails with a clear error.

## 16. Art scale pass

Split into three tasks that can run in parallel. Numbers and reasons:
`docs/art-review-2026-11-05.md`. All follow SPEC.md "Art pipeline" style rules.

Screenshots: the tiling window manager makes windowed screenshots portrait; take them
fullscreen (`godot --path . -f -- --new-game --save-path=<scratch> --settings-path=<scratch>
--screenshot=... --at=...`; the scratch settings path keeps the player's stored display mode
from overriding `-f`).

### 16a. Objects: trees, bushes, stones, camp, crops

- [x] Done

- Redraw at the target sizes: oak, spruce, pine, dead tree, berry bush, shrub, fern bush,
  sapling, fireplace (with logs), sleeping bag (1×2 tiles, vertical), turnip stages.
  Include the review's improvements for these (oak crown lobes, fern fronds, sapling
  trunk and stake, sleeping bag pillow and fold), the outline rule and contact shadows.
- New object: boulder on 2×1 tiles, higher harvest level. Multi-tile objects need
  footprint support in the object data and the walk/build checks.
- Object atlas cells: per-row cell sizes from the type data (small 32×32, trees 48×80),
  or one uniform 48×80 cell — whichever stays simpler.
- Update `sprite_height`, and add the test that each is at least the opaque height in
  the atlas. Widen the see-through radius to about 2 tiles.
- Campfire light: deeper orange (~1.0, 0.5, 0.22), energy 1.2–1.6, so grass doesn't turn
  lime and the character isn't bleached. Dusk tint: warmer, less olive (see review §2.3).

### 16b. Character

- [x] Done

- Figure 27–28 px tall in the 16×32 frame (head 9×8), feet on the bottom row.
- Coloured inner lines (keep the outer outline), hoe in `soil_dark`, nose pixel and arm
  swing in side views, 4-frame walk cycle.
- All layers and both outfits.

### 16c. House and interior

- [x] Done

- House: 5×3 footprint, sprite about 80×96 in 3/4 view (ridge, slope, eaves), straw
  thatch, door 14–16 × 24–26 on the middle tile (door_offset (2,2)) with frame and step,
  windows with sills, chimney, shadow under the eaves, darker right wall.
- Lit windows at night: a lit window variant plus a small warm point light, on when the
  tint is dark.
- Interior in 3/4 view: back wall as a 2-tile wall face with plaster, wainscot, window and
  beam; side and front walls as thin top rims; room 7×5 floor tiles; furniture: bed on
  1×2, table on 2×1 with two stools, doormat, hearth (light source), chest. Update the
  Tiled map and tileset.

## 17. Mouse tile targeting

- [x] Done

See SPEC.md "Player" (tile targeting with the mouse).

- The use highlight follows the tile under the mouse (through
  `CameraController.mouse_world_position()`).
- Reach: the 3×3 tiles around the player's tile (a constant; tools may change it later).
  In reach: normal highlight, and left click or Space uses that tile. Out of reach:
  translucent red highlight, no action.
- Mouse idle for about 3 s: the highlight fades out over about 0.5 s and the target falls
  back to the facing tile (keyboard play). Moving the mouse brings the mouse target back.
- Build mode keeps its own mouse handling; no use action while it's active.
- The targeting rule (which tile, in reach or not, which source) is a pure function with
  tests.

Parallel plan for 18–22: 18 and 19 together; 20 after 18; 21 and 22 together after 20.

## 18. Inventory, hotbar and starting tools

- [x] Done

See SPEC.md "Player" (inventory and equipment, tools).

- State: `Item` types as data (name, icon, weight, stack limit; tools with a level), an
  `Inventory` of 20 slots (first 10 the hotbar) with add (stacks, then free slots;
  reports what didn't fit), remove, move/swap, total weight, and the selected hotbar
  slot. Saved and loaded with the rest of the game; version-1 saves still load (their
  harvest count becomes turnips).
- New game: hoe, axe, pickaxe, watering can, 15 turnip seeds.
- The use action acts with the held item: hoe tills grass, seeds plant on soil (one seed
  used), empty hand harvests a ripe turnip into the inventory. Until a shop exists, a
  harvest also gives one seed back. Axe, pickaxe and watering can do nothing yet (task
  20). The use highlight only shows where the held item can act. The held-item layer of
  the character shows the held tool (hoe art exists; others can wait for their art).
- Keys 1–0 select a hotbar slot (input actions `hotbar_1` … `hotbar_10`, so task 19's
  controls screen picks them up). The inventory screen opens with Tab (action
  `inventory`); click an item, then click a slot to move or swap it.
- UI: hotbar at the bottom centre (10 slots of 20×20, selected slot marked, stack counts),
  inventory screen with all 20 slots. Replaces the harvest counter.
- Art: 16×16 icons for hoe, axe, pickaxe, watering can, turnip seeds, turnip; slot art
  (normal, selected). Put new art code in its own module next to `generate.py`.
- Tests: stacking, full inventory, move/swap, weight, using each tool, save round trip,
  loading a version-1 save.

## 19. Pause menu and settings with key bindings

- [x] Done

See SPEC.md "Menus and settings".

- Escape opens the pause menu (leaving build mode first); the game pauses. Buttons:
  Resume, Settings, Save and quit. Mouse and keyboard work in all menus.
- Settings → Controls: every game action (all actions in the project's input map except
  Godot's `ui_*` ones), with a readable name and its up to two bindings. Rebinding:
  click, press a key or mouse button, Escape cancels. Conflicts move the key and say so.
  Reset to defaults.
- Settings → Display: fullscreen / windowed.
- Settings saved to and loaded from `user://settings.cfg` at start; a bad file is ignored
  with a warning.
- UI look: a pixel bitmap font (5×7 or 6×8, generated or open licence), a 9-slice panel
  frame, buttons, all in one shared Theme with palette colours, used by the menus and the
  clock HUD. Put new art code in its own module next to `generate.py`.
- Tests: the settings file round trip, rebinding and conflict rules, defaults reset (as
  plain logic outside the UI).

## 20. Felling, mining and foraging

- [x] Done

Depends on: 18. See SPEC.md "Resources: trees and minerals" (felling and mining).

- Hit points per object type and power per tool level; hits needed = ceil(hp / power).
  Damage is object state (saved). A short shake on each hit.
- Below the harvest level: no damage, a message ("Needs a better axe.").
- Drops into the inventory (what doesn't fit lands on the ground later; for now a
  message "Inventory full"): wood, sapling (chance), stone, fibre, berries. Item types
  and 16×16 icons for each.
- Stump object after felling (art 20×12), regrows into a sapling, then the tree, over
  days. Berry bush keeps a picked state and bears again after a few days.
- Saplings can be planted from the inventory.
- Tests: hits per level, harvest level gate, drops, stump regrowth, bush regrowth, save.

## 21. Energy and health

- [ ] Done

Depends on: 20. See SPEC.md "Player" (energy, details).

- State: energy and health (0–100) on the player, saved. Action costs, the weight rule,
  sleep fill per bed and food values come from `data/energy.cfg` (ConfigFile, comments
  explain each value), loaded once; tests use their own values.
- Every use costs energy by kind (tool use 2, planting and picking 0.5), times the weight
  factor, times the energy drain factor (a plain number on the state, default 1; task 22
  connects the setting). An action with too little energy left still happens; energy
  drops to 0 and the player passes out.
- Walking speed: ≤10 % energy 75 %, <5 % 50 %, debuff day 50 %; the slowest wins.
- Passing out: fade, wake in the home bed at 06:00 the next day, debuff that day (half
  speed, energy max 50 %, health 25). Sleeping refills energy and health per bed.
- Eating: use with food held (berries, turnips) eats one and restores energy.
- HUD: energy and health bars next to the hotbar with icons, pulsing at 20 % or less.
  Art: bar frame and fills, 12×12 icons.
- Tests: costs and weight factor, drain factor, slowdowns, passing out and the debuff
  day, sleep refills, eating, save round trip, loading the data file.

## 22. UI scale and the Game settings page

- [ ] Done

Depends on: 19. See SPEC.md "Menus and settings".

- Settings → Game: UI scale slider 0.5×–2× in steps of 0.25, applied at once to all UI
  (HUD, hotbar, inventory, menus), not to the world view; and energy drain Low / Normal /
  High (×0.5 / ×1 / ×1.5), stored for task 21.
- Both saved in `user://settings.cfg` like the other settings.
- Tests: the settings round trip and defaults.

## Later (not part of the prototype)

- Split the object edits and regrowth (`_object_edits`, `replace_object`, `hit_object`,
  `change_object`, `pass_night`) out of `World` into their own class with their own tests,
  and drop the `max-public-methods` lint exception in world.gd.
- Edits of objects that are back to their generated state (a healed tree) stay in the
  save; harmless, bounded by what the player touched.
- Held art and use poses for axe and pickaxe; a "+4 wood" note on drops.
- A planted sapling can be picked up again by hand for free; decide whether that's fine.

- Floodplain farming: floodplain is the most fertile farmland, but only grass can be tilled
  now. Tilling it needs a "tilled" tile property that keeps the floodplain flag, so floods
  can still act on it.

Art notes from the art round 2 review and look:

- Extra vegetation (done, branch `extra-vegetation`): spruce, pine, dead tree, berry bush,
  shrub, sapling, fern bush; joined trunks, ground shadows, 32×48 object cells. Fern and
  sapling sprites are still plain.
- Dusk (18:30) comes out olive and muddy rather than warm orange; tune the tint gradient.
- Lush and dry grass areas look blotchy; dry should differ in hue (yellower), not only
  brightness.
- The grass texture is busy (many dark marks).
- `tools/art/generate.py`: shared sprites (pebbles, fern, clover, brown caps) are defined
  several times; move them to module level. Add a small `size(picture)` helper.
- No test yet that `redraw_tile` redraws decorations and unload erases them.

Art scale pass notes (16a–16c reviews and look):

- Pines read as olive-brown blobs with stubby trunks inside forests.
- The sleeping bag (1×2, vertical) reads like an upright sign behind the player; it should
  look flat on the ground. The character's face turns slightly pink at night.
- Seed mound and sprout stages are plain; the hoe is a thin stick from front/back.
- A grass tuft can stay under a boulder's right half at the load frontier (hidden).
- Saves from before 16a put the 1×1 bag where the new spawn is; `add_chunk` replay checks
  only the origin tile of multi-tile objects.
- Interior: the table reads like a chest, the chest is hard to identify, the bed is flat,
  the floor boards are very high contrast.

Saving notes from the task 15 review:

- A version-1 save with valid JSON but missing keys or bad references hits asserts in
  `from_dict`; fine while only the game writes saves, but handle gracefully before players
  edit or share saves.
- Only closing the window saves; Ctrl-C/SIGTERM doesn't.
- `--new-game` without `--save-path` replaces the real save on quit (intended).

See-through notes from the task 14 review:

- `sprite_height` on tree types is hand-set and 1–2 px under the art for oak and dead tree.
  Add a test that each declared height is at least the opaque height in the atlas.
- `Occlusion.building_rect` calls `load()` and `world.buildings()` copies the array every
  frame; cache texture sizes per building sprite.
- A swapped sprite may change draw order against a same-row neighbour tree (small pop).
- Skip `_update_see_through` while inside a building.

Performance notes from the task 6 review:

- Loading a chunk takes about 8 ms on average, with spikes up to 16 ms when crossing a
  chunk border. Profile `_load_chunk` first. Likely fixes, cheapest first: generate
  chunks on a `WorkerThreadPool` task (generation is pure); split drawing over frames;
  skip `set_cell` for layers a cell doesn't use.

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
