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

Parallel plan for 18–22: 18 and 19 together; 20 after 18; 21 and 22 together after 20. 23 after 22.

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

- [x] Done

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

- [x] Done

Depends on: 19. See SPEC.md "Menus and settings".

- Settings → Game: UI scale slider 0.5×–2× in steps of 0.25, applied at once to all UI
  (HUD, hotbar, inventory, menus), not to the world view; and energy drain Low / Normal /
  High (×0.5 / ×1 / ×1.5), stored for task 21.
- Both saved in `user://settings.cfg` like the other settings.
- Tests: the settings round trip and defaults.

## 23. Character screen with equipment

- [x] Done

See SPEC.md "Player" (character screen).

- State: equipment slots (head, body, legs, feet, back, main hand, off hand) on the
  player, saved; wearable item types with a slot and a character layer variant; equip,
  unequip and swap with the inventory, only into fitting slots; worn items in the total
  weight. Older saves get the default outfit worn.
- Appearance follows the equipment: each slot is a layer; an empty slot draws nothing.
  The body layer must look decent with nothing worn.
- Items: tunic and shirt (body, the two existing clothes sheets), trousers (legs), straw
  hat (head, new layer art in all facings and frames). Icons for all four.
- Screen: Tab opens it, replacing the inventory screen. Character preview (large, facing
  the viewer) with the slots around it; the inventory grid beside it; empty slots show a
  faint outline of what fits; click to pick up and put down, fitting slots light up,
  right-click quick equip/unequip.
- Tests: equip, unequip, swap, wrong slot refused, weight, save round trip, older save.

## 24. Console with cheat commands

- [x] Done

See SPEC.md "Console". Can run alongside 23.

- Command parsing and execution as plain logic (a Console state class: parse a line,
  run it against GameState, return output lines), tested without UI.
- Commands: help, tp, give (with Tab completion of item ids), god, nodrain, noweight.
  Errors say what was wrong ("Unknown item: wod").
- GameState gets the session-only cheat flags; energy costs and health changes respect
  them.
- UI: an input line and a scrolling log at the top of the screen in the UI theme; `/`
  opens it (action `console`); history with up/down; HUD line for active cheats.
- Tests: parsing, each command, bad input, the cheats' effect on energy and health.

## 25. Seasonal look

- [x] Done

See SPEC.md "Time, seasons and weather" (calendar, the world looks like its season).

- The art generator makes a variant of the terrain, decoration and object art per season:
  summer is today's art; spring lighter and fresher green (blossom on some bushes);
  autumn orange/red/yellow foliage on deciduous trees and bushes, yellower grass;
  winter snow on the ground, snow-capped evergreens and boulders, bare deciduous trees,
  snow on the house roof. Water stays as it is (freezing belongs to weather).
- The world view uses the current season's art and switches when the season changes
  (at the new day), without reloading chunks if possible.
- Palette: add the colours the seasons need; the cap may rise to about 64.
- A debug flag to start on a given day (e.g. `--day=<n>`), for screenshots.

## 26. Weather state and effects

- [x] Done

See SPEC.md "Time, seasons and weather" (weather state).

- State: a Weather class (plain logic) answering `at(region_or_position, day, minute)`
  with humidity, wind (speed and direction), temperature and sunlight, plus derived
  conditions with intensities (rain, snow, fog, wind, storm, lightning). Deterministic
  from the world seed; season baselines and the daily cycle as data in a hand-editable
  file (`data/weather.cfg`). The world state holds it; GameState exposes the current
  weather at the player.
- Effects (visual only): rain, snow, fog, wind streaks/leaves, lightning flash, overcast
  dimming through the day/night tint. Drawn on the art-pixel grid; nothing inside
  buildings; smooth transitions as values change.
- Console: `weather` prints the current values and conditions; `weather <condition>`
  forces one for testing (session only), `weather auto` returns to the simulation.
  The F3 display also shows the values. Debug flag `--weather=<condition>`.
- Tests: determinism, season baselines (e.g. snow possible in winter, never in summer),
  the daily cycle, condition thresholds, the console command.
- Added 2026-11-05: day length over the year (a Sun model: sunrise and sunset per day,
  scaled by the "Day length variation" setting on the Game page) drives the day/night
  tint and the weather's sunlight; season baselines as a smooth yearly curve with rare
  out-of-season spells; temperature follows the sun (warmer while it's up, clouds damp
  the swing).

## 27. Seasonal vegetation density

- [x] Done

Depends on: 25. See SPEC.md "Vegetation density follows the year".

- Decoration density per kind as a smooth yearly curve (data file), with a per-spot
  threshold from PositionHash, so ground cover thins and fills gradually.
- Seasonal world objects (fern bush and other soft plants) with a dormant period derived
  from the day and a per-object threshold: not drawn, not blocking, not harvestable
  while dormant; woody plants unchanged.
- Berry bushes fruit only from early summer to late autumn (per-bush start and end);
  outside it they show the berry-less look and can't be picked.
- The view updates once per day (not every minute), only the chunks that are loaded.
- Tests: the curves, gradual change across days, dormancy of a fern in winter and its
  return in spring, harvesting unaffected otherwise, save/load.

## 28. Ambient wildlife

- [x] Done

Depends on: 26 (weather), ideally 27 (flowers present by season). See SPEC.md
"Ambient wildlife".

- Spawn rules as plain logic: kind, terrain, time of day, season, weather, distance to
  the player, a cap per kind; animals appear out of view or at its edge and vanish far
  away.
- View nodes with small state machines: birds (peck, hop, fly off, flocks with shadows),
  rabbits (hop, flee in zigzags), squirrels (dart, sit up, scurry), deer (graze, look up,
  bound away; rare, dawn and dusk), bees (hover at flowers), butterflies (flutter over
  meadows).
- Art at the sizes in the spec, a few frames each, palette only; seasonal coats only if
  cheap.
- Y-sorted with the player and objects; see-through trees still work; nothing inside.
- Tests: the spawn rules (no insects in winter, none in a storm, deer only in or near
  forest, caps), fleeing distance.

## 29. Season blending, weather-driven snow and frost

- [x] Done

Depends on: 25, 26, 27. See SPEC.md "Seasons fade into each other; snow and frost come
from the weather".

- Snow cover (0..1, per weather region) integrated from the weather history (snowfall
  adds, warmth and sun melt), deterministic and cached; queryable for any time.
- Per tile and per object a threshold (PositionHash); the view picks the art variant per
  tile/object: season blend for foliage and grass (a blend factor around each season
  boundary), snow where cover is above the threshold, frost when cold without snow.
- Art: a bare, snowless winter look (brown-grey grass, bare deciduous trees, evergreens
  without snow), a frost look, and the snow look from task 25 as the snow variant.
- Refresh only tiles whose variant flips; snow and frost may change hourly, so spread
  refreshes over frames if needed.
- Tests: snow builds and melts with the weather, gone at spring start, patchy thaw over
  2–3 days, frost only below 0 °C without snow, blend fractions across boundaries.
- Done as: six looks (spring, summer, autumn, bare, frost, snow) made by the generator; the
  base terrain is summer and each look is a dual-grid overlay layer over it (soft edges, no
  seams); decorations, objects and houses switch atlas source per look. `data/seasons.cfg`
  holds the blend windows and the snow and frost numbers; `SnowCover`, `SeasonBlend` are the
  plain logic. Console `snow <0..1>|auto`, flag `--snow=<n>`, F3 shows cover and frost. The
  palette is at 64 (autumn/autumn_dark merged into reed/olive; bare-ground and frost colours added).
  A seventh look, "dusting", is the thin fringe of snow (tiles whose threshold is just above the
  cover); the snow threshold is slightly clustered in space so patches and fringes form.

## 30. More crops, grown by the weather

- [x] Done

See SPEC.md "Farming and foraging" (crops).

- data/crops.cfg (required keys, fails loudly): per crop its sheet, needs (temperature
  min/best/max, daily sunlight, soil moisture, wind tolerance), growth needed per stage,
  yield, regrowth, seed and produce items. Eleven crops; turnip moves into the file.
- One sheet per crop in assets/crops/ (4 growth stages + dead), loaded from the config,
  so new crops need no code.
- Soil moisture per tilled tile (saved): rain, watering can (now works), drying by
  temperature, sun and wind; darker look when wet.
- Nightly growth from the day's weather (aggregated per day and region) and the soil
  moisture; damage from drought, darkness, frost and wind; death shows the dead stage.
- Food values for the produce; seed bag and produce icons.
- Tests: growth under good, poor and bad days; each death cause; wind-fragile crops;
  moisture from rain and watering, drying; regrowth; save/load; the data file.

## 31. Console: completion for all arguments

- [x] Done

Depends on: 28 (it adds `spawn`). Tab completes every command's arguments, not only
command names and item ids: weather conditions, animal kinds, snow values, crop and item
ids, and so on, from one table of argument kinds per command.

## 32. Hit feedback: shake, leaves, snow and splinters

- [x] Done

See SPEC.md "Harvesting, reworked" (hit feedback). Visual only.

- Every hit shakes the object, the finishing hit too (today the last one swaps it at once).
- A small pixel-particle node in the world viewport (on the art grid, tinted by the day
  like the world): a few leaves from a tree with foliage in its current look (needles for
  spruce and pine all year), a puff of snow from a snowy tree, nothing from a bare one;
  5–7 small splinters arcing out of stone and boulders.
- A debug flag to show a hit for screenshots.
- Tests: which effect a hit on each object type and look gives.

## 33. Final resources lie on the ground

- [x] Done: `World.drop_items(source_tile, {item: count})` is the entry point (piles of one
  kind over the free walkable tiles within 1 tile, then 2, ordered by `PositionHash`);
  `GameState.collect_ground_items(delta)` pulls piles within half a tile and picks them up;
  GroundItemView draws them with the 8x8 icons of `assets/ground_items/`. Saves are version 3.
  `--drops=<x>,<y>` shows drops for screenshots.

See SPEC.md "Harvesting, reworked". Can run alongside 32.

- Ground items: an item id and count at a world position, drawn as the item's icon (small)
  in the world, saved, collected by walking over them with a short pull in the last half
  tile; with a full inventory they stay.
- Everything the world gives drops on the ground instead of going into the inventory:
  felling and mining, crop harvests, picking bushes, shrubs and ferns. Drops scatter over
  the free tiles around the source.
- The item `wood` becomes `logs` (icon, recipes, console, saves).
- Tests: drops land on the ground, collection, full inventory, save/load, old saves with
  `wood`.

## 34. Trees leave trunks, stumps rot, seeds per species

- [x] Done

Depends on 33. See SPEC.md "Harvesting, reworked".

- Felling leaves the stump and a trunk object (2×1, lying away from the player, 1×1 if
  there is no room); the axe cuts the trunk into logs and chops out the stump for 1 log.
  Art for trunks per species and for the seeds.
- Stumps no longer regrow: they rot away over about two weeks (a look or two on the way),
  then leave a sapling of their species with about 30 % chance.
- Per-species seeds (acorn, spruce cone, pine cone) dropped by felling living trees (about
  25 %); planted on grass they grow into a sapling of that species, then the tree. The
  generic sapling item goes away (old saves: turn it into acorns).
- Tests: felling, trunk placement and fallback, logs, rotting and the sapling roll, seeds
  growing into the right species, save/load.

## 35. Scythe and tall grass, shovel and clay

- [x] Done: tall grass is a seasonal object (`tall_grass` in data/vegetation.cfg, dormant in
  winter) generated in meadows; mowing is `Use.MOW` (`GameState.mow_tiles`), a mown tuft is
  "picked" and regrows after `regrow_days`. Clay spots are `WorldGenerator.is_clay_spot`;
  `World.has_clay` / `spend_clay_spot` keep the spent ones (saved as `spent_clay_spots`, optional
  in version 3 saves, so no version bump); `Use.DIG` is the shovel. `mow` and `dig` costs are in
  data/energy.cfg. Art is a placeholder in tools/art/meadow.py (to be redrawn);
  `--mow=<x>,<y>` mows for screenshots. Tall grass is `clearable`: the hoe, planting and building
  remove it without a drop (`World.is_free_on`, `placement_blockers`).

Depends on 33. See SPEC.md "Scythe and tall grass" and "Shovel and clay".

- Tall grass objects in meadows with a vegetation curve (none in winter); the scythe mows
  4 tiles (2 ahead, plus left and right of the nearer one); hay on the ground; regrowth.
- Clay spots near rivers, lakes and wetland from noise, hinted by a faint decoration; the
  shovel gives clay there by chance and spends the spot for some days.
- Scythe, shovel, hay and clay items with icons; scythe and shovel in the starting items.
- Tests: the mowing pattern for each facing, regrowth, the seasons of tall grass, clay
  spot placement, digging odds and the spent spot, save/load.

## 36. Buildings from a config, with costs and the hammer

- [x] Done

See SPEC.md "Building and land" (first buildings, costs, hammer, buildings.cfg).

- data/buildings.cfg (required keys, fails loudly) replaces the table in
  building_types.gd: shack, Kate, longhouse and barn with footprint, door, pictures,
  interior map, window lights, costs and documented future attributes.
- The hammer item (starting items, console); holding it is build mode; Q/E (rebindable)
  pick the building; B selects the hammer; a small panel shows the name and the costs
  against the inventory; placing takes the materials; a spot is refused while something is
  missing.
- Old saves: `small_house` becomes the Kate.
- Placeholder pictures and interiors until 38 and 39 (the existing house and interior may
  stand in, scaled to the footprints).
- Tests: the data file, costs taken, refusal when short, picking, the save upgrade.

## 37. Reeds on the banks

- [x] Done

See SPEC.md "Reeds". Can run alongside 36.

- Reed objects in stands along river and lake banks and wetland edges (world generator),
  looks per season; the scythe cuts them into reeds on the ground.
- A reeds section in data/crops.cfg with its growing needs; cut reeds regrow by daily
  growth from the weather (as crops do), so only in their season.
- The reeds item (icon, ground icon), placeholder art.
- Tests: placement near water only, cutting, regrowth in season and none in winter,
  save/load, the data file.

## 38. Art pass: buildings and the new sprites

- [ ] Done

Depends on 36 and 37. Opus. The four buildings (every season, snow, lit), and everything
that has placeholder art: trunks, stumps, tree seeds, tall grass (and mown), reeds, the
clay hint, and the icons for hay, clay, reeds, scythe, shovel and hammer. Also redraw the
dead tree: it reads as thin brown and grey scribbles with no trunk. It should be a solid,
weathered grey trunk with a few thick, gnarled, broken-off limbs, bark shading on one
consistent light side, and a ground shadow, in the scale of the other trees. Redraw all seven tool icons
(hoe, axe, pickaxe, watering can, scythe, shovel, hammer): today they are flat grey shapes on
thin sticks that don't read as their tools (the axe was taken for a shovel); each needs a
silhouette that names it alone, filling the icon on the diagonal.

## 39. Interiors for all four buildings

- [ ] Done

Depends on 36. A Tiled interior per building (see InteriorLoader), sized to its footprint:
the shack bare and small, the Kate a cottage room with hearth and bed, the longhouse with
a hall and living end, the barn with stalls and storage and no bed or hearth. Until then
all four buildings in data/buildings.cfg use maps/interiors/small_house.tmx, and
tests/test_interior.gd still builds its checks on that map under the old name.

## 40. Sound generator

- [x] Done

See SPEC.md "Sound". A script in tools/audio/ (run by `make assets`, deterministic) that
writes every sound event of the list below as WAV files with 2–4 variants each, loops
marked for looping. Event names (also the keys of data/sounds.cfg in task 41):
step_grass, step_soil, step_sand, step_wetland, step_ice, step_snow, step_wood;
axe_chop, tree_fall, pickaxe_hit, stone_break, scythe_swish, shovel_dig, hoe_till,
water_pour, plant, pick_bush, item_pickup, build_place, denied; ui_click, ui_open,
ui_close, hotbar_select; rain_loop, wind_loop, wind_gust, thunder; bird_chirp,
frog_croak, deer_snort, deer_hooves, rabbit_rustle, squirrel_chatter, bee_buzz_loop.

## 41. Sound system and game sounds

- [ ] Done

Depends on 40. data/sounds.cfg (required keys: files, volume, pitch range per event);
an audio service with Master/Effects/Ambience buses, positional players for world sounds
and a muffle while inside; the Audio settings page (three sliders, "Sound in background");
footsteps by ground, work sounds, item pickup, building placed, denied, UI sounds.

## 42. Ambience: weather and animals

- [ ] Done

Depends on 41. Rain and wind loops following the weather with fades, gusts, thunder
after the flash with a delay; birds chirping from their nodes now and then, deer, rabbit,
squirrel and bee sounds; frogs near water by season, time of day, temperature and
distance.

## 43. Harvest animations: falling trees, items hopping out

- [ ] Done

See SPEC.md "Harvest animations". View only. Depends on the season tiling fix being
merged (both touch world_view.gd).

- A felled tree topples away from the player onto its trunk's side, about 0.6 s, easing
  in, with leaves or snow bursting on impact (HitParticles) and the stump shaking; the
  trunk object is drawn only when the fall ends.
- Ground items appear with a hop: from the source tile in an arc (a few pixels high) to
  their landing spot, a small bounce, staggered a little when several drop at once. For
  every harvest: trunk, stump, stone, boulder, tall grass, reeds, clay, crops, bushes.
- Collecting during a hop still works; save/load and the state are untouched.
- A debug flag to capture the fall and the hops; tests for the timing and that the state
  is final at once.

## 44. Tooltips

- [ ] Done

See SPEC.md "Menus and settings" (tooltips). A tooltip panel in the shared theme, shown
after a short hover and kept on screen at any UI scale; item tooltips for hotbar,
inventory and equipment slots built from the data (ItemTypes, energy.cfg food values,
tool levels, CropRules for seeds and produce, equipment slots), with a `description` per
item; short explanations for every setting. Tests: the text for food, a tool, seeds, a
plain resource and equipment.

## Later (not part of the prototype)

- Season looks follow-ups (from the task 29 review): world_view.gd carries layer, season
  look and weather look as three parallel arrays with the corner assembly written out
  several times; fold them into one packed per-tile code. SeasonBlend's four boundaries
  as a loop over SeasonRules.BOUNDARIES; `frost_at` belongs with the season rules, not
  SnowCover. SnowCover's cold start (~80 ms for a fresh region in late winter) could be
  spread over frames. Snow cover of the player's region is applied to the whole loaded
  world for now.

- Split the object edits and regrowth (`_object_edits`, `replace_object`, `hit_object`,
  `change_object`, `pass_night`) out of `World` into their own class with their own tests,
  and drop the `max-public-methods` lint exception in world.gd.
- Edits of objects that are back to their generated state (a healed tree) stay in the
  save; harmless, bounded by what the player touched.
- Ground items (task 33 review): `World.ground_items_near` scans every pile each frame
  (fine for tens, not hundreds; piles never expire): bucket per tile or chunk. A pile that
  falls back onto a non-walkable source may be out of reach. A pulled pile moves straight
  through walls and water in its last half tile.
- Task 35 review: time a chunk load with the clay probe and hint layer against the ~14 ms
  baseline; a mown tuft stays an object edit forever after it regrew (drop edits that are
  back to their generated state); ResourceCase `_hold` could just select a hotbar slot.
- Held art and use poses for axe, pickaxe, scythe and shovel.
- A planted sapling can be picked up again by hand for free; decide whether that's fine.
- The shovel could later dig up a young sapling to move it.

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
