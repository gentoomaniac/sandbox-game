# Tasks: done

The finished tasks, moved here with their full text from [TASKS.md](../TASKS.md) when they are
merged (tasks 1 to 51 first, the rest from 2026-11-09 on); their numbers still mean the same.

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
`docs/archive/art-review-2026-11-05.md`. All follow SPEC.md "Art pipeline" style rules.

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
  A season's look has a lush and a dry grass overlay layer stacked over its ordinary one, each
  shaped by its own corners like the terrain layers (otherwise a cell with one lush corner got
  a full lush tile: straight-edged blocks); where one has the same mask as the layer below it,
  only the upper is drawn, since both edges together show as a fringe.

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

- [x] Done

Also redrew all seven tool icons (hoe, axe, pickaxe, watering can, scythe, shovel, hammer) on
the item diagonal in one metal ramp (tools/art/tool_icons.py), and the acorn and cones. The
buildings follow the user's reference photos (see SPEC.md "Building and land"). No palette
change was needed.

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

- [x] Done

Depends on 36. A Tiled interior per building (see InteriorLoader), sized to its footprint:
the shack bare and small, the Kate a cottage room with hearth and bed, the longhouse with
a hall and living end, the barn with stalls and storage and no bed or hearth. Until then
all four buildings in data/buildings.cfg use maps/interiors/small_house.tmx, and
tests/test_interior.gd still builds its checks on that map under the old name.

Done: maps/interiors/{shack,kate,longhouse,barn}.tmx (6x6, 9x8, 15x8, 13x8 tiles), each
building pointing at its own in data/buildings.cfg; small_house.tmx is now kate.tmx. New
furniture: sleeping_mat (shack, sleep fill 80), box_bed (longhouse, 100), bench, stall_partition,
hay_pile, barrel, sacks, crate. Saves store an interior's content, not its map, so old saves
load unchanged (a Kate keeps the old room); the version 5 upgrade needed no change.

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

- [x] Done

Depends on 40. data/sounds.cfg (required keys: files, volume, pitch range per event);
an audio service with Master/Effects/Ambience buses, positional players for world sounds
and a muffle while inside; the Audio settings page (three sliders, "Sound in background");
footsteps by ground, work sounds, item pickup, building placed, denied, UI sounds.

Done: AudioService is a node owned by Main (`Main._audio`), wired up by GameSounds. Buses:
Master, then Effects, Ambience and UI; plus OutsideEffects, which sends to Effects. Ambience
and OutsideEffects carry the low-pass filter that fades in inside a building, so task 42 plays
the world's effects with `play(event, position, true)` (is_from_outside) and loops with
`start_loop(event, position, level)`, whose handle fades and stops. `--sound-log` prints every
event as it plays. `PlayerView.walk_speed` scales the walk animation, and with it the steps;
`tree_fall` plays on `WorldView.tree_landed`.

## 42. Ambience: weather and animals

- [x] Done

Depends on 41. Rain and wind loops following the weather with fades, gusts, thunder
after the flash with a delay; birds chirping from their nodes now and then, deer, rabbit,
squirrel and bee sounds; frogs near water by season, time of day, temperature and
distance.

Done: data/ambience.cfg (validated by AmbienceRules, required keys, checked at start) holds
the chances, levels, distances and delays; AmbienceRules (game/state) makes the pure choices
and SoundEvents names the animals' sounds. AmbienceSounds (game/scenes, owned by Main) acts
once a second: rain and wind loops follow the weather with fades, gusts swell the wind,
birds chirp from a bird or a tree, frogs croak at water found among random tiles near the
player, deer, rabbits and squirrels sound now and then; thunder follows the new
`WeatherView.flashed` signal after a delay; WildlifeView's `animal_added` and Animal's
`state_entered` signals let it hear when animals appear and run (hooves, rustle, chatter) and
let bees' loops follow them with `move_to`. Birds and frogs are silent indoors.

## 43. Harvest animations: falling trees, items hopping out

- [x] Done

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

- [x] Done

See SPEC.md "Menus and settings" (tooltips). A tooltip panel in the shared theme, shown
after a short hover and kept on screen at any UI scale; item tooltips for hotbar,
inventory and equipment slots built from the data (ItemTypes, energy.cfg food values,
tool levels, CropRules for seeds and produce, equipment slots), with a `description` per
item; short explanations for every setting. Tests: the text for food, a tool, seeds, a
plain resource and equipment.

## 45. Ambient motion: wind sway, water, fire, rain splashes, lily pads

- [x] Done

Done: AmbientMotion (game/scenes/ambient_motion.gd) turns the shown wind and rain into the
numbers of six shaders and holds their materials, which ObjectTileset and TerrainTileset put
on the tiles that move (per-tile materials; those atlases have no texture padding so the
shaders can find a pixel's place in its cell). object_sway and decoration_sway bend plants
by whole pixels with a per-object phase hashed from the world position and gust fronts
travelling downwind; water ripples and glints; fire flickers, leans and throws sparks (the
campfire tile and the hearth sprite indoors); lily pads drift and bob; RainSplashes draws
splashes under the objects. Main feeds it WeatherView's smoothed wind and rain every frame.
Tests cover the wind-to-sway, lean, gust, chop, fire lean and splash mappings and which
tiles get which material. Left over: see-through and falling trees don't sway (sprites);
oak crowns that reach the edge of their cell can lose an edge pixel at the peak of a storm
swing (a tile is drawn only inside its cell); the reeds and tufts painted into wetland and
grass terrain tiles stay still; dead trees (bare snags) stay still on purpose.

See SPEC.md "Ambient motion". View only, driven by the weather's wind; depends on 43
(both touch the world view). Sway by shader on the object and decoration layers (whole art
pixels, stems fixed, per-object phase, gusts); water shimmer and ripples by wind; fire
flicker, lean and sparks by wind; rain splashes on the ground; lily pads drifting and
bobbing. Must stay cheap per frame.

## 46. Sleep until morning, passing out with a collapse and a wake-up screen

- [x] Done

See SPEC.md "Player" (Passing out, How passing out looks, Sleep lasts until the next
morning). Replaces the fixed sleep duration per bed and the 06:00 pass-out wake-up.

- Sleeping in any bed (and on the ground) wakes at the next 06:30; drop `sleep_minutes`
  as a duration (beds keep their energy fill). Old saves need nothing.
- Passing out sleeps until the next 06:30 but at least 10 hours; the debuff stays
  "until the next midnight".
- Still awake at 01:00 (indoors or out): pass out the same way, with a "stayed up too
  late" message (wakes at 11:00 by the 10-hour minimum).
- Collapse animation: new player frames (kneel, lying, asleep) for every layer
  (body, hair, clothes, hat), generated like the other player art; rising "z"s; input
  locked; then fade to black.
- Wake-up screen after passing out: the message (what happened, hours slept, where, the
  debuff), a key or click to go on, fade into the morning. Normal sleep: the same fade
  with the new day shown briefly, no key press.
- Tests for the wake-up times and the flow; README and screenshots updated.

Done: GameState wakes every sleep at the next 06:30 (`GameClock.minutes_until`) and passing
out at the next 06:30 but after at least 10 h (`pass_out` returns the minutes slept); beds
are marked `bed` in WorldObjectTypes instead of `sleep_minutes` (saves keep only type ids,
so old ones load as they are). `pass_awake_time`, which Main's clock calls, sets
`is_up_too_late` when the clock reaches 01:00 while awake; sleeping and passing out clear
it, and the console's `skip` is no time awake, so it never makes the player pass out.
PassOutMessage builds the text. The art generator draws a collapse sheet per worn layer
(assets/character/collapse/: kneeling, tipping over, lying, asleep; the held tool is let
go) and the rising "z" (assets/effects/sleep_z.png); PlayerView plays them (`collapse`,
`stand_up`, SleepZs). FadeScreen replaces the scene's fade: fades, a note (the new date
after sleeping) and a message that waits for a key or a click. Main locks the player for
the whole collapse, stops the clock while the screen is black and saves at the same points
as before. Debug: `--sleep`; `--energy=0` and `--time=00:59` show the pass-out. Not
covered by tests: Main itself (input lock, order of the flow), checked by screenshots.

Review follow-ups: a collapse, the message and the sleep fade take all input (Escape, hotbar
and hammer too); a game saved between 01:00 and 06:30 passes out on load (no sleep wakes then).

## 47. Thought bubbles and sweat

- [x] Done

See SPEC.md "Signs of tiredness". A small reusable thought-bubble view over the player
(an icon in a bubble, pop in, ~2 s, fade), first used for "zzz…" at 00:00 and at 00:30
while the player is awake, as the warning before the 01:00 pass-out (task 46); not for low
energy. Sweat drops on actions at 20 % or less (one) and 10 % or less (two or three).
View only; tests for when they show; README updated.

Done: ThoughtBubble (game/scenes/thought_bubble.gd) shows assets/ui/bubble_<id>.png over the
head: it pops up in whole pixels, stays 2 s and fades; the pictures come from `BUBBLE_ICONS`
in tools/art/ui.py, so a new bubble is one entry there plus `make assets` and
`show_icon(&"<id>")`. TirednessView (a child of PlayerView) owns the bubble and the sweat;
TirednessSigns (pure, tests/test_tiredness.gd) decides the sweat kind per use and energy and
which clock steps fire the "zzz" late warning (00:00 and 00:30, once each, only while awake
and only when the clock runs on: never across a sleep, a fade or a `skip`; Main sets
`is_awake` to false while it fades). Sweat is two HitParticles kinds (SWEAT: one drop, 20 % or
less; SWEAT_HEAVY: two or three drops to both sides in a bigger arc, 10 % or less): 2x2 or 1x2 px,
light blue and white from the palette with a darker last pixel, thrown out from beside the head. The
bubble sits just above the head (hat or not; pinned to the sheets by a test). The levels and warning
minutes are in data/energy.cfg `[signs]`.
`--hit=<x>,<y>` also throws the sweat, for screenshots.

## 48. Burning flames: an animated fire

- [x] Done

The user, 2026-11-05: "the flames should also move, not only the light flicker". Task 45's
fire shader only jumps the flame by a pixel and leans it, which reads as flicker. Give the
campfire and the hearth a real flame animation: generated frames (tools/art) of flame
tongues that rise, split and lick, played at a steady rate with a per-fire phase, leaning
and stretching with the wind outdoors (the hearth doesn't lean). Sparks stay. Keep it on
the art-pixel grid and cheap (one shared animation, no per-frame scripts per fire).

Done: tools/art/fire.py draws a 6-frame flame loop from a heat field (a body and three tongues
that grow, lick and fall back in turn, their tips breaking off), for the campfire (16×20 box)
and the hearth (16×16). Each fire's strip (assets/fire/<type>.png) holds what is behind the
flame, what is in front of it (the campfire's stones) and the frames; the atlas cell and the
hearth's picture keep the first frame. fire.gdshader, already on the campfire tiles and the
hearth sprite, draws the strip in the flame's box at 9 fps, the frame offset by a hash of the
fire's place (the same as `AmbientMotion.fire_frame`), shears the flame downwind by
`fire_lean_for` and makes it taller by `fire_stretch_for` (outdoors only). A shader rather than a
TileSet tile animation: the hearth is a sprite, not a tile, and the lean needs a shader
anyway, so one shader serves both. Sparks and the light flicker stay.

## 49. Crafting and the chest

- [x] Done

Done: data/recipes.cfg (validated by RecipeRules, required keys, checked at start) holds the
recipes (the chest, 5 logs); Crafting (state) takes the materials and gives the item, and
refuses (`NO_ROOM`) when the result would not fit once the materials are gone, rather than
dropping it. C (rebindable) opens CraftingScreen: a RecipeRow per recipe with icon, name,
carried/needed per material, greyed when short (tooltip says what is missing). The chest is
a WorldObjectTypes type with `storage_slots` (a WorldObject `storage`, an ItemSlots, saved
with the object, outdoors in the world's edits and inside in the interior; no save version
bump, a chest saved without storage loads empty) and an item with `places`. Holding it, the
UseHighlight draws a green or red ghost on the targeted tile (World/Interior
`is_placeable`: buildable land, nothing on it, not in front of a door; inside free floor but
not the exit or entry tile; never under the player's body). The highlight now works inside
houses too, so chests are placed there as well; inside, the axe takes a chest down into the
inventory with its contents (`TAKE_DOWN`, or `NO_ROOM` if they don't fit). Outdoors the axe
hits it like a stump (3 hits) and the chest item and its contents spill as piles
(`drop_items`). E opens StorageScreen for the chest on the targeted tile, before sleeping;
with a bed in reach it sleeps, without one the nearest chest in reach opens; with the hammer
held outdoors E is still the next building. Inventory (left) and the 5×3 chest (right) with
backpack and chest icons, click to pick up and put down, Shift+click sends a stack across
(what doesn't fit stays). Inventory and chests share ItemSlots (`move_to`, `send`). New
sounds chest_open (creak) and chest_close (thump) in tools/audio. Art: chest picture
(tools/art/chest.py) for the world with snow look, interior and icon, header icons. Tests:
recipes and crafting, placement rules, E precedence, moves, felling and spilling, saves.
Left over: the crafting menu and storage screen don't stop the clock (like the character
screen); the `nocost` cheat makes crafting free too.

See SPEC.md "Crafting". The crafting menu on C with `data/recipes.cfg` (first recipe: the
chest, 5 logs); the chest item, placed like seeds with a one-tile ghost under the building
rules, outdoors and inside houses; the storage screen on E (inventory left, 5×3 chest
right, backpack and chest icons, drag and Shift+click); squeak on open, thump on close; the
axe takes a chest down and spills its contents; chests and contents saved. Art: the chest
(world sprite with a snow look, item icon), the two header icons; sounds generated in
tools/audio and added to sounds.cfg. Tests, tooltips, README and the Controls table.

## 50. Hotbar apart from the backpack

- [x] Done

See SPEC.md "Inventory and equipment" (changed 2026-11-05). The hotbar's 10 slots no longer
count against the backpack: 10 hotbar + 20 backpack slots. The character screen and the
storage screen show the backpack grid with the hotbar as a row below it; moving items works
between hotbar, backpack, equipment and chest. Old saves keep every item where it is and
gain the new empty backpack slots. Tests; README updated. Starts after task 49 is merged.

Done: `Inventory` has `HOTBAR_SIZE` 10 + `BACKPACK_SIZE` 20 = `SLOT_COUNT` 30; slots 0-9 stay the
hotbar, 10-29 are the backpack, so the starting items and slot ids (`inventory_<n>`) keep
their meaning. `add` joins a stack first, then takes the first free slot (hotbar before
backpack, the held slot last). Both screens show the backpack as two rows of ten (as wide as
the hotbar, instead of a 5-wide grid that left the wider hotbar row hanging out) with the
hotbar row below a small gap. Shift+click from a chest goes to the backpack first
(`Inventory.backpack_first_order`, passed through `ItemSlots.add`/`send`); from the inventory
to the chest as before. Save version 6: `_upgrade_from_version_5` pads the 20 saved slots
with ten empty ones, so every item keeps its slot. Crafting and chest take-down check room
across all 30 slots through `can_add`. Tests: layout and add order
(test_inventory_backpack.gd), moving between hotbar, backpack and chest and the shift rule
(test_storage_screen.gd), the version-5 save (test_save_upgrade.gd).

## 51. Quick season changes, spring leaf-out, Scots pines

- [x] Done

See SPEC.md "Foliage and grass blend" and "Pines look like pines" (2026-11-06). The user:
"the seasons take too long to change visually, it should only be 2-3 days from start to
max"; "in spring trees should grow leaves until spring is in full bloom" (also within the
2-3 days); the pines read like young trees that don't change with the seasons.

- Blend windows in data/seasons.cfg: each change done 2-3 days after its season starts,
  ground and foliage; the season blend tests rewritten for that.
- Spring leaf-out in steps for the deciduous trees and bushes (bare, buds, small leaves,
  full): new intermediate looks in tools/art and in the season look pipeline.
- Redraw the pine as a Scots pine; keep the spruce. Season looks (snow, frost) for both.
- Screenshots of a forest over the first days of spring and of autumn; README and SPEC.

Done: every blend window in data/seasons.cfg runs from the day before its season to the
third day of it (e.g. Vector2(0, 4)), so a sixth, a half, five sixths and then all of the
tiles and plants have changed on the season's days 1 to 4. SeasonBlend has two more looks,
BUDS and YOUNG_LEAVES (objects only: SeasonBlend.GROUND_LOOKS are the ground's), and a plant
leafs out through SeasonBlend.LEAF_OUT in even steps over `leaf_out_span` (0.7) of the
spring window, starting by its threshold, so each oak and bush shows every step for about a
day. tools/art/seasons.py draws them over the bare picture (buds: pale dots on and around
the twigs; young leaves: half the summer crown in 2x2 clumps of light green) for oak, berry
bush, shrub and sapling; everything else is its spring look meanwhile. The pine is a Scots
pine (generate.py `pine`, `needle_clump`) in existing palette colours, with its own snow and
frost; sprite_height 69 and its sway profile measured on the new art. The felled pine's log
art doesn't depend on the tree picture and is unchanged.

## 52. Art quick wins from the style guide

- [x] Done

See docs/art-style.md, "Changes to make", quick wins 1-8 (the user, 2026-11-06: implement
the suggestions, quick ones first): straw bedroll instead of the sleeping bag; a new straw
hat shape (and a red knitted cap as a second hat); tomatoes replaced by flax (a fibre crop;
old saves map tomatoes to flax), strawberries the small wild kind, the pumpkin a smaller
green garden squash; autumn colours towards brown, ochre and copper (after task 51 is
merged, in seasons.py); small-paned windows on all buildings and the interior window; the
palette swaps (merge the five rare colours, add lime, paint_teal, heather, heather_dark; Kate
wall in lime and door in paint_teal, `spirit` kept for magic); seed sacks that can be told
apart; a copper watering can. Screenshots refreshed (day-and-night.png too).

Done: one commit per quick win, each with its art, tests and docs. Palette: `meadow_dark`,
`lush`, `crimson`, `frost_light` merged; `meadow_light` kept, as since task 51 it is the
Scots pine's lit needles (`green_light` turned them yellow-green); `lime`, `paint_teal`,
`heather`, `heather_dark` added (64 of 64); the Kate is lime-washed with `paint_teal` door
and shutters, and the purple berries, bean flowers, turnip shoulders and butterflies moved
from `arcane` to `heather`, so both magic colours are free. The camp's bed is a straw sack
with a rolled grey wool blanket (id still `sleeping_bag`; snow, frost and dusting looks).
The straw hat has a low crown and a drooping brim; `knitted_cap` is a red stocking cap, in
the starting backpack, with all frames (both hats one row lower, so `HAT_TOP` is -30).
Autumn oaks are brown, ochre or copper, bushes yellow or ochre, no red. Flax replaces
tomatoes: a cool-weather fibre crop with blue flowers, no regrow, not food, yielding a new
`flax` item rather than `fibre` (each crop's produce is its own item from crops.cfg, and
flax stalks are a material of their own before retting); save version 7 maps tomatoes and
their seeds to flax wherever they lie. Strawberries are wild, the pumpkin a small green
squash (id kept). Windows have 2x2 px panes in 1 px bars (3x3 in houses, 2x3 in the
shack, whose window grew taller; the dormers likewise; lit panes glow evenly); every
`window_lights` point is on glass. Seed sacks have a crop-coloured string, the crop painted
large and its seeds spilled. The watering can is copper with a big rose. Screenshots:
camp, buildings, day-and-night, seasons, character; the others only show the new can
icon in the hotbar and were left.

## 53. Period clothes for the player

- [x] Done

docs/art-style.md bigger item 1: knee breeches, white stockings, clogs, a red waistcoat
over a linen shirt, a short blue or brown jacket, long hair tied back; every animation and
the collapse frames; the starting clothes and the spare shirt become the period ones.

Done: one commit per piece. Breeches (3 rows, banded at the knee) over white stockings
that run into the feet; a red waistcoat with tin buttons over a linen shirt (`clothes_0`),
the spare shirt the plain linen one (`clothes_1`); a short open blue jacket in a new `coat`
equipment slot and layer (between clothes and hair), in the starting backpack; wooden clogs,
the first feet item, worn from the start; hair 2, mid-brown tied back with a black ribbon
(F6 cycles three). No new colours. Ids: `tunic` is `waistcoat`, `trousers` is `breeches`,
`shirt` kept; save version 9 renames them in the equipment, inventory, ground items and
chests (indoors too) and puts clogs on the bare feet. The clothes got lighter so a new game
still carries under the free 20 kg (19.9). Hats unchanged (`HAT_TOP` still -30).
Screenshot: character.

## 54. Knicks, dykes and marsh ditches

- [x] Done

docs/art-style.md bigger item 2: autotiled Knick hedges on earth banks (hazel, hawthorn),
dykes with turf, straight drainage ditches with reeds, pollard willows, wattle fences and
fieldstone walls, placed by the world generator where they fit (marsh, field edges).

Done: one commit per piece, then polish. Line objects (a type that `connects`) are one object
per tile, drawn by connection mask (World `connections`, 16 pictures per variant), as solids on
the ground in tools/art/boundaries.py: the Knick (3 variants), the wattle fence, the
fieldstone wall (3 variants) and the dyke, with all their seasons; the pollard willow is a new
tree with a trunk. `data/landscape.cfg` (LandscapeRules) and `FieldLayout` lay rows of fields
over the land; every stretch of boundary has a gap, nothing blocking stands on or beside it.
Geest: Knicks, walls, fences; marsh and wetland: ditches (water terrain) with willows and
reeds; dykes along the floodplain. Knicks, walls, fences and ditches block walking, dykes don't;
axe and pickaxe take hedges, fences and walls down. Save version 10 clears the new land 3 tiles
around buildings and the player's objects, over the tilled fields (grown by 2), under ground
items and where the player stands. Generating a chunk takes about 6.5 ms instead of 3.7. Screenshot: landscape. Decisions in SPEC, World, "The worked land".

## 55. Thatch as courses, clear roof planes

- [x] Done

docs/art-style.md bigger item 3: thatch drawn in 3-4 px courses with grouped strokes, clear
roof planes and ridge so roofs read as steep hipped roofs, not domes; crossed ridge sticks
on the Kate as an option. All buildings and their snow and lit looks.

Done: one commit per piece. `thatch_roof` draws courses about 4 px high with wavy edges,
lit along the top in broken runs, with reed ends 1-3 px long hanging below, on three
planes: the lit left hip, the front slope and the shaded right hip, with a lit hip line,
hips with a slight belly and a straight ridge; rolled eaves, dormers, moss and weathering
(crowded reed ends) in patches, the weathering kept off the door swells. Only the lowest
courses bend over a door swell. The Kate has crossed ridge sticks, and so does the longhouse, which shares them
(`kate(ridge_sticks=False)` gives the turf ridge back), drawn taller so they show against
the sky. Under snow the reed ends and most course lines are filled, leaving the planes and
an odd short line; this also fills the shack's board joints under snow, its only change.
No new colours, window lights unchanged.

## 56. Tree species of the region

- [x] Done

docs/art-style.md bigger item 4 (after task 51): beech, birch, alder and pollard willow as
the common trees with their seasons, wood and seeds; spruce and pine rarer, in clumps or
on the Geest; hazel and hawthorn in the Knicks.

Done: one commit per piece. Beech (tools/art/beech.py), birch (birch.py) and alder (alder.py)
with their summer art and a bare redraw for winter (fine twigs from `trees.twigs`), leaf-out
steps, autumn copper, yellow and a dull green-brown, their long and short trunks, a seed each
(beechnut, birch catkin, alder cone) that plants a sapling of them, sway and hit leaves. A tree
now names its trunk rows (`trunk.atlas_row`), so new trees go at the end of the atlas. The
Scots pine is redrawn taller (75 px) with a loose flat-topped crown and a warm brown trunk. The
generator keeps every tree where it stood and only picks the species anew: alder, oak and birch
on wet ground, beech, oak and birch on the dry Geest, pine and spruce only in clumps on the
Geest; no save upgrade, as no type changed and no tree moved (checked on a copy of the user's
save). No new colours. Screenshot: seasons. Decisions in SPEC, Time and seasons ("Trees of the
region") and World ("Which trees grow where"). Added on the user's word: the pollard willow
redrawn as a real Kopfweide (gnarled trunk, knobbly head, many thin rods), and a willow cutting
as its seed, which also fixes a crash on picking a willow sapling.

## 57. Hearth and furnishing of the period

- [x] Done

docs/art-style.md bigger item 5: an open hearth under a smoke hood (or a jamb stove),
Dutch tiles behind it, clay or brick floors, plate rack, wall benches; the animated fire of
task 48 kept.

Done: one commit per piece. Floors: red brick in a herringbone in the living rooms (Kate,
longhouse living end), beaten clay in the byre, the barn and the shack, as a new terrain
`CLAY_FLOOR` (footsteps on it are soil; the tileset got two floor tiles, every later tile id
moved up two). The hearth is an open hearth under a smoke hood, its picture 32x64 with the
hood on the back wall (fire box, flame top and light moved with it; same shader, light and
sound), the hearth of buff brick with an iron pot; Dutch tiles under the hood, soot behind
the fire. A plate rack (a wall piece like the window) in the Kate and the longhouse, a
spindle-backed `wall_bench` in the Kate between bed and hearth. The Kate's bed a Durk under
a canopy with curtains, the longhouse's box bed an Alkoven cupboard that stops under the
window's sill. Footprints, beds and gameplay unchanged; every free floor tile stays
reachable. Save version 12: rooms saved before take today's floors and the wall pieces they
lack, where the wall is free (checked on a copy of the user's save: Kate, shack and
longhouse load and look right). No new colours. The open hearth was chosen over the jamb
stove (the guide's first suggestion); the Bilegger is left for a best room.

## 58. The shack in tarred boards

- [x] Done

docs/art-style.md bigger item 6: tarred black or weathered silver boards with a turf roof
(no reeds, as the user decided), so it no longer reads as a frontier cabin.

Done: one commit per piece. Walls of upright boards tarred near-black with a batten over
each joint (the tar's blue-grey sheen on its edge), a sill beam on a low fieldstone base, a
ledged door and the shutter in ox-blood red, the window in a white frame. A turf roof on
birch bark: grass in overlapping clumps lit from the top left, two dry patches, a few
flowers, a ragged crest, and at the eaves a thick lip of turf with blades hanging over the
pale bark edge. Houses now have a picture per season (SeasonalArt.HOUSE_LOOKS: spring,
summer, autumn, bare, snow), picked from the season of the grass on their tile: the turf
(and the barn's turf ridge) is fresh in spring, yellow-brown in autumn, brown-grey in
winter; the build ghost stays summer or snow. Under snow the turf turns into lumpy snow,
lit near the ridge, with the lip and bark showing; the dark grass now maps to snow, which
takes a few shadow flecks off the thatch moss and the barn ridge too. Footprint, door and
window light unchanged. No new colours. Screenshot: buildings.

## 59. A hall house with the gable front

- [x] Done

docs/art-style.md bigger item 7: a new building, the Niedersachsen-style hall house with
the big arched door in the gable, owl hole (Uhlenloch) and crossed horse heads,
half-timbered; buildings.cfg entry with costs and an interior. A Haubarg later.

Done: one commit per piece. `hall_house`, 7x5 tiles, the biggest and dearest building (100
logs, 40 stone, 50 clay, 80 reeds; the longhouse takes 60, 30, 30, 50), between the longhouse
and the barn in the hammer's list. The picture (`buildings.hall_house`, 136 px tall) shows the
gable: oak framing with red brick, herringbone and slanting courses in the upper gable, the
top boarded with the Uhlenloch under a little half-hip, the green Grote Door under a carved
beam, two stable windows (with window lights). `gable_roof` draws the half-hipped thatch seen
end on in task 55's way: two planes (lit left, shaded right) whose courses run up the picture
along the side eaves, rolled side eaves, the reed cut along the rakes, a roll of reed as the
ridge lying along the roof (a turf ridge read as a green pole), moss on the shaded plane, and
white bargeboards crossing over the hip in carved horse heads, which stay clear under snow.
The interior (15x13, only task 57's furniture): the clay Diele from the door between rows of stall posts with hay, and the
brick Flett at its end with the hearth straight behind the door (a cooking station), two box
beds, wall bench, chest, table, bench, stool, plate rack and windows. Tested: footprint,
costs the most, room walls and reachability, floors, hearth and stalls, getting out of the
box beds, E at the hearth and a night in a box bed making it home. No save change (a new
building type only; a copy of the user's save loads). No new colours. Screenshot: buildings.

## 60. Animals of the region

- [x] Done

docs/art-style.md bigger item 8: white storks (on roofs, in the marsh), red-brown cattle
and sheep (on dykes and pasture), geese, as ambient wildlife with sounds; roe deer and
rabbits stay.

Done: four kinds in data/wildlife.cfg, art in tools/art/birds.py (no new colours). `stork`
hunts on wetland, the floodplain and grass with water within 4 tiles (`water_radius`, a new
key of every kind), in spring and summer by day, and flies off at 5 tiles with slow beats and
glides; `roof_stork` flies in from beside the view to a house near it (one per roof), lands
on the ridge (the middle third of the top edge of the house's picture as it is shown, read once
per picture, so it stays on top under snow), standing just in front of where the house sorts
(`BuildingViews.sort_position`), and leaves if the house is gone. Both are `Stork`, which clatters now and then. `geese` is a `GooseFlock` of 6 to
12 greylags on the marsh and floodplain (water within 7 tiles) in autumn, winter and, fewer,
spring: each goose grazes, looks round or steps on its own near the others; the flock looks up
at 9 tiles and takes off together at 6, closing into a V. `flying_geese` is a skein of 7 to 13
crossing high up, mostly at dawn and dusk: `Flock` flies sparrows or geese by kind.
`GroundShadows` are the flight shadows, kept and not made every frame. Sounds `stork_clatter`
(with the clatter) and `goose_honk` (now and then, and on taking off), peaks -25 and -24 dBFS,
quieter than the farm animals. Spawn and `--wildlife` take the four kinds (`roof_stork` on the
nearest roof, the geese as one flock). Livestock already graze the dykes, which are walkable:
no change. Not done: a stork's nest, lapwings and oystercatchers, the early spring of the geese
as such (a season factor of 0.5 for all of spring). Screenshot in docs/screenshots/wildlife.png.

## 61. Coast and tidal flats

- [x] Done

docs/art-style.md bigger item 9: tidal mud with ripples and tideways, salt marsh turning
red in autumn, a Warft (dwelling mound), an Ewer lying on the mud; terrain and world
generator work.

Done: one commit per piece. The coast lies in the west: a coast line x = f(y) about 260 tiles
west of the centre (`data/landscape.cfg` [coast], [tideways], [warften], [ewers]); the sea dyke
on the first land without gaps but for the river, the marsh reaching 36 tiles inland of it; then
salt marsh, tidal mud with tideways (one per 36 rows, clear of the river so no mud is cut off) and
the sea. New terrains `MUD`, `SALT_MARSH`, `SEA` (the salt water: no lily pads, frogs or reeds) and
`WARFT`, and layers `MUD` (over the water, the same in every season and weather), `SALT_MARSH` and
`WARFT` (grass over grass with their own season looks); the tile code's layer field holds the 12.
The salt marsh is drawn in logical colours per look (`seasons.SALT_MARSH_LOOKS`), red-purple in
autumn, with glasswort (a new decoration kind) and the flowers thrift and sea lavender (habitat
`salt_marsh`). The tide (`Tide`, `mud.gdshader`) is a look only: high water every 12 h 25 min, the
water filling a relief of its own; the mud is walked at any tide. A Warft (11 by 8 tiles, with a
Fething, buildable) on the salt marsh in one of 150 rows; an Ewer (3x1 object, tools/art/coast.py)
on the mud in one of 70; MAX_FOOTPRINT is 3x2. Storks and geese also live on the salt marsh, and
the sea counts as their water. Save version 18 gives an old home within reach of the coast its
ground back as grass and takes the new objects off (version 9's clearing, shared); a copy of the
user's save loads unchanged, the farm, camp and houses dry and reachable. Generating a chunk inland
takes 8.0 ms instead of 7.3 (side by side on one machine), on the coast about 7.4. No new colours.
Not done: ice on the mud, mussel beds and seals, a Stackdeich and sluices, the Ewer at full
scale, walking that changes with the tide. Screenshot in docs/screenshots/coast.png.

## 63. Onboarding docs and build papercuts

- [x] Done

From docs/code-review-2026-11-06.md. docs/architecture.md (~80 lines: game/state pure and
tested, game/world, game/scenes rendering; data/*.cfg -> *_rules.gd -> *Types as the way
to add content; the main nodes (Main, GameState, World, WorldView); which tests/*_case.gd to
extend; `make screenshot` for rendering; key bindings live in project.godot, change them in
the game; the debug flags), linked first under "For developers". tools/README.md (module
map, add a sprite/object/colour/sound, seed rules: `random.Random(seed)` only, no `hash()`,
draw order matters, `seed % 3` picks structure, the commands). maps/README.md (editing
interiors in Tiled: interior.tsx tile properties such as `exit`, the CSV `ground` and
`furniture` layers, one file per building id, InteriorLoader asserts). Finished tasks 1-51
moved to docs/tasks-done.md (TASKS.md keeps the rules, open tasks and "Later"; the dead
"Parallel plan" goes; check links). SPEC: real status line and make target list.
docs/art-review-2026-11-05.md archived or linked from art-style.md. Makefile: `make help`
as the default goal (targets and their variables AT, TIME, ZOOM, OUT, KEEP_SAVE, SOUND,
ARGS, GODOT); Tiled optional in `make setup`; `make clean` (build/); tools/requirements.txt
with the pinned Pillow and numpy and a `make venv` target that `make assets` depends on.

Done: docs/architecture.md, tools/README.md and maps/README.md, linked from the README.
Tasks 1-51 are in docs/tasks-done.md (task numbers in SPEC and code comments stay valid).
The art review is in docs/archive/. SPEC has a real status line and target list.
`make help` is the default, Tiled is optional in `make setup`, `make clean` exists, and
`make venv` (pins in tools/requirements.txt, gdtoolkit too) serves `make setup` and
`make assets`, which now runs without Godot. A venv is no longer repaired when a package
is missing: delete it and run `make venv`.

## 64. Quiet, honest tests

- [x] Done: 843 warnings and 6 orphans now 0 (the orphan leak was in the test, not the game: WildlifeView.ground was never parented; the test also leaked it at exit); 14 headers added (not 12); `make test` prints the counts and fails on 0 tests; test_collapse_flow steps the fade tweens with `custom_step`.

From docs/code-review-2026-11-06.md. Fix the 840 "Float/Int comparison" warnings
(tests/test_vegetation.gd) and 3 in tests/test_tiredness.gd; the 6 Node2D orphans in
tests/test_ambience_sounds.gd; delete the placeholder tests/test_pipeline.gd; a one-line
`##` header on the 13 test files without one (test_camera_rig, test_buildings,
test_chunk_streaming, test_day_night_tint, test_game_clock, test_game_state,
test_interior, test_targeting, test_tile, test_terrain_tileset, test_view_math,
test_world); test_collapse_flow drives the fade directly instead of waiting real seconds;
`make test` fails when no test ran, and prints the warning and orphan counts.

## 65. The art generators split by topic

- [x] Done: generate.py 2362 to 247 lines; canvas.py, palette.py, terrain.py, trees.py, camp.py, character.py, interior.py split out, one commit per step, `make assets` byte-identical after each. Deviations: `palette.save(rows, path, size, height)` takes the rows, not an image, so an unknown colour names the file being written; the atlas rows are tied to the GD `atlas_row` numbers by a generated assets/objects_rows.txt (read by test_object_atlas), which is the one new file in assets/; the atlas kind `fern` stays (it seeds the season looks) while the type is `fern_bush`, so the test has one alias.

From docs/code-review-2026-11-06.md; runs right after task 52, before task 53, so the later
art tasks work in the new layout. tools/art/generate.py (2290 lines) split along its
sections into palette.py, canvas.py (TILE, the 48x80 object cell constants now copied into
trunks/meadow/reeds/generate, one blank-canvas maker, one clipped `rect`, `copy`),
terrain.py, trees.py, character.py, interior.py; generate.py keeps the atlas assembly and
`main` (a `save(image, path)` helper that makes directories, the per-family writers, a
short final print; module-level drawing moved into `main`; FURNITURE defined once). One
numbered table of the object atlas rows above `object_atlas()` (the docstring misses the
chest row), the trunk-row order dependency named in trunks.py and in
world_object_types.gd, and a test tying the GD `atlas_row` numbers to it. seasons.py: copy
the canvas once at the top of `_winter_object` (snow_caps mutates the shared summer art),
a per-kind look table instead of the if-chain so a kind without a winter look fails
loudly. Palette: fail on duplicate names when seasons' colours are merged in, and say
"unknown colour X in <asset>". Outline helpers stay separate (different art rules). Must
leave `make assets` byte-identical.

## 66. Small state cleanups

- [x] Done: one commit per item. Save VERSION is now 8 (`_upgrade_from_version_7` gives old saves the moisture, clay, outfit, energy, health, debuff, chest store and crop growth they lack; every from_dict is strict). `World.new(seed, clock)` and `GameState.new(clock)` keep a default clock because many tests build them bare. Interaction uses Targeting.REACH. The five tests of the old lenient from_dict were replaced by upgrade tests.

From docs/code-review-2026-11-06.md. Delete unused tile state: Tile.water_level and
snow_depth with Chunk's arrays and accessors, Tile.is_tillable and is_plantable; keep
`frozen` with a comment (hook for frozen rivers); fix SPEC and TASKS lines that promise
them. `current_map` becomes a getter from `_building_inside` (one field instead of two that
must agree). `World.new(seed, clock)` instead of overwriting its own clock; one place that
wires `new_day` for new_game and from_dict; a comment that `clock.day` is already the new
day in `_on_new_day`. One `REACH` (Interaction and Targeting). Save: a "how to add a field"
rule at the top of save_file.gd, the silent `data.get(...)` fallbacks in from_dict
(soil moisture, spent clay, energy, equipment) and the crop `days_grown` conversion moved
into a versioned upgrade step so every from_dict is strict; upgrade tests. Small: `_hit`
returns nothing; `PositionHash.rolls(pos, salt, chance)` for the three roll idioms;
`Inventory.duplicate()` instead of the to_dict clone in Crafting; `is_blocked_by_thing`
renamed.

## 67. Tool use out of GameState

- [x] Done

From docs/code-review-2026-11-06.md. The use-action rules (~250 of GameState's lines: the
`Use` enum, COST_KINDS, use_at, use_tile, _do_use, _use_tool, _use_cutting_tool,
_use_by_hand, _use_inside, _hit, _dig, the mowing, _rolls_seed, _items_of_chest,
CLAY_DIG_*, ACTIVE_TOOLS) move to `game/state/tool_use.gd` (`ToolUse`, given the state like
Builder and Crafting). GameState keeps one-line forwards so scenes and tests keep working.
A pure move; no behaviour change.

Done: `ToolUse` holds all of it (GameState 591 -> 331 lines, ToolUse 301). `Use` moved to
`ToolUse.Use` (and `COST_KINDS` to `ToolUse.COST_KINDS`) with every caller updated: the enum
belongs to the rules that produce it, and a newcomer finds it next to them. GameState makes a
`ToolUse` per call and forwards `use_at`, `use_tile`, `use_facing_tile`, `can_use_held_item` (a
field would be a reference cycle: the state and the rules would never be freed).

## 68. World split and one way to read data files

- [x] Done

From docs/code-review-2026-11-06.md. Ground items out of World into their own class
(`_ground_items`, drop_items, _scatter_tiles, _hash_fraction, ground_items_near; no chunk
coupling); then the nightly upkeep (pass_night, _dry_and_wet_soil, _recover_clay_spots)
into its own; drop World's `max-public-methods` exception. One static
`DataFile.read_sections(path)` used by the ten rules classes (no base class), and one
validation API across them (`problems()` + `is_valid()`, renaming `missing_keys`/
`bad_values`). README/architecture: "adding a data file".

Done: `GroundItems` (`world.ground_items`: all, near, count_of, add, remove, the signals
`added`/`removed`/`dropped`, and `drop`) and `NightUpkeep.pass_night(world, ...)` (static, given
the world) are out of World (652 -> 506 lines). Neither keeps the World, so there is no
reference cycle: `World.drop_items` stays as the one entry point and passes itself to
`GroundItems.drop` per call (it is the one that knows what can be walked on). World still has 37
public methods (chunks, objects, soil, buildings, clay), so the `max-public-methods` exception
stays, with a comment on what is left. `DataFile.read_sections(path)` is used by the nine rules
classes and `Vegetation`; all of them have `problems()` and `is_valid()` (`missing_keys` and
`bad_values` are gone). docs/architecture.md has "Adding a data file".

## 69. main.gd slimmed

- [x] Done

From docs/code-review-2026-11-06.md. The ~45 debug flags into a parsed `StartupOptions`
(typed fields, one `_tile(arg)` helper; also the flags now parsed in PlayerView, BuildMode
and AudioService; unknown flags warn) and a small runner for the "once the world is drawn,
do X" steps and the screenshot countdown; the flags documented in one place, main.gd's
header points there. All screens (character, crafting, storage, console, pause) get the
same `open()`/`close()`/`is_open()` (close safe when closed; StorageScreen connects
safely), and Main keeps one list of them for the Escape order, "is any open", "close all"
and the UI sounds. `_ready` in three named steps (make views, connect state, apply start
options) with the order dependencies written down. Input order unchanged.

Done: every screen has `open()`, `close()` and `is_open()` (`close()` is safe when closed;
StorageScreen listens to the inventory and chest only while open). Main keeps `_screens`, a
plain array of the console and the three screens in Escape order, with three small functions
over it (any open, close topmost, close all) and the UI sound loop; the pause menu stays
apart because Escape opens it and it pauses the game. `StartupOptions`
(game/scenes/startup_options.gd) parses every flag once into typed fields and its header is
the one list of flags; PlayerView, BuildMode and AudioService read it. `DebugRunner` does the
"once the world is drawn" steps and the screenshot countdown. `_ready` is `_load_game`,
`_make_views`, `_connect_state_and_views`, `_apply_start_options`, then the sounds, with the
order written down. main.gd went from 871 to 671 lines.

## 70. world_view.gd: one tile code, buildings and decorations apart

- [x] Done

From docs/code-review-2026-11-06.md (and the task 29 note in "Later"). Layer, season look
and weather look of a tile packed into one int per tile (thresholds stay apart); one
`_code_at`; one corner grid in `_draw_chunk` and `_redraw_cell`. Then BuildingViews (the
building sprites, window lights, snowy check) and DecorationView (decoration spots, flowers
for the wildlife) as their own small views; streaming, terrain and objects stay in
WorldView. Verified with the season and tiling tests and a screenshot diff.

Done: `TerrainTileset.tile_code` packs layer (bits 0-2), season look (3-6) and weather look
(7-10) into one int; `ChunkLooks.codes` holds one per tile, `WorldView._code_at` reads it, and
`_draw_chunk` and `_redraw_cell` build one corner grid / one 4-code array that
`_draw_cell_corners` and `_draw_overlays` take (overlay rules untouched). `BuildingViews`
(game/scenes/building_views.gd) and `DecorationView` (game/scenes/decoration_view.gd) are
nodes WorldView owns; the wildlife reads `world_view.decorations`. world_view.gd went from 991
to 789 lines. Pixels unchanged: checked by an exact digest of every tile layer, sprite and
light (8 buildings, 7 day/snow/frost states, lights on and off) before and after each step.

## 71. Scene odds and ends

- [x] Done

From docs/code-review-2026-11-06.md. One `hash.gdshaderinc` for the hash/hash4 copied in
five shaders, the stale double comment in fire.gdshader, "palette: tools/art" notes next
to shader colours. The "object is gone" contract written once (a World helper or a signal
argument) instead of re-derived in WorldView, GameSounds and GroundItemView (and a named
"waiting" flag on a hop instead of `elapsed == 0.0`). One backdrop colour and one spelling
(colour vs color) in the screens; `TerrainTileset.tile_centre`; FallingTree emits
`finished` once; the weather text not built while F3 is off; no list copies per frame when
empty.

Done: `game/scenes/hash.gdshaderinc` (hash, hash4; the five copies were identical) is included
by lily_pad, fire, rain_splashes, water and weather_precipitation; each shader colour block
says "palette: tools/art/palette.py" and whether tests/test_shader_palette.gd guards it.
`World.is_gone(object)` is the one "the hit took it down" check (WorldView, GameSounds);
`ItemHop.just_dropped` replaces `elapsed == 0.0`. `UiColors.BACKDROP` is the one backdrop;
constant names say `color`. `TerrainTileset.tile_centre` replaces the `_centre_of` copies and
the inline math (wildlife included). FallingTree emits `finished` once. Main builds the F3
text only while it shows; WorldView returns early with no falling trees.

## 72. Lighter load, 8-slot hotbar, 4×5 backpack

- [x] Done

The user's answers of 2026-11-06:
- Tools weigh nothing, and the weight that costs no extra energy goes up to 40 kg.
- The backpack is shown as 4×5 again (not 2×10).
- The hotbar has 8 slots instead of 10 (keys 1-8). Old saves move whatever sits in the two
  dropped hotbar slots into the backpack, or onto the ground at the player's feet when it is
  full.

Done: tools (every item with a `tool`) weigh 0 and the tooltip leaves out the weight line of a
weightless item; `free_kg` is 40. The backpack is a grid of 5 columns and 4 rows on both screens,
the hotbar a row of its own below it (8 slots wide; on the storage screen it no longer wraps to
the backpack's width). `Inventory.HOTBAR_SIZE` is 8, so there are 28 slots; keys 1-8 (the
`hotbar_9` and `hotbar_10` actions are gone, and `GameSettings.RETIRED_ACTIONS` lets a settings
file that still binds them load without a warning). Save version 11: the upgrade moves what lay
in old hotbar slots 8 and 9 into the first free backpack slots (onto stacks of the same item
first), else onto the ground at the player's feet (piles 0.3 tiles apart), and a selected slot
that is gone becomes slot 0. The version 1 step now builds its inventory in version 5's 20
slots (it used the current layout, which the later steps would misread); the version 5 step
widens to 30 literally. The 8 starting items fill the hotbar, so a new game has no free hotbar
slot; harvests go to the backpack. Tests: `HotbarHold` fetches an item (or an empty hand) into
the held slot, `SaveUpgradeCase` shares the old-save helpers.

## 73. Livestock: cows, sheep, chickens, rabbits

- [x] Done

The user's word of 2026-11-06: cows, sheep, chickens and rabbits, spawned for now with a
console command. They wander, graze grass (cows, sheep, rabbits) or peck for seeds and worms
(chickens), and sleep at night. Not all alike: 2-3 looks per species, plus colour variation
when drawn. Products (milk, wool, eggs) and keeping them (pens, feeding, owning) come later.

Done: `FarmAnimal` and `Livestock` in game/state, the numbers in data/livestock.cfg
(`LivestockRules`): idle, walk, graze (peck), run (rabbits, from 2.5 tiles), sleep from
sunset plus `sleep_minutes` to sunrise plus `wake_minutes`, each animal up to 30 minutes
later. An animal steps only where its feet and its nose are on walkable tiles; the map is
asked again only when one of those tiles changes (it costs about 7 µs a tile), so about 130
animals take some 0.3 ms a frame by day. Drawn by `FarmAnimalView`, an `Animal` of the
wildlife whose state comes from Livestock; the WildlifeView makes one per animal near the view.
Sheets `assets/wildlife/<species>_<look>.png` from tools/art/livestock.py (no palette change);
the tint is a sprite modulate drawn from the animal's seed with its look. `spawn
cow|sheep|chicken|rabbit [count]`; the wild rabbit is now `spawn wild_rabbit`. Debug flag
`--livestock=<species>,...`. Save version 13 keeps species, look, tint and position. Sounds
`cow_moo`, `sheep_baa`, `chicken_cluck` through the ambience (rare, -20 to -22 dBFS, none
asleep). Not done: animals don't avoid each other or the player and may stand on a bedroll.

## 74. Professions: woodworker, cook, mason; a UI for them

- [x] Done

The user's word of 2026-11-06: start with the three professions suggested in
docs/ideas/crafting-and-professions.md (woodworker at a workbench, cook at hearth and oven,
mason with bricks and a kiln) and a UI for them. Decided by the user:
- **Skills grow both ways:** crafting raises the skill (no gain from trivial recipes), and
  skill levels unlock the next tier of recipes. Skill numbers are shown.
- **A hard total cap, as points:** only one profession can reach the maximum; with it the
  player can be above average in one or two others, not more.
- **Stations are placed objects** (workbench, oven, kiln), crafted and placed like the chest.
  The bench and oven craft at once; the kiln fires over time (overnight). The house hearth is
  the cook's first station.
- **UI:** a skills tab beside the character screen with each profession's level and progress;
  using a station opens the crafting menu filtered to it, with locked recipes shown along with
  the skill they need.

Done: `Skills` (points in tenths, the total cap, the fade marks) on the player, the rules in
data/skills.cfg (`SkillRules`: 0-100 a skill, 200 in all, 2 points a craft at the recipe's
level falling to none 40 above it). The cap rule: at 200 a skill only grows by taking points
from a skill marked Fade on the skills tab, nothing fades on its own (SPEC, Professions).
data/stations.cfg (`StationRules`) maps object types to stations: the workbench, the kiln
(outdoors only) and the bake oven are placed objects made by hand; the house hearth and the
camp's fire are the hearth. Recipes got `station`, `skill`, `level` and `hours`; E on a
station opens `CraftingScreen` on its recipes, locked ones greyed with the level they need.
A recipe with `hours` is held by its station as `StationWork` in the object's saved state, so
the kiln fires on the game clock while the player is away (no new save field). The skills tab
is a second tab of the character screen (K). Recipes: planks, stool, clogs, carved chest
(20 slots), joined cupboard (25); roast turnip, pottage, pea soup, bread, berry tart and feast
cake (flour by hand from wheat, as there was none); raw bricks and bricks, which build the
oven. Each skill has a master recipe at level 70, so every skill can reach 100. Art in tools/art/crafts.py
(atlas rows 41-44, no palette change). Save version 14 (skills); console `skill`; flags
`--skills` and `--station`. Not done: a look for a firing kiln, live refresh of the kiln's
time while its menu stays open, more brick uses.

## 75. Flowering meadows; bees only at flowers

- [x] Done

The user's word of 2026-11-06: in spring and summer the grass should have flowers on it, and
bees should only be around flowers. Meadow flowers of the region, in patches and drifts
(not evenly sprinkled), changing through the seasons; bees spawn at flowers, stay near them,
and their sound comes only from there.

Done: twelve species (wood anemone, dandelion, cuckooflower, daisy, buttercup, red campion,
red and white clover, yarrow, knapweed, meadowsweet, heather) in tools/art/flowers.py, a row
of their own in the decoration atlas (`TerrainTileset.FLOWER_ROW`), each as a small plant, a
few and two drift tiles; no new colours. A bloom curve per species in data/vegetation.cfg
`[flowers]`. DecorationView sows them per tile when a chunk is drawn: a drift noise and a mix
noise, the habitat from the layer (woods: grass where `World.is_in_woods`) and the chances and
communities of data/flowers.cfg (`FlowerRules`). A tile shows its species furthest into its
bloom, small while it has only just opened or is fading, else its ordinary decoration; the
old evenly sprinkled flowers and the `flower` kind are gone. Bees: `flowers_per_animal`
(data/wildlife.cfg) replaces `needs_flowers`, one bee per 8 tiles of flowers in bloom in and
around the view, up to the cap, spawned only at those in the spawn ring; the buzz was already
the bees' own (the nearest two). For task 77: a worn tile loses its flowers by getting no
habitat in `DecorationView._sow_flowers` and a redraw. Not done: meadowsweet grows on wet
ground and the floodplain, not beside the ditches as such; no blue flower (cornflower belongs
in the rye).

## 76. Console: what can be spawned

- [x] Done

The user's word of 2026-11-06: commands like `spawn` list what they take. `spawn` with no
argument or an unknown name prints the list, and `help spawn` shows it.

Done: `Console._candidates_text` lists the candidates of the kinds in `LISTED_KINDS` (animals,
weather conditions, snow values), from the same `candidates` that Tab uses, wrapped to 70
characters. `spawn` and `spawn <unknown>` print it; `help <command>` shows the usage and the
list (and Tab completes command names after `help`). `weather` already shows its names in its
usage, `give` has the "did you mean" for items (too many to list; Tab completes them).

## 77. Desire paths

- [x] Done

The user's word of 2026-11-06: ways the player walks very often develop paths with less grass.
Defaults: steps on grass wear the tile (grass, then trodden, then a dirt path); an unused path
grows back over days; the wear is saved; worn tiles lose their flowers and grass tufts; paths
are a look only (no change to speed or farming).

Done: `World.wear_tile` counts steps of wear per tile entered (`GameState.walk` outdoors, and
`Livestock` at `animal_step`, half a step), only on grass and the floodplain and not under a
building; `wear_stage` gives trodden from 8 steps and a path from 24, capped at 32
(`data/paths.cfg`, `PathRules`), and `regrow_paths` takes 2 a night in the night upkeep. Only
worn tiles are kept and saved (`"wear"`, save version 15; 14 is task 74's), and tilling clears
the wear. Two terrain layers, `TRODDEN` and `PATH`, between dry grass and soil (the tile code's
layer field is 4 bits now), drawn over any grass with dithered edges; a stage change emits
`tile_changed`, which redraws the four cells and the decoration around the tile. The layers
have no habitat and no decorations, so a worn tile loses its flowers and tufts. The overlay
stack of the seasons' looks is a loop over `VARIETY_LAYERS` and the frost is drawn in layers
too, so paths keep their edges in every look; snow covers them, with the trodden grass in its
snow look over it as a faint track (`SnowTrackLook`); in the bare look the earth turns
`mud_dark`. No new colours. A new chunk's cells are drawn without erasing, which pays for the
extra overlays. `--path=<x>,<y>` and `--path-days=<walked>,<left>` walk a winding route for
screenshots (`DebugPath`). Not done: mud in rain; a path does not change speed. Screenshot in
docs/screenshots/desire-paths.png.

## 78. Waking in the bed; reset and tp indoors

- [x] Done

The user's word of 2026-11-06: passing out outside put the player behind the bed, stuck.
- The bed is drawn in layers (frame and pillow under the player, blanket over), so the
  player lies in it under the blanket; the bed no longer blocks walking, so nobody gets stuck.
- Waking after passing out (and after sleeping) puts the player in the middle of the bed,
  lying under the blanket, instead of standing beside it.
- A `reset` console command puts the player at their bed.
- `tp` also works indoors: it takes the player outside to the tile, if that tile is valid.

Done: `GameState.go_to_home_bed` (waking, `reset`) and `teleport_to` (`tp`); the player lies
in the middle of the bed (`PlayerState.bed_lying_in`, cleared by the first move; not saved).
`PlayerView` lays the asleep frame of the collapse in the bed (rotated head up, or mirrored
head left for the box bed; the type data `bed` is the head direction). The beds of the houses
are drawn below the entities (`InteriorView`'s `Beds` node) and `<bed>_cover.png`, the blanket
cut from the bed's picture by tools/art/interior.py (`BED_COVERS`), is shown above the player
while they lie there; the straw mat got a wool blanket for it. Outdoors the player lies on the
bedroll (above the objects, `LYING_Z_INDEX`) under `assets/bedroll_cover.png`, the bag cut from
its atlas cell by `camp.bedroll_cover` and shown by `ObjectCover` (the snow looks use the same cover). The beds did not block walking any more
(reverted, see the fix below); the saved game of the report (player standing on the box bed of the longhouse, `[1.5, 2.5]`)
loads and walks. No save change, so no new version. `GameState` got the same
`max-public-methods` exception as `World`. Screenshots in docs/screenshots/waking-in-bed.png.

Fix (2026-11-06, "now I'm walking straight on the bed"): the Kate bed, the shack mat and the
box bed block walking again (the bedroll stays walkable). `PlayerState.move` takes the lying
player out on their first move (`_get_out_of_bed`): onto the free tile beside the bed in the
direction pressed, else the front (opposite the head), else the sides, never behind. A player
standing where they do not fit walks through objects (not walls) until free
(`_can_step_off_blocked_tile`), which covers old saves and saves made in bed.

## 79. Dogs, cats and horses; a bone for the dog

- [x] Done

The user's word of 2026-11-06: dogs, cats and horses join the livestock, spawned with the
console like the others, 2-3 looks per species plus tint, sleeping at night. A bone (an
item, spawned for now) given to a dog makes it follow the player for a while.

Defaults (QUESTIONS.md 19): period breeds, e.g. a farm collie, a spitz and a pointer-like
hunting dog; tabby, black and ginger cats; a heavy marsh horse (Oldenburger type) in bay,
black and grey, and a small pony. Cats roam wider than the others and climb nothing yet. A
dog with a bone follows at 1-2 tiles for 3 game hours (saved), then wanders again; giving
it uses up the bone. Dogs bark now and then, cats are silent but for a rare meow, horses
whinny and snort. Save version bump for the follow time.

Done: `dog`, `cat` and `horse` in data/livestock.cfg with their looks (collie, spitz, pointer;
tabby, black, ginger; bay, black, grey, pony), drawn in tools/art/livestock.py by the cow's
frame builder, which grew running legs, a lift between strides and heads and tails per look.
Every livestock sheet has a `run` row now (cattle, sheep, hens and rabbits reuse their walk),
and an awake animal can pick `RUN` (a fourth `activity_weights`, `run_seconds`; `flee_speed` is
now `run_speed`); only the new three do. The horse is 44x36 px a frame, about 32 px long, with
the top of its torso free for a rider. Sounds `dog_bark`, `cat_meow`,
`horse_whinny` (whinnies and snorts) through the ambience. The `bone` item: `ToolUse.Use.GIVE_BONE`
on a dog within a tile of the target, then `Livestock.start_following` sets the animal's
`follow_until_minute` (GameClock `total_minutes`, saved, save version 16); `Livestock.update`
now takes the clock. A follower waits within 2 tiles, walks or runs after the player to 1 tile,
and is put beside them when more than 15 tiles off or stuck for 2 s; it doesn't sleep. Not
done: the bone has no recipe or source yet; a dog left outside while the player is in a house
waits there (the world stands still).

## 80. Mice and frogs; storks eat frogs

- [x] Done

The user's word of 2026-11-06: critters, mice and frogs, the frogs food for the storks.
Ambient wildlife like the birds and rabbits, not livestock.

Defaults (QUESTIONS.md 19): mice near fields, hay, buildings and hedges, scurrying from the
player, mostly at dusk and night; frogs at the water's edge, wet meadows and ditches from
spring to early autumn, hopping, croaking in chorus on spring and summer evenings, gone in
winter. A hunting stork walks to a frog, strikes and swallows it; the frog is gone. Needs
task 60 (storks).

Done: two kinds in data/wildlife.cfg, art in tools/art/animals.py (no new colours). `mouse`
(`Mouse`) lives on grass and soil within 2 tiles of farmland: tilled soil, a crop, a Knick, a
fieldstone wall or a building (`farm_radius`, a new key of every kind, and
`WildlifeRules.has_farm_near`; hay lies only in the barns, so the building counts for it), all
year, mostly at dusk and at night; it sniffs and scurries and dashes off into cover (gone) at
2.5 tiles. `frog` (`Frog`) lives on grass, floodplain and wetland within 2 tiles of water,
spring and summer and fewer in autumn, none in winter, most at dusk, and stays out in the
rain; it sits puffing its throat, hops, and hops off at 1.5 tiles. A hunting `Stork` that
sees a frog within 3 tiles when it picks what to do next walks up to it, strikes and swallows
it (a new `swallow` row of the stork's sheet), and the frog is done; one that hopped away
during the strike is missed. The lookup is `WildlifeView.nearest_animal(kind, point, reach)`
over the few wild animals, for task 82's cats as well. Sound `frog_chorus_loop` (-22 dBFS,
quiet) through the ambience: `AmbienceRules.chorus_level` by `[frog_chorus]` in
data/ambience.cfg (dusk, less at night, spring and summer, as warm as the croaks need it),
fuller with the frogs about up to 3; the single croaks at water stay. `spawn mouse|frog` and
`--wildlife=mouse,frog` come with the kinds. Not done: autumn counts as a whole (no "early"
autumn), frogs don't dive into the water, mice make no sound. Screenshot in
docs/screenshots/mice-and-frogs.png.

## 81. Riding a horse with a saddle

- [x] Done

The user's word of 2026-11-06: horses can be ridden once you have a saddle, which for now is
spawned with the console. Needs task 79.

Defaults (QUESTIONS.md 19): use the saddle on a horse to saddle it (it stays on the horse;
taking it off gives it back), use a saddled horse to mount it, the same key to get off
beside it. Riding is about twice walking speed and costs no energy; no tools, no building,
no doors while mounted (get off first). The player is drawn sitting on the horse in all four
directions, walking and trotting. Saved: the saddle on the horse; a save made while riding
loads with the player beside the horse.

Done: the `saddle` item (`give saddle`, one to a slot). The use key with it puts it on the horse
in front (`ToolUse.Use.SADDLE`, `FarmAnimal.is_saddled`, saved, save version 22), with an empty
hand takes it off (`UNSADDLE`; the empty hand's slot always has room, so nothing is refused). A
saddled horse has sheets of its own, `horse_<look>_saddled`. E on a saddled horse in front
(`Interaction.horse_to_mount`, after a villager, before chests and beds) gets on it
(`GameState.mount`, `PlayerState.horse`, `FarmAnimal.is_ridden`), E again gets off
(`dismount`): on free ground within 2 tiles, its side first, never water, a wall or a building;
with no room the player stays on ("No room to get off here."). A ridden horse does nothing of
its own and goes where the player rides; it walks at walking speed and trots at twice it after
0.6 s of riding on (`ride_walk_factor`, `ride_trot_factor`, `trot_after_seconds` in
data/livestock.cfg), for no energy and unslowed by tiredness. The rider's body collides as on
foot and keeps off buildings' tiles, so no door is passed (a horse in a doorway is ridden out);
the use key (`Use.RIDING`), the hammer, a door ahead and (the user, 2026-11-07) the crafting
key say "Get off the horse first."; only the inventory (with the hotbar and dropping) and eating
work, and nothing is picked up while riding. Passing out slides the player off first if there is
room; a teleport and waking in the home bed leave the horse. A save on horseback writes the
player beside the horse (nothing about riding is saved). Art: the player's layers astride
(assets/character/riding/, tools/art/character.py `riding_sheet`) and the ridden horse
behind and in front of the rider in four directions, standing, walking and trotting
(`horse_<look>_ridden[_over]`, tools/art/livestock.py `ridden_sheets`; the pony has its own
views); no new colours. `PlayerView` draws them with the horse's tint and shadow, the rider
rising with the trot; occlusion counts the rider and horse (`Occlusion.RIDER_SIZE`). Debug flag
`--riding=<look>`. Not done: no hoofbeats (no sound for them yet), no saddle recipe, the pony
carries an adult whose feet nearly touch the ground. Screenshot in docs/screenshots/riding.png.

## 82. Cats hunt mice

- [x] Done

The user's word of 2026-11-06. Needs tasks 79 and 80. Defaults: a cat that sees a mouse
within a few tiles crouches, creeps, and pounces; about half the pounces catch it.

Done: a cat's `FarmAnimalView` looks for a mouse when the cat picks what to do next
(`WildlifeView.nearest_animal`, within `sight_tiles`, 3.5) if `Livestock.can_hunt` (a cat, up
and about, not asleep, rested), and starts the hunt: three new activities of `FarmAnimal`,
`CROUCH` (1.5 s, facing the mouse), `CREEP` (0.3 tiles a second, `track_prey` following the
mouse, given up after 12 s, when blocked or when the mouse is gone: `stop_hunt`) and `POUNCE`
(from 1.2 tiles, a leap at 3.5 tiles a second onto where the mouse was). As the cat pounces the
view draws the catch (`catch_chance` 0.5, `wildlife.rng`): a miss sends the mouse dashing off
into cover away from the cat (`Mouse.flee_from`), a catch takes it if it is within
`catch_tiles` of where the cat lands. Then the cat rests 60 s (`hunt_rest_seconds`). The numbers
are a new `[hunting]` section of data/livestock.cfg. The hunt is not saved (nor are the
mice), so a game saved mid-hunt loads with the cat looking about; no save version bump. Mice
take no notice of a creeping cat. Art: `crouch`, `creep` and `pounce` rows of every cat sheet
(tools/art/livestock.py, low torso, flat tail, a leap and a landing with the head down); no new
colours. Debug flag `--hunt` (a cat of each look with a mouse ahead). Not done: cats don't
carry or eat what they catch, and hunt nothing but mice; the cats' sleeping hours are those of
task 79, so they hunt at dusk and before dawn rather than through the night. Screenshot in
docs/screenshots/cats-hunting.png.

## 83. Taking down buildings and placed things

- [x] Done

The user's word of 2026-11-06: a way to deconstruct buildings and items. Placed things can
already be taken down with the axe or the pickaxe; buildings can't be removed at all.

Decided by the user (QUESTIONS.md 21): with the hammer in hand, X switches between building
and taking down, and the HUD shows which mode is on. Taking down highlights the building or
placed thing under the cursor; holding the use button for about a second takes it down. A
building gives back about half its materials (rounded down), dropped in front of its door;
the house's own furniture goes with the house. Not while inside it, and not while anything
the player placed is still inside (chests, stations, stools...): those must be taken out
first, and the message says so. If the player's bed was in it, they wake at the camp's
sleeping bag. A stork on its roof flies off. Crafted placed things (chests, stations,
stools) are not broken down: taken down, they go back into the inventory whole (or drop
when it is full). No salvaging of items into materials.

Done: `World.remove_building` (signal `building_removed`, which `BuildingViews.remove` answers)
and `GameState.take_down_building` / `refund_of_building` / `why_not_take_down`. The furniture
the house came with is told from what the player put in by reloading the house's own map
(same type at the same tile, and nothing in it), so an empty chest of the Kate goes with the
house but a full one, or a stool the player added, keeps it standing. The camp's sleeping bag
is not saved: `CampSite.sleeping_bag_of_seed` finds it again from the generated land, so no
save change. `Builder` has the mode (`is_taking_down`, reset when the hammer is let go or
build mode dismissed) and `take_down_target` / `take_down_gives` / `take_down`; what counts as
a placed thing is `ItemTypes.item_placing`. `BuildMode` marks the target and runs the one
second hold; the sound is the axe's chop (`taken_down`). `--taking-down` for screenshots.
Storks: `WildlifeView.is_standing` already made a stork leave a roof that is gone.

## 84. NPCs: a first villager to spawn and chat with

- [x] Done

The user's word of 2026-11-06 (priority, the first step of docs/ideas/NPC.md): NPC art and
an entity that can be spawned randomised via the console. It walks about a bit but stays
close to buildings, so it never leaves the campfire area. The use of E on it opens a chat:
the player's face on the left, the NPC's on the right, a classic IRC-style chat window in
the middle. A random name on spawn. Esc leaves the chat. The chat keeps its history. For
now the NPC always answers "I understand.", but the answer comes from one function that can
later do more (an LLM, see the ideas doc).

Defaults (QUESTIONS.md 22): `spawn npc [count]`; the look is randomised from layers like the
player's (sex, skin, hair, period clothes in their colours); period North Frisian / Low
German first names and surnames matching the sex. The NPC keeps to within about 6 tiles of
the nearest building or campfire at spawn (its anchor), idles and strolls by day and stands
still at night. NPCs, their looks, names, anchors and chat histories are saved (a save
version bump; history capped at the last 200 lines). The chat pauses the game while open;
lines read `[08:15] <You> hello` with the game time; Enter sends, Esc closes; the history
scrolls. The reply function is async-ready (awaited), so a slow LLM fits later.

Done: `Npc` and `Npcs` in game/state, the numbers, names and clothes in data/npcs.cfg
(`NpcRules`): a seed gives the sex, the name and the look, layers of `Appearance` (which got an
`apron` slot) drawn from the player's kind of sheets, the women's dress and the other colours
from tools/art/villagers.py, no new colours. The anchor is the yard in front of the nearest
building's door or the nearest fireplace within 16 tiles, else the spawn spot; a villager
strolls towards points inside 6 tiles of it, never steps out of that circle (one outside only
steps back in), steps only where its body fits on walkable tiles (the map asked only when the
body moves onto new tiles), stops short of the player, and stands still from 30 minutes after
sunset to sunrise. `NpcView` draws it among the entities with the player's frames. E speaks to
the villager on the targeted tile or the nearest one in reach in front
(`Interaction.npc_to_chat`), before chests, stations and beds; `NpcNameTag` shows that one's
name over their head. `ChatScreen` pauses the game, shows 32x32 portraits at 2x laid together from the
layers' portraits (tools/art/portraits.py) and the IRC-style lines, awaits
`NpcDialogue.reply` (for now "I understand." after half a second) and keeps its lines in the
villager's history. `spawn npc [count]`; debug flags `--npcs=<count>` and
`--chat=<line>;<line>`. Save version 17 keeps name, sex, look, position, anchor and the last
200 chat lines. Not done: villagers don't avoid each other and may share a spot; two can get
the same name.

## 85. A local LLM in a container for testing NPC talk

- [x] Done

The user's word of 2026-11-06: a script that brings up an OpenAI-compatible server in a
container (docker via podman on the user's machine) with a model that fits simple NPC
conversations, for testing. Performance doesn't matter in this test.

Defaults (QUESTIONS.md 23): Ollama in a container (`ollama/ollama`, OpenAI-compatible API on
localhost:11434/v1) with a small instruct model of about 2 GB, e.g. Qwen2.5 3B Instruct
(Apache-2.0), on the CPU (the GPU isn't exposed to containers here). `make llm-up` starts it
and pulls the model (kept in a named volume), `make llm-down` stops it, `make llm-check`
sends one chat request and prints the answer. Works with `docker` or `podman`. Normal tests
never need it.

Done 2026-11-06: `tools/llm/llm.sh` (up, down [--purge], check, status, logs) and the targets
`make llm-up`, `llm-down` (`PURGE=1` deletes the model), `llm-check`. Ollama 0.35.0 pinned,
model `qwen2.5:3b-instruct` (override `LLM_MODEL=`), container `sandbox-game-llm`, volume
`sandbox-game-llm-models`, 127.0.0.1:11434 only; podman if present, else docker. A check
answers in about 5 s on the CPU. Note: the 3B model has the Qwen Research License
(non-commercial), not Apache-2.0 as assumed in QUESTIONS.md 23; fine for testing only.

GPU, the user's word of 2026-11-06: give the container the NVIDIA GPU. `llm.sh up` adds
`--device nvidia.com/gpu=all` (CDI, podman and docker) when a CDI spec for it exists,
`LLM_GPU=auto|1|0` overrides, and a container with the other setting is recreated. The host
needs `nvidia-container-toolkit` and `nvidia-ctk cdi generate` once (root, see
tools/README.md).

## 86. NPC replies from the LLM, with compacted memory per NPC

- [x] Done

The user's word of 2026-11-06. Needs tasks 84 and 85. `NpcDialogue.reply` asks the
configured OpenAI-compatible endpoint (endpoint, model, optional key in Settings; "none"
keeps "I understand.") and falls back to a scripted line on time-outs and errors. Save games
keep, per NPC, the compacted history of former conversations: when a chat closes, the
conversation is summarised (by the LLM, or a plain truncation without one) into a memory
line that is saved and used in later prompts; the raw lines stay capped as in task 84.
Tests use a fake backend; an optional test talks to `make llm-up` when it runs.

The prompt, from the user's working example against the test LLM (2026-11-06): a template
in a data file, shaped like this request, which gave good lines with qwen2.5:3b-instruct:

```
"temperature": 0.7, "max_tokens": 60,
system: "You write dialogue lines for villagers in a game set on the North Frisian coast
  in 1750. Answer with the villager's spoken line only: one or two short sentences of
  plain, casual small talk in the language the neighbour speaks. Never break character,
  never mention being an AI, never offer help or advice like an assistant."
user: "Villager: Antje Boysen, a farmer's wife.\nHer neighbour says: \"Fine weather for
  the hay today.\"\nAntje's reply:"
assistant: "Aye, if it holds till Thursday. My Hinrich's out with the scythe already."
user: "Villager: Antje Boysen, a farmer's wife.\nHer neighbour says: \"Good morning! Is
  the dyke holding after the storm?\"\nAntje's reply:"
```

The template fills the villager line from the villager's data: name, sex (her/his),
age, appearance in words (from their look), trade, personality, background story and
memory, and the moment from the game's real state (the date as the HUD shows it and how far
into the season, the clock time and the phase of the day, the actual weather in words:
condition, temperature, wind, rain or snow, frost; and where they are); earlier turns of
the chat go in as user/assistant pairs in the same shape. The example exchange (the
few-shot turn) is part of the template data.

Villagers are defined in data files: a few hand-written ones (Antje Boysen first, as in the
example, then e.g. a fisherman, the miller, a dyke reeve's widow) with a fixed look,
background and personality, spawned by id: `spawn npc antje`. `spawn npc` without an id
keeps making a random villager, who gets a background composed from data tables (trade,
family, a worry, a habit). The ids are listed in the console's spawn list and completion.

Since (2026-11-06, the user's word): the endpoint defaults to the test LLM
(`http://127.0.0.1:11434/v1`); emptied, it is off.

From the review of task 84: the "awaiting an answer" state must belong to the villager, not
the chat screen (closing A's chat while it answers and opening B's must not show B typing
or block B), and `reply` needs a time-out and an error path that return a fallback line, so
the typing line never sticks.

Added by the user while it was built: the moment in the prompt is concrete, from the game's
state: the date as the HUD shows it and how far into the season, the clock time and the part
of the day, and the weather as it is (condition, °C, wind, frost), wording in the data file.

Done: `data/villagers.cfg` (`VillagerRules`, checked at start) has Antje Boysen, Momme Ketels
(fisherman), Ocke Hansen (miller) and Kerrin Paulsen (the dyke reeve's widow); `spawn npc
<id>` puts one near the player, once, and the ids are in the spawn list and Tab completion;
the debug flag `--villager=<id>` does it for screenshots. Made-up villagers draw an age, trade,
family, personality, worry and habit from new tables in `data/npcs.cfg`. `NpcPrompt` builds the
request from `data/npc_talk.cfg` (`NpcTalkRules`) in the user's shape: system line, the Antje
example, the last 8 lines of this conversation, then the villager line, who they are (look in
words from the layers), their memories, the moment (`NpcMoment`: "the 12th day of Spring,
year 1 (mid spring), 08:15 in the morning", "light rain, 9 °C, a fresh west wind", "outside
the kate"), that the player is a newcomer whose name they don't know (else the model named the
player "Jakob"), and what the player said. `OpenAiChat` (an HTTPRequest that runs while
paused, 30 s time-out) asks the endpoint of Settings → Language model (endpoint, model, key;
the key plain text in settings.cfg); `NpcDialogue` (moved to game/scenes) trims the answer
(quotes, name prefix, first line, two sentences) or says a scripted line. `Npc.is_answering`
holds the wait. On closing a chat `NpcDialogue.remember` sums it up in a dated memory line (by
the model, else the start of what the player said), 10 kept, the oldest two merged. Save
versions 19 (who they are) and 20 (memories), after task 61's 18. Tests use `FakeChat`; two tests ask the real
model when `SANDBOX_LLM_URL` is set. Replies from qwen2.5:3b-instruct: Antje, asked whether
the dyke holds: "Moin, welcome. The dyke's as good as it's ever been."; about butter: "Aye, I
do. Why, do you need some?"; Kerrin in a storm at dusk: "The dyke will hold, the Lord is
watching over us. But we must be ever vigilant." Not done: an adapter for Claude's own API,
streaming, suggestions from the model (docs/ideas/NPC.md 6.3).

Since (2026-11-06, the user's word): the model lost the thread, as only the lines since the
last memory went in (at most 8), and every closed chat became a memory. Now the last 24
lines of the chat go in, also those already remembered.

## 88. Inventory handling

- [x] Done

The user's word of 2026-11-06:

- **Bug:** some slots in the inventory can't be selected. Find which (likely hit areas or
  an overlapping control) and fix all of them.
- **Dropping:** items from the inventory can be dropped on the ground (e.g. dragged out of
  the screen, or a drop key on the held stack); they lie as ground items like a felled
  tree's drops and can be picked up again.
- **Swapping:** dropping the held item on a slot that holds another item puts it there and
  the item that was in the slot now sticks to the mouse (same items stack as today).
- **Shift-click:** in the backpack moves the stack to the quick bar, on the quick bar moves
  it into the backpack, as long as there is space (stacking onto the same item first).
- **The quick bar while the inventory is open:** the HUD's quick bar is not greyed out and
  is used directly; the extra copy of the quick bar inside the inventory screen goes.

Done: **The bug:** the fade screen's invisible text box (layer 2, centred, 320x32, default mouse
filter) caught every click on the strip in the middle of the window, which lay over the
bottom rows of the backpack; it now ignores the mouse. tests/test_inventory_clicks.gd clicks
every slot at its centre and corners with the fade screen and the hotbar in the tree.
**Quick bar:** `HotbarHud` is on layer 2 (above the screens' backdrop, under the fade), its
slots are clickable (`SlotView.is_clickable`) only while the character page or the chest screen
is open, and both screens take the hotbar in their constructor, listen to its slot views and
draw no row of their own (the tooltip ids of those slots are `hotbar_<n>`, no longer
`inventory_<n>`). **Swap:** `ItemSlots.move_to` says whether it swapped; the screens then keep
the picked slot (now holding the displaced item) as the pick; on the character screen also onto
and off the equipment slots. **Shift-click:** `Inventory.move_to_other_part` (character
screen); the chest screen already sent stacks to the other side. **Dropping:** a left click
outside the panel (and the hotbar) with a backpack or hotbar stack picked emits `drop_requested`
(chest screen too, for inventory picks; an equipment or chest pick is just let go), and the new
action `drop_item` (default T; Q and G were taken or clashed with test bindings) drops the held
stack: `GameState.drop_from_inventory` lays it in front of the player with `World.drop_items`;
such piles (`GroundItem.is_dropped_by_player`) are pulled in again only after the player has
left their reach (not saved: a game saved right after a drop collects the pile on load).
Nothing is dropped inside a house. The hotbar is on layer 2 only while a screen that uses it
is open (else layer 1 with the other HUDs), and only that screen listens to its clicks; the
dragged icon has a layer of its own (3), above the hotbar.

## 89. Crafting UI: buttons clickable all over

- [x] Done

The user's word of 2026-11-06: in the crafting UI some buttons can only be clicked on small
areas. Make every button and recipe entry clickable over its whole visible area (likely
child controls eating the mouse or a too-small hit rect); check the other screens (storage,
character, settings) for the same and add a test that clicks at the edges of a button.

Done: no code fix was needed; the cause was the one task 88 fixed in commit 296d0c7: the fade
screen's invisible text box (layer 2, centred) kept the default mouse filter and ate the
clicks on a strip in the middle of the window, which cut across recipe rows. Without that fix
the new test fails on the crafting rows at those places. Every recipe row (by hand and at a
station), storage and character slot, tab button and pause menu page button and slider
answers the mouse at its centre and just inside each corner (what is scrolled out of a list
is left out), with the game's other HUD layers in the viewport; the HUDs that need a game
state (build panel, vitals, cheats) are checked to have no control that stops the mouse.
Tests: tests/test_click_areas.gd, helpers in tests/click_case.gd.

## 90. Console: noclip

- [x] Done

The user's word of 2026-11-06: a console command `noclip` that turns off collision for the
player. A toggle like `nocost`, shown on the cheat HUD: the player walks through trees,
rocks, water, buildings and furniture; indoors they stay inside the room's bounds; off
again, a player standing on a blocked tile can walk off it (the step-off rule of task 78).

Done: `CheatFlags.is_noclip` (HUD "No clip"), `PlayerState.move(..., is_noclip)` checks only
that the body's tiles exist (`is_on_map`): the room's tiles indoors, loaded chunks outdoors;
a room's wall tiles are on the map, so noclip reaches the wall but not beyond. The step-off
rule of task 78 refuses steps into water, so a player left in a lake would be stuck: turning
noclip off where the player doesn't fit puts them on the nearest tile they fit on, within 12
tiles, never on a building's tiles (its door would take them inside; one lying in a bed stays
in it): `GameState.put_player_on_free_ground`; the console says so when nothing is free. A
noclip walk wears no desire path. Tests: tests/test_noclip.gd.

## 91. NPC chat history: a set length, the rest compacted, a clear for debugging

- [x] Done

The user's word of 2026-11-06, after finding that villagers lost the thread (fixed for now
by telling the last 24 lines, commit 4e7826c):

- **A setting for the chat history length** (Settings → Language model, e.g. "Lines a
  villager keeps", default 24): each villager keeps that many of the latest chat lines in
  the save, and all of them are sent to the model as earlier turns.
- **The older rest is compacted:** lines that fall out of the kept history are summed up
  into the villager's memory (by the model, or plainly without one), saved, and sent too.
  This replaces making a memory every time a chat closes: a memory is made when lines drop
  out, so a reopened chat goes on where it left off. The memory cap and merging of task 86
  stay. Lowering the setting compacts the lines it drops.
- **Clearing, for debugging:** typing `/clear` in the chat (IRC style) forgets the chat
  history and the memories of that villager (with a line saying so); the README and the
  input's placeholder mention it.

Save: the kept lines and memories are already saved; a save version step only if the format
changes. Tests with FakeChat; the README's "What the model is told" updated.

Done: `GameSettings.chat_history_lines` (2 to 200, default 24, not per provider, in
`[language_model]` of settings.cfg only when changed; the `history_lines` of npc_talk.cfg and
the 200-line cap are gone, so the setting is the one source). `NpcDialogue.compact` keeps a
villager's chat at that length and makes a memory of the lines that drop out, once per
exchange (the model's summary, else `plain_memory`); a loaded game and a lowered setting
compact every villager (`compact_all`). Dropped lines wait in `Npc.uncompacted_lines`, which is
saved, until their memory is made: a save made while a summary is asked for loses none, and
the next load summarises them. One summary at a time per villager (`is_compacting`), lines
that drop meanwhile are summed up next; a summary in flight when the chat is cleared is
dropped. Closing a chat no longer makes a memory; `lines_since_memory` became
`remembered_lines` (save version 21, tests/test_save_npcs.gd): the oldest kept lines a version
20 memory already holds, dropped without a second summary. The setting is applied when the
menu closes, not at each step of its slider. `/clear` in the chat input forgets the chat, memories and lines
waiting (a line says so, not sent, not kept); other text with a slash is said as it is. Tests:
tests/test_npc_memory.gd and the settings, save and prompt tests.

## 92. A font with umlauts and Scandinavian letters

- [x] Done

The user's word of 2026-11-06, with screenshots of the chat: å, ä, ö, ü, æ, ø (and the like)
show as boxes with hex codes, as the villagers answer in German and Danish too. Give the
game's pixel font the Latin-1 Supplement at least (À-ÿ, with ß), and the Latin Extended-A
letters the region's languages use, drawn in the font's style (generated, like the rest of
the art, or a pixel font with a licence that allows it); check the chat, the HUD, the
console and the menus, and add a test that every character of those ranges has a glyph.

Done: tools/art/ui.py builds the Latin-1 letters (À-ÿ), the Latin Extended-A letters of the
region and the typographic punctuation from the base letters plus two-row marks (hand-drawn:
ß æ Æ œ Œ ð þ Þ ı Ø and the stroked ø đ Ð ł Ł), and € £ © § µ ² ³ • ‹ › ‚. The line is now
12 px (was 10): two rows above the capitals are for the marks, as a label clipped them on its
first line. test_font_coverage.gd checks the glyphs; the README shows a chat with German and
Danish lines. Still missing: ½ ¼ ¾, ď ť ľ ĥ ķ ģ, Cyrillic and Greek, emoji; the en and em
dash are as wide as the hyphen (a glyph is at most 6 px wide).

## 93. Claude as a language model choice in Settings

- [x] Done: `ModelChat` (the POST, no redirects, the once-per-endpoint warning, the model list)
  with `OpenAiChat` and `ClaudeChat` on it; the provider is a row of `GameSettings.LANGUAGE_MODEL_PROVIDERS`
  (`openai` default, `claude`, with the protocol it speaks), each provider keeps its own
  endpoint, model and key (a section each in settings.cfg), and NpcDialogue and the page pick
  the chat by protocol, so a preset is one more row; Claude's numbers
  and the models that take fallbacks are in `[claude]` of data/npc_talk.cfg; the drop-down
  asks `<endpoint>/models` (not for a provider that needs a key, without one), debounced on
  typing, and warns once per failure. The tests use a
  small TCP server (`CannedHttpTest`); a real Claude is asked only with `ANTHROPIC_API_KEY`
  set, and was not here, so the requests follow Anthropic's API reference unverified against
  the live API.

The user's word of 2026-11-06: hook Claude up to the villagers' talk, as an option to pick
in Settings, not the default (the local test LLM stays the default).

- **Settings → Language model gets a provider choice:** "OpenAI-compatible" (the default:
  the test LLM, Ollama, LM Studio, hosted OpenAI-style APIs) or "Claude". Picking Claude
  fills the endpoint `https://api.anthropic.com/v1` and a Claude model (default
  `claude-opus-5-5`; `claude-haiku-5-5` named as the much cheaper choice), each still
  editable; the key field takes the Anthropic API key (plain text in settings.cfg, as the
  page says).
- **A Claude adapter** beside OpenAiChat, behind the same interface: POST
  `<endpoint>/messages` with `x-api-key` and `anthropic-version: 2026-10-21` headers; the
  template's system line as the top-level `system`, the example exchange and the chat as
  user/assistant turns; no `temperature` (current models refuse it); `max_tokens` about
  1000 (thinking counts against it; the reply is trimmed to two sentences anyway) and a low
  effort (`output_config: {effort: "low"}`); the reply from the `text` blocks of `content`;
  `stop_reason` `refusal` or any error gives a scripted line; server-side fallbacks
  (`anthropic-beta: server-side-fallback-2026-07-01`, `fallbacks: "default"`) on models
  that take them. No redirects, the key never logged, time-out as now.
- **The model is picked from a list** (the user, 2026-11-06), for both providers: the page
  asks the endpoint which models it has (`GET <endpoint>/models`: the test LLM lists what
  `make llm-pull` fetched; Claude's `GET /v1/models` with the key lists the Claude models)
  and shows them in a drop-down, refreshed when the endpoint or key changes and by a button.
  When the endpoint can't be asked (down, no key yet), the drop-down shows the saved model
  and a note, and the name can still be typed.
- Tests with canned HTTP responses like test_open_ai_chat.gd (success, refusal, error, the
  headers and body shape, both model lists); an optional real test only with an env var set. README: how to
  pick Claude, what it costs per line roughly, that the chat goes to Anthropic.

## 94. Refine the villagers' prompts for the local model; the default test model

- [x] Done

The user's word of 2026-11-07: have a worker refine the queries for the local model, also try
them on 3B; if 3B gives about the same quality, keep it as the default (they had agreed to
make qwen2.5:7b-instruct the default otherwise).

Done: `make llm-eval LLM_MODEL=<tag>` (tools/llm/dump_requests.gd has Godot write the requests
of 13 fixed scenarios with NpcPrompt itself; tools/llm/eval_prompts.py sends each `LLM_RUNS`
times and writes build/llm-eval/<model>.md with every reply and crude checks; `--compare`
puts two models side by side). Baseline of the old words, 5 replies per scenario, replies
without a failed check: 3B 52/65, 7B 55/65 (7 wrong language each). The new words
(data/npc_talk.cfg only, no change of shape): the example exchange is told of a blacksmith
who is not a villager, so the models stop copying Antje's answer and habits into other
villagers' mouths; the system line asks to answer what was said, says an English line gets an
English answer whatever the villager's home, to use the background only where it fits, to be
puzzled by phones and cars, to answer rudeness sharply; a memory is one sentence of at most
25 words in the first person. Result: 3B 57/65, 7B 60/65, wrong language 3 each, memories in
the first person 5/5 for both. Tried and dropped: a second example in German, a longer
language line, "never repeat their words". Decision: **7B is the default** (3B was faster,
1.1 s against 2.2 s a reply, but drifts into nonsense and loses the thread more often; the 7B
is Apache-2.0, the 3B has the Qwen Research License). Following the player's language is
still only about 3 of 5 in German after English for both; naming the language to the model
(the game detecting it) is an idea for later.

## 95. Villagers answer in the language the player speaks to them

- [x] Done

The user's word of 2026-11-07: if it can, the game should detect the language; villagers
respond in the language the player speaks to them. Task 94 left following a switch of language
at about 3 of 5 (German after English), with the prompt only asking for "the language the
neighbour just spoke in". The game detects the language of the player's line (English, German
or Danish, from word lists and letters in data/npc_talk.cfg) and names it in the prompt
("Hark answers in German."); a line too short to tell keeps the language of the player's last
line that could be told, and with none the prompt keeps today's words. Measured with
`make llm-eval` on the 7B and the 3B.

Done: `NpcLanguage` (game/state/npc_language.gd) scores the lowercased words of a line against the
short word lists of `[language]` in data/npc_talk.cfg (one point per word, two per telling letter: ä
ö ü ß German, æ ø Danish) and names the language if it has at least 2 points and more than any
other. Too short or tied ("Hi", "Moin", "Hej", a name): the player's latest earlier line in the chat
that can be told, else nothing, and the prompt keeps its old words (`language_unknown`,
`last_reply_unknown`). The last turn now says "Antje answers in German." and ends with "Antje's
reply in German:" (`trimmed_reply` strips whichever label was used); nothing is saved, it is derived
from the chat. A language that is none of the three (the user's Swedish case, "Tjena! Hur går det
idag för dig?", which Gemini answered with "I don't understand this foreign language") has a list of
its own (`other`) so that it is not taken for Danish, and is then not named; "å" tells no language
for the same reason, and the Danish words Swedish shares (det, går, dig...) are in both lists so
they favour neither. Eval: five new scenarios (German after a longer English chat, Danish after
English, "Moin" after German, "Hej" after Danish, Swedish), the language check counts telling
letters and has `LLM_API_KEY`/`--endpoint`/`--requests`. Replies in the right language, 5 per
scenario: with the old words (17 scenarios) 7B 72/85 and 3B 72/85; with the new ones (the same plus
Swedish, 18 scenarios) 7B 90/90 and 3B 86/90. The 7B had 0/5 on Moin and Hej and 3/5 on German after
a longer English chat before; the four 3B misses are it only echoing "Hej!"; Swedish: both answer in
Swedish, but the check can only tell they do not answer in English. Tried and dropped: carrying the
language in the earlier turns (not needed after this), a second wording (the first was already at 0
wrong language on the 7B). Not measured on Gemini: the sandbox refused to read the user's key.

## 96. Villagers with more background, family and friends, and a village they share

- [x] Done

The user's word of 2026-11-07: with Gemini the talk works well, but replies are not consistent
enough; villagers need way more background and instructions. A worker writes it for now
(the user may edit it later); relationships and family members must exist and be spawnable.
Plan: a longer sheet per hand-written villager (how they speak with sample lines in their
voice, the people they know by name and what they think of them, likes, wants, their day,
what they don't know or won't talk about); one village sheet every villager shares (the
village and its places, who lives where, landlord, pastor, Deichgraf, prices, this year's
news) so villagers don't contradict each other; family and friends named there are villagers
of data/villagers.cfg that can be spawned; firmer instructions (keep to what was said
earlier, never make up family or names, stay in one's own voice; perhaps a lower
temperature); made-up villagers get their sheet drawn once and kept. Hosted models (Gemini,
Claude) get the full sheets, local models a cut-down version. Seen by the user with Gemini:
"Aye." in the middle of a German talk (the English habit leaks into other languages).

Done: `data/village.cfg` (`VillageSheet`) is Wehlsbüll, a made-up marsh parish two hours north
of Husum in 1750: the village, places, who is who (Pastor Johann Martens, the Deichgraf Peter
Momsen, the Deichvogt Brar Feddersen, the Krug's Tete Jacobsen, the sexton Claus Thomsen, the
Amtmann at Husum, and the families), money and prices, this year's news (the cattle plague, the
dyke broken last autumn, the land militia), the church year and what people know of the world (the
Danish king holds all Schleswig since 1721, who speaks what), each topic with a full and a short
text. `data/villagers.cfg` gives each villager a sheet: home, speech as a manner (no English
words: "Says Aye" is gone), sample lines, people (family and friends by id, with kind and what
they think), likes, wants, day, habits, avoids, secrets. Four new villagers make the families
whole and can be spawned: `hinrich` and `boy` Boysen, `inken` Ketels (Boy's sweetheart), `gesche`
Hansen (Antje's friend, Kerrin's niece). `VillagerRules` checks that each one named is a villager
who names them back with a matching kind and sex, a parent is 15 or more years older, and a
married couple shares a home (tests/test_villagers.gd). Fixed on the way: Kerrin was 30 in 1717,
not a girl; Ocke's grudge is the king's Amt, not the duke's toll. Made-up villagers draw the whole
sheet once from the tables of `data/npcs.cfg` (trades with their day, speeches with sample lines,
homes on the edges of the parish, likes, wants, habits, avoids, secrets), have no people, no
surname of the village sheet, and a spouse with their own surname; save version 23 keeps the
sheet (a version 22 made-up villager is made up anew by their name, with another surname if theirs
is now one of the village's families). The system line has firmer rules (keep to the sheets and to what was said;
never make up relatives, names or places, say one doesn't know; one's own manner, the samples show
the manner, not the language) and then the sheets: in full for a provider with `needs_key` (Gemini,
Claude; `NpcDialogue.has_full_sheets`), cut down for a local model (the villager's essentials,
people by name and kind, speech, one sample line; the village line and who is who). Temperature
0.5 (was 0.7). The eval has 7 new scenarios (family, also in German; the husband's name again; another
villager; the pastor; the Deichgraf in German; a sister or brother they don't have, also in German),
a check for expected names and for made-up ones, prompt tokens, and `--full-sheets`.

Measured with `make llm-eval`, 5 replies each of 25 scenarios, replies without a failed check:
before, 7B 110/125 and 3B 87/125 at 515 prompt tokens (the 7B named no pastor or Deichgraf right
in 10 of 10, made up names 7 times, e.g. "Herr Müller"; "Aye" in 23 replies, three children
named Boy, Anna and Heinrich). After (cut-down, 0.5): 7B 123/125 and 3B 96/125 at 850 tokens
(1.65x; 7B 3.5 s against 3.1 s a reply), "Aye" in 6 English replies and none of the others,
"Pastor Johann Martens" and "Peter Momsen" named every
time on the 7B, no sister made up. At 0.7: 7B 118, 3B 95. The cut-down before trimming (1150
tokens) gave the 3B 110 and the 7B 121. The full sheets on the 7B: 50/50 (2 each) at 2375 tokens,
but 12.9 s a reply on the CPU. The 3B still often says it doesn't know the pastor or that Momme
has no children. Not measured on Gemini: no key here; the command is in tools/README.md
(`--full-sheets --endpoint ... --model gemini-3.1-flash-lite`). The cfg wins for a hand-written
villager (the coordinator's decision after review, as the user will edit the sheets): a loaded
game takes their sheet from data/villagers.cfg as it is now; the saved sheet only stands in when
their id has left the file.

## 97. Chat screen laid out like a messenger

- [x] Done

The user's word of 2026-11-07: the chat is hard to read with all the text and the font. Make
it look a bit like WhatsApp: the player's lines on one side and the villager's on the other,
as bubbles with more space between them, so the conversation is easy to follow (the user
showed a WhatsApp screenshot: bubbles in two colours, right for one's own lines, the time
small in the bubble's corner, the name above the other's lines).

- [x] Done: the chat is bubbles in a ScrollContainer: the villager's on the left (portrait left too, the player's right) in stone_dark with their name in gold above the first bubble of a run, the player's on the right in water_deep, the time small in each bubble's corner, at most 70% of the window wide, 2 px between lines of one speaker and 6 px at a change, "..." as the villager's bubble while they answer, a grey centred notice for `/clear`; it scrolls to the newest line (the scrollbar's `changed`). `line_text` is gone, unused. New debug flag `--chat-script` (canned lines, no model; a last `...` leaves the villager typing). The bubbles are StyleBoxFlat with a 3 px radius and no antialiasing, no art or palette change.

## 98. A flaky goose test

- [x] Done

Seen on 2026-11-07 while task 96 was verified: tests/test_geese.gd failed twice in a row on
one commit (a flock of 5 where 6 to 12 are expected) and passed on the third run. The wildlife
view calls `rng.randomize()`, so the test is not deterministic, and `_place_geese` can place
fewer geese than the flock size. Seed the test (or let it pass a seed) and make sure a flock
is always placed in full, or that the test asks for what the game promises.

Done: a flock got 4 tries per goose to find a dry spot not crowded by another, and 5 of 300
seeds came out under 6 geese. Now it gets 20 tries per goose (`GooseFlock.PLACING_TRIES`), and
none of 300 seeds came out short (a one-off measurement, not a test). On a narrow shore a flock
still makes do with fewer geese, as there is no room for more; SPEC says so. The wildlife tests
(tests/wildlife_case.gd) seed the view's dice, so they throw the same numbers every run.

## 99. Sea birds of the coast

- [x] Done

The user's word of 2026-11-08: sea birds that are active on the coastline, some pecking in the
Watt, some going into the water to catch fish; think about the birds that naturally occur in
the region (the North Frisian Wadden Sea in 1750). Candidates: oystercatchers, redshanks,
curlews and dunlin probing the mud flats; shelducks dabbling; herring and black-headed gulls;
terns plunge-diving for fish; cormorants diving and drying their wings. Ambient wildlife like
task 60's geese: on Terrain.MUD, SEA and SALT_MARSH and their edges, by season and time of
day, spawnable from the console.

Done: four species the visitor of the Wadden Sea surely sees, each with its own behaviour, in
data/wildlife.cfg: `oystercatcher` (groups of 2 to 5 on the mud and the salt marsh, all year, a
few at night; probe, look up at 6 tiles, fly off low at 4), `dunlin` (flocks of 12 to 24 only on
the mud, spring and autumn, fewer in winter; probe fast, take off at 3.5 tiles and swing round
in a wheel), `gull` (herring gulls on the mud, the salt marsh and the sea all year; walk, peck,
call, swim, fly off gliding at 3 tiles) and `tern` (common terns over the sea and the tideways
from late spring to the end of summer; fly along, hover, plunge in with a splash, now and then
a fish; after 2 to 4 dives they leave; no notice of the player). The waders are `GroundFlock`s
(the former `GooseFlock`, now with its numbers per kind in `FLOCKS`: a bunch instead of a V, the
wheel), the others `Gull` and `Tern`. The tide counts for the animals: above `flooded_tide`
(0.6) the mud is water (`WildlifeView.is_water`, `can_stand`), so waders on it fly off and
dunlin find none, gulls swim there and terns may dive. Made by hand (`spawn`, `--wildlife`)
the sea birds appear only where they live, so near the coast; no extra debug flag was needed
(`make screenshot AT=-298,-60 TIME=11:00 ARGS="--day=21 --wildlife=oystercatcher,dunlin"`).
Sheets from tools/art/sea_birds.py, no new colours. Not done: their calls (the oystercatcher's
piping, the gulls' laughing); cormorants, curlews, shelducks; waders roosting on the salt marsh
at high water as a flock of their own; a flock partly on the salt marsh only takes off when
the tide reaches its middle.

## 100. One shared outline helper for the art, and a contrast sheet

- [x] Done

From the visual review of 2026-11-08 (Fable; the user started it): the art generators have
eight outline helpers of their own (items.outlined has the only "darkest of the pixel's ramp"
table; animals, character, trees.shaded_blob, trunks, interior, buildings, chest and four in
boundaries). Move items' helper and its table to one place (e.g. `canvas.outline(picture,
colour=None, keep_bottom=False)` and `palette.DARKEST_OF`) and use it where the others do the
same; no change to how anything looks. Add a tool under tools/ that draws the vegetation atlas
rows over the ground colours of every look (season, frost, snow), so contrast can be checked.

Done: `canvas.outline` (outside ring; colour or a function of the surrounded pixel; `ignoring`
for the ground shadow) and `canvas.outline_edge` (recolours the border; `keep_bottom`), and
`palette.DARKEST_OF` / `palette.darkest_of`. `items.outlined` (now a thin wrapper), animals and
livestock, trees' `outline_in_bark`, trunks, interior and crafts, buildings and the chest use
them; every generated asset is byte-identical. Left alone: `character.outlined` (skips pixels
the body already outlines), `trees.shaded_blob` (outlines circles while shading them) and the
callbacks in boundaries.py (their own screen map, not a picture). `make contrast-sheet` writes
build/contrast_sheet.png (tools/README.md).

## 101. Tall grass, fern and reeds stand out from the ground

- [x] Done

The user's word of 2026-11-08: like the willows, some grass and reeds (and the bushes by a
stream) have too little contrast against the ground; a slight outline would help. The review
found tall grass, fern and reeds drawn in the two lightest shades of their ramp, 40-60 % empty,
with no dark edge and a 1-2 px foot shadow: they vanish on olive and autumn ground. Fix, within
the SPEC rule (no ink on vegetation, ramp-darkest outlines only, none on terrain): a ground
shadow under each clump (`trees.ground_shadow()`), the bottom third of a clump in its two
darkest shades with light shades on top, and the task-100 outline only round dense cores,
never single blade tips; check every season, dusk, night and snow with the contrast sheet.
The willow (TASKS Later, graphics review) is a task of its own.

Done: tall grass, fern and reeds each have `trees.ground_shadow`, a dense foot
(`trees.dense_foot`) in their two darkest shades rimmed with green_deep (no ink, no rim round
blade tips) and the lower third of the blades dark, light shades above. seasons.py keeps the
foot dark in autumn, bare, frost and snow (`_DARK_FOOT` for tall grass; `green_deep` is umber
for the golden reeds and the dry and frosted fern). No new colours. Checked on the contrast
sheet in every look and at night, and in screenshots of a stream with tall grass and reeds in
summer and autumn (docs/screenshots/outlines.png is before and after). Open: at night and on
autumn_light ground the light blades still sit close to the ground in value; the willow is its
own task.

## 102. A church with a wooden bell frame and a churchyard

- [x] Done

The user's word of 2026-11-08: the village needs a small church (review/art-review-2026-11-08,
task 9 and buildings row 5). A small marsh-village church of North Frisia in 1750 for the
parish of Wehlsbüll (data/village.cfg): a nave of brick (or tuff), a steep tiled roof, small
arched windows, a south porch; beside it a free-standing wooden bell frame (Glockenstapel) on
a brick base; the churchyard with a fieldstone wall and grave crosses, on the highest Warft.
Buildable or placed, no interior yet.

Done: two buildings the hammer builds (data/buildings.cfg), drawn in tools/art/church.py with
no new colours. The church, 6x4 (70 logs, 35 stone, 45 clay): tuff ashlar nave and lower
chancel, red pantile roofs that keep their light and shade under snow, three leaded arched
windows that light at night, a lime-washed south porch with the door; the interior system
was cheap, so it has a nave inside (maps/interiors/church.tmx: twelve pews, a table as the
altar). The bell frame, 2x2 (25 logs, 5 stone, 10 clay): oak on a brick base under oak
shingles, the bell in it; a building with an empty `interior_map`, so nobody goes in and none
of its tiles can be walked on (`Building.has_inside`). The churchyard: the existing
fieldstone wall, and grave markers made at the workbench (woodworking 15) and placed
outdoors, standing as an oak cross, a headstone or a fieldstone slab by their tile. The world
generator places none: the world has no village and its Warften are empty, so placing the
church there waits for a village; `--churchyard=<x>,<y>` puts the yard in view for
screenshots. Screenshot docs/screenshots/church.png.

## 103. A fisherman's hut, a jetty, nets and a boat

- [x] Done

The user's word of 2026-11-08 (review/art-review-2026-11-08, task 10 and buildings rows 6 and
12): the Ketels' home at the landing by the sluice: a small turf-and-thatch hut of tarred
boards, a net-drying frame and eel traps by the door, a plank jetty on posts at the water and a
flat rowing boat beside it.

Done: the fisherman's hut is a building (4x2, after the shack in data/buildings.cfg: tarred
boards under a reed thatch with a turf ridge, one small window; 25 logs, 5 stone, 15 reeds; a
7x6 room like the shack's). The landing is world objects placed with items (tools/art/
landing.py, atlas rows 47-50): a jetty laid a piece per tile that joins its neighbours and is
walked on over water or mud (the new `deck` and `placed_on` keys of WorldObjectTypes; placing
checks every footprint tile now), a rowing boat (2x1, water or mud), a net frame (2x1) and
eel traps. Jetty and boat at the workbench, frame and traps by hand. Snowy and lit looks as
the other buildings and objects. `--landing=x,y` places it for screenshots; docs/screenshots/
fisher-hut.png. Not done: fishing, a usable boat, nets as a crafting material, the net needle
in Inken's hands, mooring the boat on a rope.

## 104. Save upgrades for the last 10 versions only

- [x] Done

The user's word of 2026-11-08: the game is in development and practically only the user plays
it, so keep the code for save compatibility to the last 10 versions at most. With VERSION 23,
saves of versions 13 to 23 load; older ones are rejected the existing way (renamed .bak, a new
game). Drop `_upgrade_from_version_1` to `_12`, the constants and helpers only they use, and
their tests; state the rule in save_file.gd's header (when VERSION goes up, the oldest step
goes) and in SPEC "Saving".

Done: `SaveFile.OLDEST_VERSION := VERSION - 10` (13 today); older saves are rejected with a
message naming the versions read. Removed `_upgrade_from_version_1` to `_12`, their calls in
`read` (the plain chain stays), TOMATOES_TO_FLAX, TUNIC_AND_TROUSERS_TO_PERIOD, the
VERSION_10_* constants, UPGRADE_PILE_SPACING, `_saved_objects` and `_rename_items`
(about 250 lines), and their tests (test_save_upgrade_hotbar and _interiors deleted, the
rest trimmed). Kept for steps 17 and later: `_home_tiles`, `_clear_new_land`,
COAST_TERRAINS and the clearance constants. New tests: version 12 is refused, version 13
loads. The drop is a commit of its own (`Save: drop the upgrades from versions 1 to 12
(oldest read: 13)`), so an older save can be rescued from its parent; the rule is in
save_file.gd's header and SPEC "Saving".

## 105. make test runs the tests in parallel

- [x] Done

The user's word of 2026-11-08, after the code review measured the suite: one Godot process took
about 170 s, and the per-commit verify loop runs it once per commit.

Done: `make test` runs `tools/run_tests.py`, which spreads tests/test_*.gd over `TEST_JOBS`
headless Godot processes (default 8; `TEST_JOBS=1` is one process like before), each with its
own user:// (build/user-data-<i>) and log (build/test-<i>.log), after one shared import. The
files are balanced by their time in the last run (build/test-times, written from GUT's junit
output), by size until a file has a time. Every check holds per shard (a script that failed to
load, no tests run, "leaked at exit", Godot's exit status) and the exit status is non-zero if any
shard fails. build/test.log is the shard logs joined, ending with a summary block that keeps
GUT's labels (Passing Tests, Failing Tests), `[Failed] <file>: <test>` lines and the warning and
orphan counts. Wall time of a full run (22 cores, 1656 tests): TEST_JOBS=1 169 s, 4 52 s, 8 36 s,
12 29 s; 8 is the default as the gain flattens and several worker loops share the machine. Order
dependence: runs with 3, 4, 5, 8, 12 and 16 shards, with time-balanced and size-balanced
assignments, all green. The one failure found, `test_language_model_page` under load, was not
order but time: `CannedHttpTest` waited for the client by frame count, and a headless frame takes
microseconds, so it gave up before the client connected; it now waits 5 s of clock time.

## 106. The engine at 32×32 art pixels per tile, the 16 px art doubled for now

- [x] Done

The user's decision of 2026-11-08, after review/resolution-mockup-2026-11-08: switch to 32×32
art pixels per tile, with a native 640×360 view (20×11 tiles) at the widest zoom; "still retro
enough, but things are actually visible". This first step changes the engine and leaves the
look as it is: one tile size everywhere (TerrainTileset.TILE_SIZE and every pixel number that
follows from it, the viewport and zoom range in ViewMath, frame and cell sizes, window light
positions in data/buildings.cfg, ground item and shadow sizes, tests that pin sizes), and
every generated picture doubled pixel for pixel at the end of the art pipeline, so the game
plays and looks as today at zoom 1 while the art is redrawn group by group (tasks 107 to 116),
each group dropping its doubling. UI icons and slots stay as they are until task 115.

Done: `TerrainTileset.TILE_SIZE` is 32 and every pixel number of the game follows from it, or
from `TerrainTileset.ART_16_SCALE` (2) where it is measured on a 16 px picture: frame sizes
(`WildlifeSprites`), seats and poses (`PlayerView`), the object cell (3×5 tiles), the hops,
flights and speeds of the wild animals, contact and flight shadows (drawn on the 16 px grid,
scaled), hit particles, sweat, the thought bubble, the "z"s, ground items, the name tag, the
build and take-down frames. The shaders of the art (sway, lily pads, water, mud, fire, rain
splashes, rain and snow, fog) work on the art's pixels through a uniform `art_scale`
(art_scale.gdshaderinc). `ViewMath`: zoom 1 is the widest view, a native 640×360 (20×11 tiles,
×3 at 1080p and ×4 at 1440p; tested), where the game starts; zoom 2 is the closest (320×180);
`make screenshot ZOOM=` takes 1 to 2. tools/art/generate.py scales the files of `DOUBLED` from
`canvas.TILE` (16) to `canvas.GAME_TILE` (32) pixel for pixel as its last step; each of tasks
107 to 116 takes its group out (docs/art-style.md, "Resolution", says how). Not doubled: item
icons, UI slots and frames, the chat portraits (task 115). The doubled pictures' own pixels in
data are doubled too (`sprite_height`, `window_lights`); the sound reach is in tiles. Positions,
speeds and reach were in tiles already: no saved value is in pixels, the save format is the same.
Screenshots at both zooms (summer, snow, rain, fog, night, the church and its lit windows,
inside, livestock, wildlife, riding, passing out, sweat, the highlight, the build ghost, a felled
tree, a chat, villagers, the console, the inventory) match the ones before pixel for pixel but
for animation and random placement. The README's camp and zoom pictures are retaken.

## 107. 32 px art: ground (terrain, paths, soil, water, mud, the dual-grid looks)

- [x] Done

Done: every terrain layer, its edge tiles and decorations, the wet look of tilled soil and the
clay hint are drawn at 32 px (tools/art/terrain.py, the wet soil moved there from
crop_icons.py) in the style of the mockup and left `DOUBLED`. From the art review: the ground
is calm behind small figures (a base colour with blade roots and small tufts, a dark root
fanning to lit tips, gathered in patches by a tile-periodic noise, few light pixels, no outline
on terrain); tilled soil reads as earth, not stacked logs (one broken row of light on the crest,
ragged bands, square field edges dark under the turf); autumn keeps the marsh's grass green with
olive tips, straw only on the dry grass of the Geest (`seasons.LAYER_REMAPS`), and the salt
marsh reads as marsh (olive turf with red-purple glasswort in autumn, cool green patches in
summer, where it was purple all over and dry olive). The path is
packed earth worn pale in patches with clog prints and pebbles; the mud has wavy ripple marks;
pebbles, lily pads, caps and pools are shaded with forms.py. Every layer keeps its number of
tiles and decorations, so no game data changed. The ground's shaders (water, mud, lily pads,
swaying decorations) get `art_scale` 1 from AmbientMotion, or 2 in the classic art; the tide's
relief is in world pixels; the meadow flowers are still 16 px art, scaled up in their row of
the decoration atlas, with a sway material of their own (`flower_sway`, art_scale 2). The
classic art (task 117) has the old ground: terrain.py, the ground part of seasons.py
(`ground_looks.py`) and the wet soil and clay hint (`ground_overlays.py`) of commit acf236e,
byte for byte the files before; the terrain tileset is the first tileset to follow the art set
(`TerrainTileset.show_art_set` swaps its atlases' pictures, as both sets have the same tiles, a
test checks it; no extra tileset is built, so the tests are no slower), and so does the wet
soil. WorldView now shows the chosen set when given a world, as it is made before Main reads
the setting (`--classic-art` at start). Checked in screenshots at zoom 1 and 2: grass, lush and
dry grass, floodplain and river banks, wetland, a desire path, a field tilled, wet in rain and
with crops, the coast (salt marsh, a Warft with its Fething, the tidal mud at low and high
water), spring, summer, autumn (Geest and marsh), bare winter, frost, snow, the dusting, dusk
and night, and both art sets (at start and after F7); `make contrast-sheet` (plants read on
the new ground in every look). README pictures retaken: camp, zoom, coast, desire paths, field,
art sets.
Left for later: the coast's dyke, the Knick, fences and walls (boundaries.py) and the Ewer
(coast.py) are rows of the object atlas, so they stay with tasks 108 and 111; the meadow flowers
(task 108) look coarse on the new ground until they are redrawn; the seasons, meadows,
landscape and outlines pictures of the README show mostly plants and were not retaken; the
water's ripples and the lily pads' drift work in art pixels, so they are finer and move half as
far in the new art; the wet soil's patches are the same on every tile, as before.

## 108. 32 px art: plants (trees, the willow, bushes, tall grass, fern, reeds, flowers, decorations)

- [x] Done

Done: every plant row of the object atlas is drawn at 32 px per tile in the style of the mockup
(trees.py, beech.py, birch.py, alder.py, willow.py, trunks.py, the tall grass in meadow.py,
reeds.py), and so are the meadow flowers of the decoration atlas (flowers.py), which lose their
own sway material. The oak, beech, alder, birch, the bushes and the sapling have crowns of leaf
sprays (`trees.foliage`), round furrowed trunks spreading into roots, and bare limbs that fan out
into twigs (`trees.crown_limb`); the spruce hangs in drooping tiers; the pine, the dead tree,
stumps, trunks, stones and boulders keep their shapes with more detail; tall grass and reeds are
two-pixel blades with a lit edge over the dense dark foot of task 101, the fern a fan of combs.
From the art review: the pollard willow has a dense, rounded crown with a dark edge and a shaded
underside, rods below and over it, silver leaves, a knobbly head and a mud-coloured trunk on its
ground shadow (bare: umber rods up to the middle); tall grass, fern and reeds read on autumn
ground (autumn tall grass turns `reed` where it was the dry grass' own `autumn_light`) and, a
little weaker, at night; no vegetation is outlined in ink (the dead tree, its stump and the
trunks are rimmed in their darkest bark); `maple_light` is `leaf_orange`. Snow caps are twice
as deep on the plants, and snow lies along the bare oak's and beech's limbs. The atlas is
written at 32 px (cells of 96×160, `canvas.GAME_OBJECT_CELL_*`); its rows not drawn anew are in
`DOUBLED_ROWS` and scaled up after their looks are made (not in `object_atlas()` itself, so their
snow caps and frost specks keep the 16 px grain): byte for byte the rows of before, in every look.
The plants' sway profiles are measured on the new art in the world's pixels, and AmbientMotion
gives their materials art_scale 1, or 2 with the profiles halved in the classic art; the crops
keep 2. The plants now sway half as far on screen as before, on purpose (the user, 2026-11-08:
the calmer world is better, the old one felt busy), and in an order (the user: "grass and crops
usually move more than large trees"): tall grass, reeds, fern and the meadow flowers most, the
bushes and the sapling less, the big trees least and slowest; in a light air the grass's tips
flick while the trees stand still (a test checks the order). Task 109 matches it for the
crops. The trees' `sprite_height` is measured anew. The classic art (task 117): the plant
generators of commit e303759 under tools/art/classic/ (`object_looks.py` is the object part of
seasons.py) write the whole classic object atlas, byte for byte the atlas before, and the
classic decorations' flowers; the object tileset follows the art set (`ObjectTileset.show_art_set`,
a test checks both sets have the same cells). Checked in screenshots at zoom 0.5, 1 and 2 (the
camp, a wood, the marsh ditches with willows, a meadow through spring and summer, the forage and
felled scenes) in spring, summer, autumn, a rainy autumn evening, the night, bare winter and
snow, and in the classic art; `make contrast-sheet` for tall grass, fern, reeds and the willow.
README pictures retaken: camp, zoom, seasons, meadows, landscape, outlines (the new art only),
harvest (the stumps and trunks, without the fall), forage.
Left for later: the camp (fireplace, bedroll), walls, fences, the dyke and the placed objects
stay doubled for task 111 (it takes them out of `DOUBLED_ROWS`); on dry autumn grass the light
blades of tall grass still sit close to the ground (the foot and the olive edges carry it). Not
changed, as they are distances in the world's pixels and right in both art sets:
`FallingTree.IMPACT_HEIGHT` and the see-through sprite's hop and edge. The screenshot window was
1474×439, so the README pictures are wide strips stacked.

The objects atlas (assets/objects*.png) is shared by 108 and 111 and has one cell size for all
its rows: do 108 and 111 together, or the first of them writes the whole atlas at 32 px, with a
`DOUBLED_ROWS` set inside `object_atlas()` for the rows not yet redrawn (scaled up there instead
of by `DOUBLED`), and the sway materials' `art_scale` per type (2 for the old rows, 1 for the
native ones). contrast_sheet.py needs no change.

## 109. 32 px art: crops and fields

- [x] Done

Done: every crop's four growth stages and its dead look are drawn at 32 px per tile
(tools/art/crops.py) after the field of the mockup, and left `DOUBLED`: a cell a tile wide, two
tall for the tall crops, the plants' feet on the lowest ridge of the new tilled soil (task 107),
on a shadow of dark earth; leaves, heads, roots and fruit are rounded forms shaded with forms.py
and rimmed in the darkest shade of their own colours (no ink), stalks, awns, flowers and pods
drawn over them. The sown mound, seed leaves, turnip rosettes and the purple-shouldered root, a
potato bush of leaflets that flowers and dies back yellow over its tubers, feathery carrot
fronds over orange shoulders, the mockup's cabbage, onion bulbs with fallen tops, wheat with
paired grains and awns, peas on brushwood, runner beans on a pole, flax in blue flower and boll,
wild strawberries and the small green squash. From the art review: the Geest grains rye and
buckwheat are new crops end to end (data/crops.cfg, their sheets, seed and produce icons in
crop_icons.py, flour from either in recipes.cfg; neither is eaten raw); the crops still read on
the dark soil. The crops sway on the pixels of their art (`AmbientMotion.crop_material` by cell
size and art scale, the material chosen per crop by the sheet it shows): calm like the plants
of task 108 and in the grass's band, more than the big trees (`CROP_SWAY` strength 1.3, it was
0.6 on doubled pixels), so their tips flick in a light air while the trees stand still;
test_plant_sway.gd checks the order, docs/art-style.md writes it down. No other number of the game was measured on crop art
(the cells' sizes come from the sheets). The classic art (task 117) has the old crops: crops.py
of commit f2c24f8 in tools/art/classic/, byte for byte the old sheets, loaded through `ArtSet`
by `ObjectTileset` (`show_art_set`, called by WorldView); rye and buckwheat show their new sheets
in both sets. The drawing helpers of the old crop art (`KEYS`, `Surface`) moved to
crop_icons.py, their only other user. `--field` lays the crops out three to a row on one tilled
patch, so the whole field fits into the widest view. Checked in screenshots at zoom 0.5, 1 and
2: every crop and stage in summer, autumn, under snow, at dusk and at night, in both art sets;
README field picture retaken.
Left for later: `make contrast-sheet` draws atlas rows only, so the crops were checked on the
soil in screenshots and sheets instead; the classic crops now sway with strength 1.3 on their
doubled pixels, more than they did; the crafting menu lists three recipes named "Flour" (from
wheat, rye or buckwheat); a buckwheat dish (pancakes, groats) would need a new item (task 115);
the potato bush is a dome of small leaflets that reads as a bush but could be leafier.

## 110. 32 px art: buildings (shack, fisherman's hut, Kate, longhouse, hall house, barn, church, bell frame) and their seasonal and lit looks

- [x] Done

Done: every building is drawn at 32 px per tile (tools/art/buildings.py, church.py) after the
Kate of the mockup, and left `DOUBLED`: thatch in 7 px courses with a broken lit top, reed ends
of mixed length and a ragged shadow line, rolled eaves 12 rows deep with a ragged dark hem,
eyebrow dormers, crossed ridge sticks and turf ridges; round fieldstones each lit on its own;
windows of 5 px panes with a glint (lit, each pane one warm colour), braced shutters on hinges;
the Kate's split teal door, the longhouse's arched green door, the barn's braced double doors,
the ledged doors of the huts, the hall house's Grote Door with a carved beam, herringbone and
slanting brick, bargeboards crossing in horse heads; brick 8 px long, half-timber 4 px wide,
tarred boards with battens, a lime wash with flakes and rain splash; the church's tuff ashlar,
pantiles 10 px wide, leaded windows in brick arches and the porch, the bell frame's oak, bronze
bell and shingles. The doors are about 60 px high, so the people (61 px) fit through them;
every picture keeps its size (the walls are taller, the roofs a little lower), so the classic
pictures need no padding and stand where they stood. From the review: the buildings table's
materials (thatch, timber, brick, lime, green and teal paint); the outline in the darkest shade
of the roof's ramp, the eaves' shadow and a ground shadow kept; the longhouse door stays on its
long side, as art-style.md says (a Geesthardenhaus), and SPEC now says so too. The window lights
in data/buildings.cfg are measured on the new windows (a test checks they are on lit glass);
the stork stands `ROOF_FOOTING` (4 px) into a roof, right in both sets; no other number in the
game was measured on building art (the build ghost and the sprites take their size from the
picture). The snow look is the shared `seasons.house`, unchanged. The classic art (task 117)
has the old houses: buildings.py and church.py of commit e303759 in tools/art/classic/, the
pictures loaded through `ArtSet` (`BuildingViews.picture_path`, the build ghost; WorldView
shows the buildings anew on F7). New debug flag `--street=<x>,<y>`: every building in a row on
a lane of grass. Checked in screenshots at zoom 0.5, 1 and 2: every building in spring,
summer, autumn, bare winter, snow, at dusk and at night with the windows lit, in both art sets,
the player at the doors; README pictures retaken (buildings, church, fisher-hut, build, take-down).
Left for later: the Kate variants of the review (task 120); the graves in church.py are world
objects (task 111) and still 16 px; `make contrast-sheet` draws atlas rows only, so the
buildings' contrast was checked in screenshots on every ground; the snow look keeps 2 to 4 rows
of the eaves' dark underside, which is thinner at 32 px than it was (a native snow look would
mean a copy of `seasons.house`, which task 108 owns); in the classic art the window lights sit
on the new windows' places, a few pixels off the old windows.

## 111. 32 px art: walls, fences, the dyke and placed objects (chests, stations, the landing, graves)

- [x] Done

Done: every row of the object atlas is drawn at 32 px now, so `DOUBLED_ROWS` and `doubled` are gone,
and so are the explicit doublings of the stations, the grave marker and the indoor chest
(`write_interior`, `interior.chest_picture`) and `standing_outdoors`' 16 px shadow (it uses
`trees.ground_shadow`); `bedroll_cover.png` left `DOUBLED`. Each placed thing is as big as its
doubled picture was, so it stands where it stood and no number of the game changed (the fireplace's
flame box, the bedroll's cover row and the jetty's deck are the same). The lines (boundaries.py):
the Knick a turfed bank with a low dark core and hazel and hawthorn bushes drawn as leafy domes,
each drawn whole by the tile it stands on so no bush breaks at a seam; the wattle fence's rods woven
round stakes; the fieldstone wall's squat stones in two courses; the dyke (review task 5) a bank
with a flat crest and a sheep track that bends round each corner in a quarter circle, which keeps a
straight arm's distances across the tile's sides, so a dyke on the slant (a stair of corners, as the
generator makes it) is one winding bank and needs no new masks or game data; green in autumn like
the marsh. The camp (camp.py): a ring of field stones, ash, embers and three split logs; the quilted
bedroll with its blanket roll and its cover. The chest, the carved chest with tulips, the workbench,
the kiln, the oven and the cupboard (chest.py, crafts.py), the oak cross, headstone and granite slab
(church.py), the landing (landing.py). The Ewer (coast.py) is in scale with the people (the review):
a hull about seven tiles long and a mast more than twice a person's height, a picture three cells
wide; a type's `cells_wide` makes ObjectTileset create one tile over that many cells (and
WorldView's stand-in sprite take them), the Ewer's footprint is 7x1 (`MAX_FOOTPRINT` 7x2;
landscape.cfg's Ewers need 7 tiles of mud) and generate.py's `atlas_cells` splits the picture. No
save change: Ewers come from the seed, so an old world keeps those with 7 tiles of mud and loses the
rest; a jetty or boat built far out on the mud of an old save could now overlap a kept Ewer's longer
hull (rare, accepted). Snow lies twice as deep on all of them. Their item icons and ground items are
made from the new pictures (task 115's `items.icon_of` takes a 32 px picture, halving one much
bigger than an icon). fire.strip and fire.burning take every picture at the game's tile now.
canvas.py's object cell is defined at 32 px (`GAME_OBJECT_*`); `OBJECT_*` stays for the classic
art's old generators, which import it. The classic art (task 117): boundaries.py, camp.py (with the
old bedroll and cover, replacing task 112's bedroll.py), chest.py, coast.py, crafts.py and
landing.py of commit ec0b1af in tools/art/classic/, byte for byte the classic atlas before but for
the Ewer, which lies in the middle of its three cells; the classic art also writes the stations and
the grave marker placed indoors. New debug flag `--yard=<x>,<y>`: the chest and the stations in a
row with a Knick, a wattle fence, a wall and a dyke on the slant behind them. Checked in screenshots
at zoom 0.5, 1 and 2: the camp by day, at dusk and waking on the bedroll, the yard in summer,
autumn, bare winter, snow and at night, the landing in summer and on a snowy winter night, the Ewer
at high and low water beside the player, the river dykes of the marsh, the churchyard by day and on
a snowy night, in both art sets; `make contrast-sheet` for the four lines. README pictures retaken:
camp, stations, waking-in-bed (the bedroll), church (the graves and the wall), art-sets; new: ewer,
landing.
Left for later: the farm yard objects of review task 6 (task 122); where the dyke is two tiles wide
(2x2 blocks at the river's bends, T-junctions) it shows a ring with a dip in the middle, as a 4-side
mask cannot know the diagonal neighbour; the fisher-hut, landscape and coast pictures of the README
were not retaken (the hut would not place by the water in the shots; the new landing and Ewer
pictures show what changed); the classic Ewer stands on the new 7x1 footprint, which is wider than
its picture; the wattle fence and the wall seen end-on (running north-south) are thin columns, as
before.

The objects atlas is shared with 108; see there.

From task 112: draw the bedroll's row of the object atlas and its cover (`camp.bedroll_cover`,
assets/bedroll_cover.png, still in `DOUBLED`) at 32 px, and remove the explicit `doubled(...)`
of the stations and the grave marker in `write_interior` (generate.py) and of the chest in
`interior.chest_picture` once chest.py, crafts.py and the graves are drawn at 32 px.

## 112. 32 px art: interiors and furniture

- [x] Done

Done: the rooms and their furniture are drawn at 32 px per tile (tools/art/interior.py) and
left `DOUBLED`: floor bricks 16x8 in a herringbone, calm (one colour of brick, soft joints,
a worn spot on every third) and beaten clay trodden in soft patches, an oak ceiling beam over smoked plaster, a wainscot of raised panels, oak wall
plates and corner posts, a deep-set window, the doormat plaited; the bed with its canopy and
curtains, the box bed, the sleeping mat, the table with a candle, a pewter plate and a jug,
the stool, the bench and the wall bench with turned legs and spindles, the stall partition,
the hay pile, barrel, sacks, crate and the plate rack with Delft and pewter plates, and the
hearth (a lime-washed hood with soot, Delft tiles with flowers, buff brick, logs and an iron
pot). From the review: each piece outlined in the darkest shade of its own ramp, a dithered
floor shadow under what stands free. Every picture keeps its size and every tile its id, so
the maps are unchanged. The beds fit the 61 px figure of `PlayerView.LYING_POSES`: the
blanket and the cover go down to the foot, and the box bed's front board starts under the
figure; in the box bed the figure lies 2 px left and up (`LYING_POSES`, head to the left), so
its head is on the pillow inside the bed. The bedroll at the camp (16 px, the atlas is task
111's) is two rows longer, so it reaches the foot of its footprint and its cover hides the
clogs; the classic object atlas keeps the old bedroll, so the classic set has the old cover
too (tools/art/classic/bedroll.py, `ObjectCover` loads it through `ArtSet`). The hearth's flame box is unchanged (`FIRE_PROFILES` keeps its numbers); its still
picture shows the native flame (`fire.strip` and `fire.burning` take the pictures' scale),
and its light is placed in native pixels. The classic art (task 117) has the old rooms:
interior.py of commit f2c24f8 in tools/art/classic/; the atlas, the furniture, the covers and
the ghost of a placed piece load through `ArtSet`, and `InteriorView` shows its room anew on
F7. The stool's item icon keeps the 16 px stool (now in crafts.py); the indoor chest, the
stations and the grave marker are still 16 px art, scaled up in write_interior. Debug flags:
`--inside=<building>` walks into the first building of that type (with `--street`, every
interior can be shot), and `--sleep` with `--inside` lies down in the room's first bed.
Checked in screenshots at zoom 0.5, 1, 1.2 and 2: every interior (shack, fisherman's hut,
Kate, longhouse, hall house, barn, church) by day and at night with the hearth lit, waking in
the straw mat, the bed, the box bed and on the bedroll, in both art sets (at start and after
F7). README pictures retaken: interiors, day-and-night, waking-in-bed.
Left for later: the chest indoors comes from chest.py and the stations from crafts.py (task
111), scaled up until they are redrawn; the bedroll's row of the object atlas is task 111's,
which may draw it at 32 px with its cover (then `BEDROLL_COVER_FROM_ROW` and the cell are
native); rooms have no seasonal looks, so seasons, frost and snow change nothing inside;
`make contrast-sheet` draws atlas rows only, so the furniture was checked on brick and clay
in screenshots; the screenshot window here is 1474x439, so the README pictures are cut from
shots at zoom 1 and 1.2.

## 113. 32 px art: the player and the villagers (character layers, every action, riding, collapse, portraits)

- [x] Done

Done: every character layer is drawn at 32x64 (tools/art/character.py, villagers.py) in the
style of the mockup: rounded forms shaded by the light from the top left (a new
tools/art/forms.py with the mockup's shapes and shading), faces with eyes, a glint, brows, a
nose shadow, cheeks and a mouth, collars, buttons and pockets, full sleeves gathered at the
wrist, knee bands with a button, white stockings and clogs with a lit top and a dark sole. All
layers draw on one `Figure` (head, torso, arms and legs of a facing and pose), so the looks still
combine; the hands stay in front of what is worn. The walk, passing out (64x64 frames), riding,
the held hoe, the sleeping "z" and the thought bubble are redrawn; the chat portraits are the top
of each layer's front frame, so they have the new faces (the chat layout is unchanged). From the
art review: a white stocking cap besides the red one (now a stocking cap with a tip and tassel),
a striped apron and a tricorne, worn by made-up villagers (data/npcs.cfg, data/npc_talk.cfg).
The people stand on the animals' contact shadow. The character sheets, the "z" and the bubbles
left `DOUBLED`; the game's numbers measured on them are native (head tops and sweat in
`TirednessView`, the name tag, the lying poses, the "z"s, the bubble's pop, the character
preview at one UI pixel per art pixel). The seat on the horse keeps its row, as the horse is
still doubled 16 px art: task 114 measures `SEAT` anew. Checked in screenshots at zoom 1 and 2
(every facing and walk frame, riding the bay, the grey and the pony from the side, the front
and behind, the collapse, beds, villagers of every look, the portraits, the inventory, summer, snow and night); README pictures retaken.
Left for later: the trades' props in hand (net, crook, ...) for task 115; the bedroll's and the
beds' covers (16 px art) are shorter than the 61 px figure, so its clogs show at the foot of
the bedroll: tasks 111 and 112 draw the covers to the foot; the waking picture shows the shack
and the camp only (a Kate or longhouse would not place by the camp with `--house`).

## 114. 32 px art: farm animals (cow, sheep, chicken, horse, dog, cat, rabbit), every action

- [x] Done

Done: every farm animal sheet is drawn at 32 px per tile (tools/art/livestock.py) in the style
of the mockup, with every action and frame it had: idle, walk, graze, sleep and run, the cat's
crouch, creep and pounce, the saddled horse and the ridden horse from the side, the front and
behind, standing, walking and trotting. The four-legged animals share `quadruped_frame`: body
and neck with the head as polygons shaded as one rounded form (forms.py, with a new
`top_light` and `shade_by_level`), legs as limbs through their joints swung and folded for each
step, the far ones a step darker; the face, ears, manes and tails in strands and each look's
marks by hand (pied patches shaded with the body, dapples, a dun's stripe, a bay's points and
blaze, tabby stripes, wool curls). The cow's head is hand-drawn and transposed for grazing; the
pony is the horse at four fifths; the hen and the rabbit are drawn whole per pose. In scale with
the 61 px people (the horse 57 px to the withers, the cow 40 px to its back), the small animals
a little larger than life; the outline is the darkest colour of each coat. The farm sheets left
`DOUBLED` (the glob split so the wild animals stay doubled for task 116) and their numbers are
native: the cell sizes in `WildlifeSprites` (cow 72x54, horse 88x76), the contact shadows of
`FarmAnimalView` (`Animal.art_scale` 1), and in `PlayerView` the `SEAT` and `PONY_SEAT` measured
on the new saddles, `RIDE_LIFTS` and the ridden horse's shadow. From the review of task 113: a
blue saddle cloth sets the rider's brown breeches off from a bay. Checked in screenshots at
zoom 1 and 2 (every species and look, summer, snow and night, the hunting cats at dusk, riding
the bay, the grey and the pony from the side, the front and behind, walking and trotting);
README pictures retaken (livestock, dogs, cats and horses, the hunt, riding). The 16 px farm
animals are the classic art (task 117): their old livestock.py and animals.py in
tools/art/classic/, the cow's and the horse's classic cells set in the new, larger ones, the
sheets loaded through `ArtSet` (FarmAnimalView in `ArtSet.VIEWS`, the ridden horse in
PlayerView), the rider seated where it was on the classic horses (`CLASSIC_SEAT`); checked in
both sets (cows, horses, riding).
Left for later: `make contrast-sheet` draws atlas rows only, so the animals were checked on
grass, snow and night in screenshots instead; the riding legs of the people (task 113) are
short for the 32 px horse, so from the front the rider's feet hang at the saddle cloth rather
than down the barrel; a lying animal's folded legs mostly hide under its body; the contact
shadow is three art rows tall, so under the native animals it is half as tall as under the
still doubled ones (task 116 may even them out).

## 115. 32 px art: items and icons (ground items, inventory icons, the UI slots that show them)

- [x] Done

Done: every item icon is drawn at 32 px (tools/art/items.py, tool_icons.py, crop_icons.py and
the icon parts of meadow.py, reeds.py, crafts.py, church.py and landing.py) in the style of the
32 px art: forms.py shading from the top left, wood grain, cloth folds, iron with a lit and a
dark rim and a bright edge, each a body outlined in the darkest shade of its own ramp
(`items.RIMS`). The items on the ground are the bodies at half size (16 px, `items.ground_item`),
no longer `DOUBLED`, on a contact shadow (`GroundItemView`); the drop's hop and the sprite
offset are in world pixels. The UI keeps its 20 UI pixel slots and shows a 32 px icon at half
size in 16 UI pixels (`SlotView.ICON_RECT`, `ItemIcon` for the recipe rows and the picked
icon), an icon pixel as big as a world pixel at the widest zoom, through
`sharp_pixels.gdshader` so the pixels stay square at 1.5 window pixels; 36 UI pixel slots for
full-size icons were tried in a screenshot and turned down (the hotbar took over a third of the
screen). The seed sacks are one linen sack told apart by the crop's string, its produce painted
on it and its seeds. From the art review: the pickaxe is the Geest's pick for grubbing out and
splitting the fieldstones of the till (a point and a chisel), in art-style.md's tools; the
spade has an iron shoe. The three flour recipes have names of their own (`name` in
data/recipes.cfg, `RecipeRules.name_of`): Wheat, Rye and Buckwheat flour, a long name clipped; the flour is one
item. A buckwheat dish: buckwheat pancakes, 2 from 3 buckwheat at the fire (cooking 15, 14
energy). The classic art (task 117): the old icon generators in tools/art/classic/
(`item_icons.py`, `tool_icons.py`, `crop_icons.py`, `craft_icons.py`), the icons and the doubled
ground items under assets/classic/, byte for byte main's; the slots, recipe rows, picked icons
and ground items load through `ArtSet`. Debug flag `--items=<x>,<y>`: every item on the ground
and in the inventory. Checked in screenshots at zoom 0.5, 1 and 2 in spring, summer, autumn,
frost, snow, dusk and night, in both art sets, and the character screen, the crafting menu and
the hotbar; README pictures retaken (character, crafting) and added (items).
Left for later: the sickle, flail, rake, pitchfork, buckets and yoke have no job in the game
yet (grain harvest and threshing, hay, carrying water), so they have no icons; the icons of the
items that place a world object (chest, stations, grave marker, the landing's pieces) are their
16 px world pictures doubled until task 111 redraws those (`items.icon_of` then needs no
doubling); the station-menus and chest README pictures show the new icons but were not
retaken; `make contrast-sheet` has no items, so they were checked on screenshots over grass,
sand, snow and dyke instead.

## 116. 32 px art: wild animals (birds, flocks, storks, geese, sea birds, deer, squirrels, rabbits, mice, frogs, bees, butterflies) and effects (fire, particles, rain splashes, hit effects)

- [x] Done

Done: every wild animal is drawn at 32 px, every action and frame it had, in the style of the
mockup: rounded forms shaded from the top left (forms.py, whose ellipse can now be turned),
eyes with a glint, legs with joints (the deer's knee and hock), each outlined in the darkest
colour of its own coat or plumage. The sparrow, rabbit, squirrel, roe deer, bee, butterflies,
mouse and frog are in animals.py; the birds are put together by a new bird_forms.py (body,
tail, neck, head, bill, folded or open wings, legs drawn over the outline) for the sparrow, the
stork and goose (birds.py) and the oystercatcher, dunlin, gull and tern (sea_birds.py). From the
art review: the small animals are drawn a little larger than life (cells twice the 16 px ones,
the sparrow, rabbit, bee, butterflies and dunlin bigger still), and every animal stands on a
contact shadow, now a flat oval in the game's pixels (`Animal.draw_contact_shadow`, its half
widths native for the wild and the farm animals and the people; `Animal.art_scale` and the
`scale` parameter are gone); the birds' flight shadows (`GroundShadows`) are native too. The
wild sheets left `DOUBLED`; their frame sizes in `WildlifeSprites` and the wild animals' hops,
speeds and margins are in the game's pixels. The classic art (task 117) has the old wild
animals and flames (tools/art/classic/ birds.py, sea_birds.py and fire.py of commit 2793065,
the grown cells set in the new ones); the wild sheets and the flame strips load through ArtSet,
and the animals, the flocks' birds, WorldView and InteriorView (the fires) join ArtSet.VIEWS.
The hit particles, the splashes and the weather are code and look new in both sets. The
effects: the flame's loop is drawn at 32 px (fire.py; fire.gdshader works on the world's pixels,
the fireplace and hearth around the flame are scaled up into the strip), the hit particles fly
and are drawn natively (leaves with their corners left out and a shaded side, long needles,
round snow, chips, drops), the rain's splashes show a streak, a crown and a ring, and the
weather (rain, snow, wind streaks, leaves, fog) works on single pixels; `art_scale` is left to
the plants, water, mud and lily pads. Checked by eye in screenshots at zoom 1 and 2 (every
species and action, flight and shadows, the stork on a roof, gulls swimming, terns diving, the
fire by day and night, hits, rain, storm, snow, fog, summer, autumn, dusk) and in sheets over
grass, sand, snow and water, and the wild animals and the fire in the classic art too; README
pictures retaken (wildlife, mice and frogs, sea birds, weather, camp, zoom).
Left for later: the still pictures of the fireplace (atlas cell) and the hearth keep their 16
px flame until tasks 111 and 112 redraw them; the Ewer (an object of the coast) is not in this
group: its scale against the 61 px people is for task 111; `make contrast-sheet` covers the
object atlas only, so the animals' contrast was checked on sheets over the grounds of every
look instead; the day-and-night picture (the hearth inside a house) and the harvest picture
were not retaken (`--inside` did not get into a house in time).

The redraw takes in the findings of review/art-review-2026-11-08 (the user, 2026-11-08: "make
sure the redraw includes the art review feedback"); each group's brief points at the review and
lists its part:
- every group: the contrast and outline rule (the darkest shade of an asset's own ramp at its
  outer edge against the ground, a ground shadow, never ink on vegetation, none on terrain;
  canvas.outline / outline_edge from task 100) and a check with `make contrast-sheet`;
- 107 ground: autumn is not one straw yellow everywhere (the marsh stays green until November,
  straw only on the dry Geest); tilled rows that don't read as stacked logs (a softer ridge
  highlight, no rounded ends); a calmer ground behind small figures;
- 108 plants: the pollard willow (a dense crown with an edge, rods over it, trunk in mud/mud_dark
  rather than grey stone, its ground shadow); tall grass, fern and reeds legible on autumn and
  night ground (task 101 left those weak); rename `maple_light` while touching seasons.py;
- 109 crops: the Geest grains of the village sheet (rye, buckwheat) if cheap, else a task;
- 110 buildings: the longhouse door as SPEC and art-style.md say (or fix the docs); the Kate in
  brick and Geest variants (review task 7) if it fits; the buildings table of the review as
  the reference for new ones;
- 111 objects: the dyke as a sloped bank with corner and diagonal pieces (review task 5); the
  farm yard objects (chicken coop, trough, hay rack, draw well, stork's nest; review task 6) if
  they fit, else their own task;
- 113 people: the clothes art-style.md lists but the art lacks (stocking caps in two colours,
  striped apron, tricorne), the trades' props held in hand where cheap;
- 115 items: the period tools art-style.md lists (sickle, flail, rake, pitchfork, bucket, yoke)
  and a period job for the pickaxe, or the docs corrected;
- 116 wild animals: small animals drawn a little larger than life, contact shadows; the Ewer's
  scale against the people;
- the last group: docs/art-style.md and SPEC brought in line with the art (review task 14).

Each of 107 to 116 redraws its group at 32 px in the style of the mockup (more detail, legs
with joints, faces, small animals drawn a little larger than life, a calmer ground behind small
figures, contact shadows), drops the doubling for it, checks every season, frost, snow, dusk
and night in screenshots and the contrast sheet, and retakes the README pictures it shows.
Order: 106 first; then 113 and 114 (what reads worst), 107 and 108 (what everything stands on),
the rest after; a group may be split if it is large.

## 117. Switch between the classic 16 px art and the new 32 px art

- [x] Done

The user, 2026-11-08: "Since you fixed the engine to run in both old and new textures, add a
functionality to switch in-between those. You can recover the already changed ones from git
history, make it a setting under the video settings and add an F-key to change it on the fly."
And: "There's a script to generate the art, correct? Make sure there's a target that also
generates the old art".

Done: the old art is generated, not copied. tools/art/classic/ holds the people's generators of
commit 97e9736 (`character.py`, `villagers.py` and `portraits.py` unchanged, the thought bubble
part of `ui.py`), and `make classic-assets` (run first by `make assets`, so the palette check
covers it) writes their pictures under assets/classic/ with the new files' names, doubled as
then: byte for byte the art of 97e9736, with the new files' cell sizes. `ArtSet` loads the
classic picture where there is one and the new one where there is none (the white stocking
cap, the striped apron and the tricorne have none); every load of the people's art goes through
it (the player, the villagers, the character screen, the chat portraits, the "z"s, the thought
bubble). The setting is "Art: New 32 px / Classic 16 px" under Settings → Display
(`classic_art` under [display] in settings.cfg; not in the save) and F7 ("Classic or new art"
under Settings → Controls) switches it on the fly and saves it; the views that keep their
pictures load them anew, the rest on their next frame. The numbers measured on the art stay the
new art's: in the classic art the head and hat tops and the name tag are 2 to 3 pixels off and
the "z"s start 8 pixels further left, still over the head, which does not show. Debug flags:
`--classic-art` (not saved) and `--switch-art` (F7 just before a screenshot). Checked in
screenshots at zoom 1 and 2: villagers and the player in both sets, F7 pressed in a running
game, passing out with the "z"s, the Display and Controls pages; README picture added.
Each of tasks 107 to 116 moves its group's old generators to tools/art/classic/ and loads its
pictures through `ArtSet` (docs/art-style.md, "Resolution"; tools/README.md): 114 and 116 are
running beside this task, so their classic art comes with them or right after.

## 118. Zoom out as far as before the 32 px switch

- [x] Done

Done: the widest view shows 1280×720 art pixels, 40×22 tiles, again (zoom 0.5, `ViewMath.MIN_ZOOM`;
`WIDEST_VISIBLE_SIZE`, and the stage-one viewport is that plus the margin). Zoom 1 and 2 keep
their size (640×360, 320×180), so `--zoom=` and `make screenshot ZOOM=` mean what they did; the
game starts at 0.5. The zoom keys `=` and `-` (and the keypad's + and −), the actions `zoom_in`
and `zoom_out`, are rebindable and listed on the Controls page and in the README; a press is two
wheel notches and holding repeats. Where an art pixel is smaller than a window pixel (windows
under 1280×720) the sharp-bilinear shader averages four taps. Cost, measured in a busy scene
(rain, 8 villagers, deer, rabbits, gulls, cows, sheep, dusk) at 1920×1080 on an Intel Arc: the
world viewport's GPU time went from 1.09 to about 2.8 ms, the whole frame's GPU time from about
4.8 to 6.4 ms, so the frame stays capped by the 145 Hz display (6.9 ms) either way. Nothing else
needed a change: the weather and fog shaders work in viewport pixels (they follow
`VIEWPORT_SIZE`), and spawning, wildlife and streaming count in tiles or follow the view
(`view_rect`), and the same 40×22 tiles worked before task 106.

The user, 2026-11-08: "we need the zoom back. Now we need to zoom even further to get the same
effect as before". Before task 106 the widest view (zoom 0.5 of 16 px art) showed 640x360 art
pixels, 40x22 tiles; since 106 the widest view (zoom 1, `ViewMath.MIN_ZOOM`) shows 640x360 of
the 32 px art, only 20x11 tiles, so the same zoom-out shows a quarter of the world. Let the view
zoom out to about 40x22 tiles again (1280x720 art pixels at the widest, each art pixel then
smaller than a screen pixel at small windows: check it stays crisp, e.g. by the viewport size
and `screen_scale`), keep zooming in to today's closest view, and start at the widest as now.
Also check the zoom is easy to find since the wheel turns the hotbar: Ctrl and the wheel zoom
today; list it on the Controls page and the README, and consider keys (+/-) as well. Mind the
cost of the larger viewport (world, shadows, weather, lights drawn over 4x the pixels) and what
assumes 640x360 (`VIEWPORT_SIZE`, `WIDEST_VISIBLE_HEIGHT`, the screenshot tool, tests).

## 119. The tools in the character's hand

- [x] Done

Done: every tool shows in the hand (`HELD_TOOLS` in tools/art/character.py, one sheet
assets/character/held_<tool>.png each, the item's `held_sheet`): the hoe, shovel, scythe, axe,
pickaxe, hammer and watering can, at 32 px in every facing and walk frame, in the colours of
their icons. One helper places them the hoe's way, in the right hand: the long tools (hoe,
shovel on its blade, scythe) stand on the ground beside the figure, the short ones (axe and
pickaxe at the throat, hammer, the copper can by its handle) hang in the hand with the head
above it and, seen from the side, swing with the near hand; from behind the tool is behind the
body, its head turned outward so it shows beside it. There is no fishing rod in the game, and
the player has no use (swing) animation, so there was no swing for a tool to follow: a tool
stays in the hand as it is used, and riding, passing out and lying in bed still let go of it.
The classic art keeps its hoe; the other tools show the new picture in both sets (checked: they
sit by the doubled 16 px figure's hand). A test checks every tool has a held sheet in the
character's cells in both sets. Checked in screenshots of every tool in all four facings at
zoom 1 and 2 in both sets; the README's build picture is retaken with the hammer in hand.

The user, 2026-11-08: "most tools don't show on the character". Only the hoe has a
`held_sheet` (game/state/item_types.gd) and a held layer drawn (tools/art/character.py); the
others (axe, pickaxe, shovel, watering can, scythe, hammer, fishing rod, and what else the
player can hold) show nothing in the hand. Draw a held layer for each at 32 px in every facing
and pose the hoe has (idle, walk, and the use animation where there is one), set `held_sheet`
for each, and check them in screenshots in all four facings; classic art (task 117) falls back
to the new picture for those without an old one. Task 115 (items and icons) redraws the
icons; this task is the hand-held pictures, and may go with 115 if that is simpler.

## 120. Kate variants: a brick Kate and a Geest Kate

- [x] Done

Done (with task 121): a building has styles, sections `[<building>.<style>]` after it in
data/buildings.cfg with their own `name` and the keys they change; the footprint, the door
and the interior map stay the building's (checked), so a style needs no interior map of its
own and the hammer's row does not grow. `BuildingTypes.of(type, style)` gives a style's entry,
the building's own look being style &"". A placed building saves its `style` (save version
24; a version 23 building has its own look, a style later taken out of the file shows as the
own look; the upgrade from version 13 dropped in a commit of its own, before the bump). Its
picture, window lights, name and refund are its style's. The art: `buildings.kate(walls=)`,
"brick" red brick (rust, red_light) in sand joints on the fieldstones, white frames, green
door and shutters, a brick chimney (30 clay instead of 15); "geest" the lime wash over a foot
tarred black (`tarred_foot`) under a turf ridge (35 logs, 5 stone). The windows stand where
the Kate's do, so the window lights are its own. The classic set has both too, drawn into
the frozen classic Kate by the same `walls` parameter (its brick wall and a small tarred
foot); every old picture stays byte-identical. `--street` shows every style. Checked in
screenshots at zoom 0.5, 1 and 2: summer, autumn, a winter night under snow with lit windows,
in both art sets.

From review/art-review-2026-11-08 (its task 7 and buildings row 7), left out of task 110: two
more looks of the Kate, for Kerrin's house at the dyke foot, the mill house and the sexton's
house: red brick walls (`rust`, `red_light`, joints `sand`) with white frames, green paint and
a brick chimney; and a Geest look, lime-washed over a black tarred foot instead of the
fieldstones, under a turf ridge. The art is cheap (`buildings.kate` takes the walls as a
parameter; task 110 tried both looks); the open question is the game side. The review proposes
a `style` per building in data/buildings.cfg (SPEC "presets with customisation"), which means a
saved style per placed building (a save version), a way to pick it with the hammer and the
pictures per style; two more building types in data/buildings.cfg would need no code, but
each needs its own interior map today (test_interior_maps) and the hammer's list grows.

## 121. A building menu: the buildings and their variants, with a preview

- [x] Done

Done (with task 120): `BuildMenu` replaces the small build panel. With the hammer held, a
row of the buildings stands just above the hotbar in the order of data/buildings.cfg, each a
small picture with its name and its materials (icon and count); the chosen building's other
styles stand in a column above its cell, the first nearest the row; beside them (right, or
left at the window's edge) a larger preview of the chosen style with each material as
carried/needed, red when short, and why the spot is refused (the row covers the message
above the hotbar). The chosen cell is lit like a hovered button, its name in gold. Q and E or
the left and right arrows move along the row (wrapping, a new building in its own look), the
up and down arrows through the styles (`build_style_up`, `build_style_down`, stopping at the
ends); a click on a cell picks it (`Builder.choose`) and never reaches the land. While the
menu is up the arrows are the menu's and the player walks with WASD only
(`BuildMode.walk_direction`, `GameSettings.SHARING_PAIRS`); Escape dismisses build mode and
gives them back. The ghost is the chosen style's; `--building=kate.brick` picks a style for
screenshots. Taking down, the menu gives way to its "Taking down" panel at the top left. Its
pictures follow F7. Checked in screenshots at zoom 0.5, 1 and 2, both art sets, day, a winter
night and taking down; README's build screenshot retaken.

The user, 2026-11-08: "we need a proper building menu which allows the different variants and
maybe a small preview. It could look like a matrix on top of the quick bar where you see the
main buildings and their variants popping up to the top when you selected a building."
Today the hammer's Q and E step through data/buildings.cfg in file order, one building at a
time. Instead, with the hammer held, a row of the main buildings sits just above the hotbar
(each a small picture of the building, its name and cost); picking one makes its variants pop up
in a column above it (task 120's brick and Geest Kate, later styles), and the chosen variant
shows a larger preview with its materials and whether the inventory has them. Keys and mouse
both work (arrows or Q/E along the row, up and down through the variants, a click picks; Esc
closes), the ghost in the world follows the choice, and it reads in both art sets (task 117).
Goes with task 120: the variant needs a saved style per placed building (a save version) and
the variants' pictures; plan the data shape (a building and its styles in data/buildings.cfg)
together.

## 124. Language model profiles, with a temperature setting for villager talk

- [x] Done

Done: three commits. A "Temperature" setting per provider (empty: the game's 0.5, else 0 to 2),
used for the reply only; the memory summary got its own `[memory] temperature` (0.3) in the data
file, as before it borrowed the reply's. Then `LanguageModelProfiles` (`GameSettings.profiles`):
profiles of a provider with its endpoint, model, tokens, temperature and chat length, the key per
provider, the upgrade of old settings files (a profile per provider, the chat length into each),
and the page with the profile list, New, Copy, Delete, a name and a provider.

From the gossip plan (design/villagers/gossip.md, Settings; the user, 2026-11-09: "add a setting
for LLM temperature so that it is easy to adjust"). A temperature per provider in Settings, kept
like "most tokens an answer may take": empty is the game's own (`temperature` of
data/npc_talk.cfg, 0.5), else 0 to 2. It applies to the chat replies (and later the bubbles of
task 130); the memory summary keeps its own value in the data file. Saved in the settings file
per provider, read by NpcDialogue. Tests for the setting and that the request carries it; docs
in design/villagers/dialogue.md and the README.

Then, in the same task (the user, 2026-11-09: "revamp the LLM settings to profiles: a profile
contains a provider and its settings. That way you can choose different settings for any given
provider, for instance Gemini with a pro or a flash model, the same model with different history
and temperature etc."; first a later idea, then "put this into the current task and expand its
scope"):
- A profile is a name, a provider and that provider's settings: endpoint, model, most tokens,
  temperature, and "Lines a villager keeps" (today one for all; later the memory sizes of task
  126 too). Several profiles may use the same provider.
- Settings picks the active profile and adds, copies, renames and deletes them (at least one
  stays). The game uses the active one wherever it reads the provider's settings today.
- The key stays per provider, not per profile: entered once, only ever sent to its own provider.
- The settings file gets a new shape with an upgrade: each provider's settings of today become a
  profile named after the provider, the active provider's the active profile, and the global
  chat length goes into each.
- Tests for profiles, the upgrade and that a key goes only to its provider; docs and README.
  The temperature setting is its own commit first; the profiles follow as further atomic
  commits.

## 131. Scrolling for menus that outgrow the window

- [x] Done

Halted 2026-11-09 after the crafting screen and the chest (merged): the other panels move
onto the Modal base of task 132 once it is in.
Paused by the user on 2026-11-09 after task 132 was merged: "pause 131 until i tell you to
continue".
Going on again on 2026-11-09 ("you can continue 131"): the character screen (the inventory)
moves first, so task 133 can start.
The keys that close a window are the window's own (the user, 2026-11-09, when moving the
character screen made E close it: "The old behaviour should stay the same. Maybe the modal should
handle it but the instance can decide which key to use. You register a key with the modal and the
modal uses it for shared closing code"): crafting and the chest register E, the inventory doesn't.

The build menu (the user, 2026-11-09: "the build menu should scroll sideways"): its row of
buildings scrolls sideways when wider than the window, keeping the chosen building in view (see
design/building/README.md, the build menu). It is an overlay, not a Modal; ScrollingList (or a
horizontal sibling of it) handles the width.

The user, 2026-11-09: "UIs like crafting get bigger than the screen. so we need scrolling for
those if they reach certain limits." First a later idea, then "start the scrolling".
- The crafting screen first; then every panel with content that grows: inventory and chest, the
  build menu, the character screen, the pause menu's Settings pages (the language model page with
  its profiles is close to the window height already).
- Past a height limit (the window less a margin) the growing part scrolls, by mouse wheel and by
  dragging the bar, while titles, tabs and buttons stay put. Keyboard or controller focus keeps the
  selected entry in view. Below the limit nothing changes: no bar, the panel as it is today.
- One shared way to do it (a helper or a scene used by all panels), not a copy per panel.
- Check each panel at the smallest supported window size and the largest UI scale; tests for what
  can be tested (the limit, focus kept in view), screenshots by hand. Docs: the UI page of the
  design (design/presentation/menus-and-hud.md) and the README.

Done: one commit per panel. `ScrollingList` (and `ScrollingList.Row` for the build menu's row)
is the one helper, used by the crafting screen, the chest, the Controls and Language model pages
and the build menu; every window is on Modal. Skipped as they cannot grow: the character screen's
fixed grids, the skills tab (a few rows), the short pause menu pages. Open: the chat window is a
fixed size (340 units wide plus portraits), wider than the window at a UI scale of 2.

## 132. One way to build a window: a Modal base class

- [x] Done

The user, 2026-11-09, during task 131: "are the modals currently coded separately? we might need
to refactor to create our own little UI library that handles all that in one place", then "work
on that first, halt the other scrolling refactor. Once the interface is clear the other worker
can continue using the new modal/ui lib and only build the contents for it".

Today each window (crafting, chest, character, chat, the pause menu and its Settings pages) is
its own CanvasLayer that builds its own backdrop and themed PanelContainer, centres itself (three
copies of `_centre_panel`, the character screen's `_fit_to_window`, the Controls page's
`_fit_list_to_screen`), has its own open, close, is_open and toggle, and handles Escape one of
three ways; pausing is per window (only chat pauses), and which window may open over which is a
set of conditions in main.gd.

- A `Modal` base class in game/scenes/ that does all of that once: the dimmed backdrop, a themed
  panel centred in the window that refits on window resize, UI scale and content changes;
  opening, closing, is_open and toggle, with `opened` and `closed` signals; Escape (ui_cancel)
  closes it, a window may take Escape for itself first (the pause menu goes back a page);
  a click on the backdrop closes it if the window wants that; a flag whether the game pauses while
  it is open; one window at a time (opening one closes the one that is open), so main.gd asks
  the base whether any window is open instead of keeping its own conditions.
- The growing part of a window is given to the base, which wraps it in ScrollingList (task 131).
- A window only builds its contents. Small builders (a title, a row of buttons) go into the base
  only if two windows or more use them.
- Not windows, so not part of it: the HUDs, tooltips, the build menu (an overlay while building).
- The crafting screen and the chest move onto it in this task, to prove the interface; task 131
  then moves the rest (Controls and the other Settings pages, the language model page, the
  character screen, chat, the pause menu) straight onto it.
- The interface is written down in the class's comments and docs/architecture.md; tests for the
  base (open and close, one at a time, Escape, pause, refit).
- A guide, docs/ui.md (the user, 2026-11-09: "add documentation for the ui lib so that future
  workers/humans know how to use it"): how to make a window with one short example, the growing
  part and scrolling, Escape, backdrop, pause and one at a time, theme and builders, testing a
  window headless, and what is not a Modal; linked from docs/architecture.md and the README. Behaviour the player sees doesn't
  change, except where the old windows differed by accident.

Done: `Modal` (game/scenes/modal.gd) with the interface in its class comments and in docs/ui.md
(new, linked from architecture.md and the README). Windows with arguments have a method of their
own that calls `open()` (`open_station`, `open_chest`), as GDScript allows no override with another
signature. The crafting screen and the chest are on it; Main asks `Modal.is_any_open()` and the
screens not yet on it. The open window is a static variable of the base, no registry. Escape is
`ui_cancel` or the pause key, through the `_takes_escape()` hook.

## 133. A trash can in the inventory

- [x] Done

The user, 2026-11-09: "once i tell you to resume 131, start in parallel: a trash can for the
inventory dragging items on it will destroy them after confirmation." Then: "do 133 after 131
has done the inventory, but tell 131 to do the inventory first". So task 131, once resumed, moves
the character screen (the inventory) onto Modal first, and this task starts once that is merged.
- A trash can slot on the inventory screen (character screen), and on the chest's screen, where
  the backpack shows. It looks like a slot with a bin icon (palette colours, both art sets).
- Putting a picked stack on it (the screens pick and place with clicks, see
  design/player/inventory-and-character.md; a real drag counts the same if dragging comes later)
  asks first: "Destroy 12 logs?" with Destroy and Keep. Destroy removes the stack for good; Keep,
  Escape or a click elsewhere leaves it picked as it was. Equipped items and the hotbar's stacks
  can be thrown away the same way once picked.
- The confirmation is part of the screen, not a second window (one Modal at a time, task 132).
- Game state: the inventory's removal is an explicit action with a test; the screen only asks
  and sends it. Docs: the inventory design page and the README.
- It builds on the character screen as task 131 left it on Modal.

Done: `ItemSlots.destroy` and `Equipment.destroy` (tests/test_item_slots.gd, test_equipment.gd),
the bin icon `assets/ui/trash_icon.png` (UI icons have one version for both art sets, as the
slots do), and `TrashCan` (game/scenes/trash_can.gd): a bin slot whose question "Destroy Logs
(12)?" floats over the screen with Destroy and Keep, so the screen does not change size. It
swallows any other click while up, Escape goes through `_takes_escape`. Used by the character
screen and the chest's (tests/test_trash_can.gd, test_storage_trash_can.gd).

## 134. Real drag and drop in the inventory screens, the trash can too

- [x] Done

The user, 2026-11-09: "make the trash can really drag and drop. Also the whole menu drag and drop.
clicking should not anchor the item to the mouse, wherever you drop it puts / swaps the item, on
the trashcan it opens the deletion confirmation".
- Today the screens pick a stack with a click and carry it on the mouse until the next click
  (task 88, design/player/inventory-and-character.md). Instead: press on a stack and drag it; it
  follows the mouse only while the button is held; releasing it over a slot puts it there, or
  swaps with what is there, or adds to a stack of the same item; released over the trash can, it
  asks "Destroy Logs (12)?" (task 133) and Keep puts it back where it came from; released outside
  the panel, it drops on the ground as a click outside does today; released anywhere else, it goes
  back. A click alone no longer picks anything up.
- All the screens that move stacks: the character screen (backpack, equipment, the hotbar while
  it is open) and the chest (both sides, the hotbar), the same way, in one place (SlotView and the
  TrashCan, built on Godot's drag and drop where it fits), not a copy per screen.
- Keep what works today unless it clashes with dragging: right-click equips or unequips, Shift and
  a click sends a stack to the other side, the hotbar's number keys. Splitting a stack (dragging
  half) is a later idea unless it falls out naturally; ask first.
- Tests for drop on a slot, swap, merge, the trash can (asks, Destroy, Keep), outside the panel,
  cancelled drags; docs and README, the controls table too.

Done: `SlotView` is Godot's drag and drop (`_get_drag_data`, `_can_drop_data`, `_drop_data`,
`set_drag_preview`) on a slot bound to an `ItemSlots` or the `Equipment` (`bind_to`): drop onto an
empty slot, a different item (swap), the same item (merge), an equipment slot that fits; the
source slot fades while dragged and the fitting equipment slots light up. `TrashCan` is a drop
target that asks and destroys the dragged slot's stack itself (no screen code); `Modal.
_drop_outside_panel` turns a drop on the dimmed area outside the panel and the hotbar into the
ground drop; anything else goes back, as nothing moves during the drag. A click picks nothing
up; Shift+click (`quick_move_requested`) and right click stay. The old pick state, the icon
following the mouse and the backdrop click handlers are gone from both screens. Tests:
tests/test_inventory_drag.gd, test_equipment_drag.gd (real mouse events in a SubViewport),
test_trash_can.gd, test_storage_trash_can.gd, test_storage_screen.gd. Docs, README and controls
table updated.

## 135. Fireflies on summer nights

- [x] Done: fireflies in summer from dusk to four hours after sunset, over meadows by trees, Knicks and
  water, not in rain, storm, fog, wind or cold (rules and numbers in data/wildlife.cfg, tests,
  `--wildlife=firefly`, art in both sets, README and design/world/wildlife.md).

The user, 2026-11-09: "add fireflies for the corresponding seasons and time of day". Ambient
wildlife (design/world/wildlife.md, data and rules as the other animals): small glowing points
that drift and blink, a few together, in the right season (early to late summer; the glow-worms
of northern Germany, Lampyris and Lamprohiza, fly from about June to mid July) and the right hour
(dusk and the first hours of the night), over meadows, hedges (Knicks) and the edges of woods and
water, not in rain, wind or cold. Drawn as light (they glow at night like the other lights of the
game, see design/presentation/look.md), in both art sets; a debug flag to see them; tests for when
and where they come; docs and README.

## 136. Saplings without a stake

- [x] Done: the 32 px sapling lost its stake and band and got a slightly wider foot so the stem stands on
  its own; the classic 16 px sapling lost its stake too; art regenerated; the README forage picture retaken.

The user, 2026-11-09: "saplings should not have a stabilizing rod since they often occur naturally
and not planted by a player". The 32 px sapling (tools/art/trees.py, `sapling`) has a stake and a
band tying the stem to it; draw it without them, in every species and season look, and check the
classic set (tools/art/classic/trees.py) has none either. Screenshots where the README shows
saplings.

## 137. The camp's bedroll and campfire: take them down, craft them, set them up elsewhere

- [x] Done

The user, 2026-11-08 (a later idea then): today the bedroll and the campfire come with the camp
and stay where they are; let the player take them down (as task 83 does for buildings and placed
things) and build them again elsewhere, with sensible materials (straw and a wool blanket; stones
and wood), keeping the bed the player wakes in (task 78) and the campfire's cooking station
working wherever they stand. Started 2026-11-09 ("also start the deconstructible campfire and
sleeping roll. Add to that task to be able to craft them"):
- Taking down with the hammer gives the bedroll or the campfire back as an item (or its
  materials, if that reads better; decide and say), like other placed things.
- Both can be crafted (data/recipes.cfg, the crafting menu; by hand or at a station, whichever
  fits the other recipes), and the item is placed like other placed things.
- The bed the player wakes in follows a bedroll that is moved; if the only bed is taken down,
  the player still has somewhere to wake (design/player/energy-and-sleep.md says there is always
  a bed; keep that true or say what changes). The campfire cooks wherever it stands.
- Saves keep working (a save upgrade if the camp's objects change shape); tests; docs (the
  design pages for sleep, crafting and building) and README.

Done: the campfire and bedroll are items (`ItemTypes.FIREPLACE`, `SLEEPING_BAG`, ids of their
objects) the hammer takes down whole and the player sets up outdoors; recipes by hand (campfire
6 stone + 3 logs, bedroll 6 hay + 4 fibre: no wool or linen item exists); the home follows a
bedroll set up while the home has no bed (`GameState.make_home_if_bedless`), and `_home_bed`
ignores a non-bed on the old tile; with no bed at all the player wakes at the world's start
point (`CampSite.spawn_of_seed`, decided by the user 2026-11-09), put on free ground if it is
taken ("there is always a bed" holds only at the start, see energy-and-sleep.md). The campfire's
cooking is the hearth station wherever it stands. No save change: the camp objects were
already edits (tests/test_camp_objects.gd). The bedroll's ghost is in
docs/screenshots/bedroll-ghost.png.

## 138. The chat window never gets bigger than the window

- [x] Done: the log is the window less the margins and the portraits, clamped between 128x64 and
  340x176 (`ChatScreen.refit`, on open and on the viewport's `size_changed`); the bubbles re-wrap
  to it.

The user, 2026-11-09, on the chat being wider than the window at UI scale 2 (a fixed LOG_SIZE of
340x176 plus the portraits): "it should never become bigger than the screen fits, but the text
size might still increase based on uiscale".
- The chat's log (game/scenes/chat_screen.gd, LOG_SIZE) gets as wide and tall as the window at
  the current UI scale leaves, less the margin the other windows keep (ScrollingList.MARGIN), up
  to today's size; the portraits and the input line keep their places. The bubbles' widths (at
  most 70% of the log) follow the log's width, and the text wraps within them; the text itself
  keeps scaling with the UI scale as all UI does.
- It refits on window resize and UI scale change (Modal and ScrollingList show how), and the log
  still follows the newest line.
- Below the limit nothing changes. Tests in a small SubViewport (the window fits, bubbles narrower,
  text wraps); a screenshot at UI scale 2 by hand; docs: design/villagers/dialogue.md, docs/ui.md
  if something new for windows comes of it.

## 145. Autosave on a timer, quick save and quick load

- [x] Done: Settings, Game, "Autosave every" (10 to 60 minutes of play in steps of 10, default 10;
  `AutosaveTimer`, held back by a fade, a collapse, an open window or the console); F9 quick save
  and F8 quick load, rebindable (F8 restarts the scene from the save, "No save to load" when
  there is none); saving off the main thread (`SaveService`: the text at once, the write in a
  worker thread, one save at a time, a second request skipped, quitting and F8 wait for the
  running one); the notifications at the top left below the clock and harvest note
  (`NotificationHud`: "Saving...", "Saved", a failure in red); `SaveService.last_succeeded` is
  there for task 140.

The user, 2026-11-09: "automatic save,
players can configure the time in the settings from 10 min to 60 min in 10 min steps. F8 will
be a quick load from the last save, F9 a quick save (can both be changed in the key config). A
save in progress should be indicated in the notifications, the game can't quit while a save is
in progress."
- A setting "Autosave every" of 10 to 60 minutes in steps of 10 (real minutes of play; paused
  time doesn't count), besides today's autosaves on sleep, passing out and quitting
  (design/tech/saving.md).
- F9 saves, F8 loads the last save; both rebindable in the controls page like the other keys.
- While a save is written, a notice says so; quitting waits until it is done (or is refused
  until then). Today the save is written at once in one call, so "in progress" first needs the
  write to run without freezing the game (a thread, or the save data taken at once and written
  in the background), keeping the temporary file and rename.
- A failed timed or quick save shows a red message in the notifications and nothing else (see the
  decision below); asking the player about a failed save is for saving on quit, in task 140.
- Decided by the user, 2026-11-09: F8 does not ask first ("quick load generally doesn't ask in
  games"). Notifications appear at the top left of the screen (the game has no notification
  area yet; this makes one). A failed quick save shows a message in red there; quick save and
  quick load get no dialog of their own (the failed-save question of task 140 is for saving on
  quit).

Started 2026-11-09 ("Start implementing auto save and quick save/load").

## 142. Review R7: only what is near is drawn and scanned

- [x] Done

Review A1 and package R7, moved up by the user on 2026-11-09 ("there's already some performance
weakness"). Saved things stay saved; only drawing and scanning get bounded.
- Ground piles: a spatial index by chunk, sprites only for piles near the player (created and freed
  as the player moves, as farm animals already are), and pick-up and settling asking the index
  instead of scanning every pile. Piles that are pulled toward the player move between cells.
- Villagers: a view only for those near the player; their state goes on as now.
- World edits replayed by chunk instead of scanning all edits on every chunk load; the wet-soil
  marks counted in what stays resident.
- No expiry or despawning of saved piles; no change to how far anything reaches in play.
- Tests: 10,000 distant piles and a few near give sprites for the near ones only; leaving and
  coming back, entering a house, saving and loading, picking up and switching art keep every pile
  right. Measure before and after (node counts, frame time in a big save copy) and report it.

Done: piles indexed by chunk (pick-up and settling look at the player's chunk and its neighbours); pile sprites and villager views only within the chunks the world view draws, kept one chunk further; edits replayed per chunk; wet-soil marks counted. Fixture save (9,939 piles, 154 villagers, 27,561 tilled tiles, headless Main): nodes 21,804 to 1,074; mean frame 37.2 ms to 7.3 ms; world settled 8.9 s to 5.9 s. See design/tech/world-objects-and-edits.md.
