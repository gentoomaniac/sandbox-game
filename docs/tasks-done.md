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

## 141. Review R3: windows and conversations can go away without leaving work behind

- [x] Done

Review F2 and package R3 (plus A5 and the rest of R5).
- The chat's reply is finished by the session's dialogue service (NpcDialogue), not by the
  ChatScreen: closing or freeing the window can't leave a villager answering forever, and an old
  reply never lands in another conversation or session. A normal close keeps today's behaviour
  (the answer lands in the villager's chat).
- Removing an open window runs the same cleanup as closing it (Modal `_exit_tree`), so a borrowed
  hotbar gets its layer, clickability and look back.
- The hotbar owns its slot views: screens ask it to be clickable and give it back, they don't
  reach into `slot_view()` themselves.
- Showing a view another world (WorldView, GroundItemView, the screens' `show_*`) disconnects the
  old one, or is refused before anything changes; doing it twice with the same one doesn't
  connect twice.
- WildlifeView no longer sets `sun` on the shared default rules (A5): pass the session's sun.
- Tests: the review's probes (a reply after the window is freed, chat A then B then A's answer,
  freeing an open chest window, world A then B), and counts of nodes settling after repeated
  open, close and free cycles.

Done: `NpcDialogue.say` commits the line and the reply and sends `answered(npc)`; the window only
shows it. `Modal._exit_tree` calls `close()`. `HotbarHud.acquire(self)` / `release(self)` replace
`slot_view()` and `set_clickable()` and reset the slots too. `show_inventory`, `show_player`,
`show_skills` and `show_crafting` let go of the old model; `WorldView.show_world` and
`GroundItemView.show_items` refuse another world with `push_error` (their drawn chunks and
sprites belong to one world: make a new view), and the same one twice does nothing.
`WildlifeRules.for_session(sun)` replaces writing the sun on the shared default rules. Tests:
`test_chat_lifetime.gd`, `test_modal_removal.gd`, `test_shared_hotbar.gd`,
`test_view_rebinding.gd`, `test_window_cycles.gd`, `test_wildlife_session_rules.gd`. A pending
reply is dropped with the session (its NpcDialogue is freed with it); no generation counter was
needed, as a reply goes to the villager object it was asked of.

## 139. Review R1: item operations are committed transactions

- [x] Done

From the architecture review of 2026-11-09 ([review/code-review-2026-11-09/README.md](review/code-review-2026-11-09/README.md), F1 and package R1; the user: review
items come before the gossip work). Make conservation, slot identity and notification timing
properties of the item API:
- One internal "change, then notify once" path in ItemSlots that transfers, payments, equipment
  moves and crafting all use: a listener on any `changed` never sees an item twice or missing
  (today `send` fills the target and notifies before emptying the source; `move_to_equipment`
  notifies between unequip, write and equip; crafting removes each material and adds the output
  in separate steps; `take_out` adds before it clears the station).
- `send` to its own container is refused or harmless (today it empties the stack). Bad counts and
  indices are refused without partial change.
- Using the held item takes from the selected slot: eating, planting, placing, the bone and the
  saddle (today `remove(item, 1)` takes from the last stack of that item). Paying a cost across
  the inventory stays its own operation.
- Outside code stops writing `slots` or emitting another object's `changed` (Equipment,
  GameState). Destination order and overflow rules stay exactly as they are.
- Tests look at the state from inside the signal callbacks, two containers in one operation, a
  re-entrant listener, and the two-stacks-of-berries case.
- Out of scope: item attributes, a new stack type, moving content into data files.

Done: ItemSlots finishes every change before it notifies (`send`, `move_to`, `add`, `remove`, the
new `take_from` and `exchange`); Equipment moves update both sides, then notify; crafting and
building pay with `exchange`, `take_out` clears the station first; `Inventory.consume_held` takes
from the selected slot; GameState and the debug harvest no longer write `slots` or emit
`changed`.

## 146. One image per entity, packed into the atlases by make assets

- [x] Done

The user, 2026-11-09: "don't have a shared file with item images but rather single images per item
with all its states. That'll make it easier to eventually swap out with hand crafted artwork.
Instead of changing one big map we can change single files one entity at a time." "Map artwork
stays in a big tilemap." Then: "add a make assets that's separate from the image generation. It
compiles the maps so that artists can edit single images and for optimisation make assets
compiles it into the atlas that Godot can natively read."
- Today the world objects (trees, bushes, stones, stumps, reeds, chests, stations...) are drawn
  straight into nine shared sheets (assets/objects*.png, one per season look, 4608x8160) and the
  decorations into assets/decorations*.png, the same for the classic set. Items, buildings,
  interiors, wildlife and crops already have files of their own; terrain stays in its tile sheets.
- **Source images:** one PNG per object type and per decoration in each art set, with all its
  states: a row per season look, a column per variant, cells of the fixed size the game uses (96x160;
  48x80 in the classic set), the object standing on the cell's bottom centre. These are the files
  artists edit, and they are kept in git.
- **Hand-drawn art with fewer states:** a source image may leave season looks or variants out; a
  missing look falls back to the default look, a missing variant to the first.
- **`make art`** (today's `make assets`, renamed; `make classic-art` likewise): the generators
  write the source images (and the other generated art and sounds as today).
- **`make assets`** (new, fast, no drawing): packs the source images into the atlases the game reads
  (the same grid as today, so ObjectTileset, the motion shaders and batching stay as they are) and
  runs the palette check. The packed atlases are build output, ignored by git; `make setup`, and
  the targets that need them (run, test, screenshot, export), build them when they are missing or
  older than their sources.
- A missing source image fails `make assets` with a message naming the object type (and task 144's
  start-up check can rely on it).
- Docs: tools/README.md (the two targets and how to replace one entity's art by hand),
  design/presentation/art-pipeline.md, README (setup), and the briefs' "make assets" lines.
- Check: packing today's generated art gives atlases identical to today's committed ones, pixel for
  pixel, before the old files leave git.

Hand-drawn art drops in over the generated art (the user, 2026-11-09: "We want a way so that we can
drop in hand drawn data, the flow detects it and uses those over the generated art"):
- **Three places:** `art/generated/` is what `make art` draws (only the generators write there);
  `art/hand/` is what artists drop in (no tool ever writes there); `assets/` is what Godot reads,
  built by `make assets` and no longer in git. Both source folders are in git.
- **Naming** (the user): a hand-drawn file has the path and name of the generated one with a postfix
  for the art set it replaces: `_32x32` for the 32 px set, `_16x16` for the classic set (e.g.
  `art/hand/objects/oak_32x32.png`). A hand file for one set leaves the other set's generated art
  as it is.
- **Choice per file and per state:** `make assets` takes the hand-drawn file where there is one,
  else the generated one; in a sheet of states (season looks, variants, frames) a cell the hand file
  leaves empty (fully transparent) is filled from the generated file, so art can be replaced bit by
  bit.
- **Everything, not only the atlases:** items, buildings, furniture, animals, crops and the UI art
  the same way; sounds too (`art/hand/sounds/`), so recorded sounds can replace generated ones.
- **Visible:** `make assets` lists which files came from `art/hand/`; a hand file that matches no
  generated file (a typo in the path or postfix) is an error.
- Defaults until the user decides otherwise: hand art outside the palette is warned about, not
  refused; a hand file must have the generated file's size exactly (no scaling of pixel art).

Done: `make art` / `make classic-art` draw into `art/generated/` (the paths of `assets/`; objects and
decorations as one sheet per type or ground layer, a row per look, a cell per variant, with an
`atlas.txt` for the order; the classic art at 16 px as drawn). `make assets` (tools/art/pack.py, about
20 s, no drawing) packs the atlases (byte-identical to the old ones, checked against a copy of the
old `assets/` with `diff -rq`), scales the classic art (`classic/scaling.py`) and copies the rest;
`assets/` is out of the repository and `run`, `test`, `screenshot`, `bench`, `export` and `setup`
build it when `art/` is newer (stamp `assets/.packed`). Godot writes the `.import` files itself;
only the font page's `skip` import is written by the pack. `art/.gdignore` keeps Godot out of `art/`.
Hand art (`art/hand/`): path of the generated file plus `_32x32` / `_16x16` (sounds none), exact size,
empty cells stay generated (not the default look, as the task text first said), a listing of the hand
files used, palette warnings, an error for a hand file that replaces nothing. A hand sound is not
level-checked. Tests: `tools/art/test_pack.py` (`make test-tools`, part of `make test`).

## 144. Review R4: one checked catalog of items and objects

- [x] Done

Review F3.3/F3.4, section 4 and package R4, cut down after talking it over with the user on
2026-11-09: no per-item scripts and no move of the definitions into folders now ("there's not much
to win with a restructure"; the "one folder per entity" idea stays under Later). What stays is the
check, which catches the cross-file mistakes adding an item invites today:
- At start, before anything uses them, every item and object definition is checked with its
  references, with a message naming the item and the field: stack limits, weights and tool power in
  range, wearables stack 1, what an item places, plants or drops exists, recipes and stations name
  real items and objects, crop items don't collide with fixed ones, footprints are sane, and every
  item and object has its picture (an art manifest check, in both art sets).
- Callers can't change the definitions through what they get back; tests use their own small
  catalogs instead of adding to and erasing from the shared dictionaries.
- Where something may be placed is an explicit field of the object, not inferred from whether it
  has an atlas row (tool_use.gd `_can_place_on`).
- Same ids, same data, same game; no save change.

Done: `CatalogCheck` (game/state/catalog_check.gd) checks every item and object with its references at
start; `AssetCheck.catalog_problems` checks their pictures and atlas cells in both art sets; `Main`
quits with the errors in the log on any problem (no window opens). `ItemTypes.TYPES` and
`WorldObjectTypes.TYPES` are read-only all the way down (`ReadOnly.deep`); two tests that added to
them use their own catalog. `placeable_in` (INSIDE, OUTDOORS, ANYWHERE) says where an object may be
placed and replaces `outdoors_only` and the atlas-row inference in `_can_place_on`. Same ids, data and
game; no save change. Not done by design: per-item scripts, moving the definitions into folders.

## 150. The test LLM finds the GPU by itself: NVIDIA or AMD

- [x] Done

`make llm-up` (tools/llm/llm.sh) must use whatever GPU the machine has, without being told: the
NVIDIA GPU through its CDI spec (as today), or an AMD GPU through ROCm (`/dev/kfd` and a render
node; the image `ollama/ollama:<version>-rocm`). The second machine has a Radeon RX 7900 GRE.
- `LLM_GPU=auto` (default) picks NVIDIA, then AMD, else the CPU with a hint why; `nvidia` and `amd`
  choose one, `1` means any GPU or fail, `0` the CPU. The container label records which one, so
  a change recreates the container.
- AMD: group access, an optional `LLM_HSA_OVERRIDE` for consumer cards ROCm does not list, the
  detected gfx target printed with a hint for the known unsupported ones.
- `make llm-gpu-setup` detects the vendor: NVIDIA writes the CDI spec, AMD checks what is missing
  (no root).
- Docs: Makefile help, tools/README.md (an AMD section), README.

Done: `LLM_GPU=auto` in tools/llm/llm.sh takes NVIDIA (CDI spec), else AMD (`/dev/kfd` and a render
node: the `-rocm` image of the same Ollama version, both devices, `keep-groups` or the device
group ids, optional `LLM_HSA_OVERRIDE`), else the CPU with the reason; `LLM_GPU=nvidia|amd` choose
one, `1` and `0` as before. The gfx target is printed, with the override for the known unsupported
families. The container label holds nvidia, amd or cpu. `make llm-gpu-setup` detects the vendor
(AMD only checks). The AMD path was tested by logic (a fake device tree, `LLM_DRY_RUN=1`), not
on a real AMD card.

## 140. Review R2: a broken save is caught before it becomes the game; a failed save says so

- [x] Done

Review F3 and package R2. Needs 139's stack rules.
- One validator runs on the upgraded save before anything is built from it, with the path of
  what is wrong ("inventory slot 3: count -7"): item ids, counts and stack limits, the selected
  slot, object and building and map references, field types, station recipes. Assertions stay for
  internal invariants only; `from_dict` stays strict behind the validator.
- **Missing content** (the user, 2026-11-09): when a save holds things the game no longer has (an
  item or object id that was removed), loading asks the player: load anyway, dropping what is
  missing, with a plain warning that playing on may run into problems, or cancel. Nothing is
  dropped silently; the file on disk is not changed until the player saves. Other broken data is
  refused with the message, and the file is left as it is.
- **A failed save** (the user, 2026-11-09): the game says so and asks the player; "Save and quit"
  doesn't quit after a failed save unless the player chooses to, and that choice says very plainly
  that the progress since the last save will be lost. The previous good save stays (the write
  already goes to a temporary file and renames it; check every step's result).
- Tests: the review's broken saves (-7 logs, slot 999, unknown ids, missing fields, a wrong map
  reference, a bad station recipe, `game` of the wrong type) are refused or asked about, never
  half loaded; injected write and rename failures keep the old save and don't quit; round trips
  stay whole; the oldest and newest supported versions.

Done: `SaveValidator` checks the upgraded save once, with the place of each problem; a damaged
save is refused (`LoadResult`, explained in a `ChoiceDialog`, moved to `world.json.bak`); content the
game no longer has asks (load anyway, dropping it, or cancel; F8 asks too); every step of the write is
checked and `SaveBeforeQuit` asks after a failed save before quitting. Object state entries are
checked as numbers, but positions on the map, skill ids and appearance variants are not (the strict
`from_dict` still trusts them).

## 143. Review R6: player actions are checked where they are done, and say what happened

- [x] Done

Review A2, A3 and package R6; the base for the gossip work (task 125's deed log listens to it).
Needs 139.
- Player-facing commands check their own conditions: crafting checks the station's kind, map and
  reach (today a kiln recipe starts on any workbench); using a tile checks reach, the horse and the
  map, not only Main. Trusted low-level setters stay as they are; debug bypasses are explicit.
- One outcome for each finished action (who, what kind, where and on which map, the object and the
  items with counts), published once after it succeeded and never for a refusal or on load.
  Sounds move onto it; the deed log of task 125 will use it. No global event bus.
- World and Interior tell their views about object and terrain changes the same way, so Main stops
  rebuilding the interior for particular tool results.
- Tests: the kiln-on-a-workbench probe and an out-of-reach use are refused without side effects; the
  same action from the UI and from code gives the same state and one outcome; loading a save gives
  no outcomes.

Done: the pick-up order, shift-click and the cost-off craft follow-ups of task 139 first. Then
`Crafting.craft` needs a station of the recipe's kind on the player's map in reach (`WRONG_STATION`,
`NO_STATION`; `take_out` needs reach), and `ToolUse.use_tile` refuses a tile out of reach or off the
map (`OUT_OF_REACH`, nothing changed, no energy; Main's own check is gone; one rule,
`Targeting.is_tile_in_reach`). `ActionOutcome` (who, kind, tile and map, object, items) is told once
through `GameState.action_done` by tool uses, the hammer, crafting, eating, dropping, picking up and
taking a building down: never for a refusal or a load. The work sounds listen to it; only the
refusals ("denied", the scythe at nothing) still come from the result of a use. `GameMap` declares
`objects_changed` and `tile_changed`, `Interior` emits them and `InteriorView` redraws from them
(once per change), so Main rebuilds nothing. Player-visible changes: a kiln recipe at a workbench is
refused ("Made at the Kiln"), a craft out of reach says "Too far from the station", the pick-up pop
also plays for a pile taken only in part, and a building placed by world code alone is silent.

## 87. Willows that stand out from the grass

- [x] Done

Dropped as a task (the user, 2026-11-07) and kept as a point for the next graphics review.

Done: by task 108 (the willow's crown closed with an edge, the rods and warmer bark, as the art
review of 2026-11-08 asked) and task 101 (grass and reeds stand out from the ground: a ground
shadow, a dark foot, an outline only round dense cores). Closed in the tasks review of 2026-11-09.

## 151. Cows at 32 px: the head the right way up

- [x] Done

The user, 2026-11-09: "32x32 cows look weirdly twisted as if the head is upside down."

Done: the grazing head was the ahead head transposed (a mirror, so forehead and eye sat on the jaw side). It is drawn on its own now (`COW_HEAD_DOWN` in `tools/art/livestock.py`). The standing head is unchanged; the other 32 px animals and the 16 px cow were checked and are fine.

## 153. Villagers wear desire paths too

- [x] Done

The user's words of 2026-11-10: "The tracks that show up on tiles that you walk often are good.
NPCs should contribute to those."

- Every villager that steps onto a new tile outdoors wears it, like the player and the farm
  animals, with its own step amount in data/paths.cfg; their daily routes slowly become paths.
- The same on and off screen; the wear fades as before when nobody walks there.
- Tests, and the design page and README say it.

Done: `Npcs._walk` wears the tile a villager steps onto (`World.wear_tile` at `villager_step`,
half a step, in data/paths.cfg beside `animal_step`; `PathRules.villager_step`), for every
loaded villager, on screen or off, since they all move in `Npcs.update`; only on a tile change,
so it costs nothing measurable (`make bench` frame mean 7.19 ms before, 7.15 after). Nothing
while they rest at night or while the player is inside (the world stands still); the wear
table and its save format are unchanged and the nightly regrowth fades it as before.

## 123. Tilled soil: seamless, flat furrows, and its colour follows the moisture

- [x] Done

The user, 2026-11-08, with screenshots of hoed patches: "the patches of soil don't look
seemless. Also the wavy pattern is weird, fresh prepped soil looks rather flat or has straight
lines but certainly not waves." And: "watered soil looks almost identical to unwatered one. Dry
soil should look rather bright brown like the middle 'cross' that comes from the pattern. Only
when watered it should get this dark. If there is a humidity level for the soil, that should be
reflected by the brightness of the brown so from dark brown when humid turn slowly to a bright
whitish brown when drying out."
- Seamless: neighbouring tilled tiles join into one bed, with no seams or lighter cross where
  four tiles meet (the soil terrain in tools/art/terrain.py and its autotile edges).
- Flat: fresh soil is flat or has straight furrows, no waves.
- Moisture: there is one (World `moisture_at`, 0 to 1). Today SoilWetness only lays dark dashes
  over the soil from 0.35 (damp) and 0.7 (wet). Instead the whole tile's brown follows the
  moisture in several steps: bright, whitish brown when dry, darkening to dark brown when wet,
  and lightening again day by day as it dries. The dry look is the base; watering visibly
  darkens it at once.
- Both art sets (task 117), every season, frost and snow; crops on it stay readable. At dusk
  and night the steps may fade: "that's how darkness works" (the user).

Done: the soil terrain is the driest look (flat, straight furrows, one tile, so no seams) and
`SoilWetness` lays the whole tile's brown over it in four steps by moisture (0.25, 0.5, 0.75;
fresh soil is on the second), cut to the bed's shape by the 47 neighbour masks of
tools/art/soil_beds.py so field edges keep their rim and the tiles inside show no seam; the old
dashes (which left the lighter cross where four tiles met) are gone. The browns are existing
palette colours (`soil_dark` to `soil_light`, a `sand_light` crest on the driest; no new palette
colour). Both art sets. Snow-covered soil is not drawn moist, as before. The user's 2026-11-09
addition: the sown mound is dark earth with cream seeds (`crops.MOUND_SOIL`), so a sown tile reads
as planted at zoom 0.5. Screenshot of the states: docs/screenshots/soil.png.

## 155. Worn ground tiles join up: desire paths without a pattern of shapes

- [x] Done

The user, 2026-11-10, with a screenshot of a well-walked yard (100 rabbits from the console):
"The wear actually looks weird. The tiling doesn't fit, it doesn't adjust when new wear is
added." The worn ground shows a repeating grid of hourglass and oval shapes instead of a
joined patch of trodden earth, and the edges don't follow when more tiles wear.
- Find the cause: the dual-grid terrain (WorldView `redraw_tile` redraws the 4 cells around a
  tile) and the trodden and path stages of `World.wear_tile`: are there edge tiles between
  trodden and path, and between both and every grass kind (lush, dry, floodplain), in both art
  sets and every season? Is the stage of a tile, or of its neighbours, read from stale chunk
  looks (ChunkLooks codes), so cells are drawn from an old neighbour?
- Worn ground joins into one patch with its rim against grass, like the tilled soil of task
  123 (no seams, no shapes repeating per tile), and adjusts at once as tiles wear or regrow.
- Tests for the redraw when a neighbour's stage changes; before and after screenshots of a
  yard worn by many animals (the console can spawn them).

Done: the cause was the 32 px full tiles of `trodden` and `path` (tools/art/terrain.py): they were
patterned with tile-wide noise blobs (cells of 8 and 16 px) and stamps, picked at random per tile,
so every worn tile showed its own oval or hourglass and the tiles did not join. The redraw was not
stale: `redraw_tile` redraws the 4 cells around a tile and the edge tiles between stages and every
grass kind exist (tests added for the cells between worn tiles). A full tile is now an even colour
(trodden dark earth, path earth) with single specks of 3 percent and no stamps, in both art sets
and all looks (palette unchanged; the user asked for it calmer still). `--worn-ground=<x>,<y>`
wears a yard for screenshots (`DebugWornGround`); screenshot docs/screenshots/worn-ground.png.

## 154. Skipping time moves the whole world forward, like the clock ticking

- [x] Done

The user, 2026-11-10: "Time skip seems to not affect crops. It should. Also other stuff should
get affected like NPCs' schedules once that gets implemented, or birds' movement. Skipping time
should be like moving the game engine's tick clock forward for everything."
- Today the console's `skip` (game/state/console.gd `_skip`), sleeping and passing out only call
  `clock.advance(minutes)`; what happens per day runs on `new_day` (NightUpkeep), and what runs
  per frame (crop growth by the minute?, soil drying, weather, livestock, villagers, wildlife,
  stations' work) doesn't see the skipped minutes. Find out exactly what does and doesn't follow
  a skip of minutes, hours and days.
- One way to move time for everything: a skip, a night's sleep and a pass-out advance the same
  simulation step by step (or in catch-up steps a system declares), so after it the world is as
  if the time had been played: crops grown or withered, soil dried, weather moved on, kilns done,
  animals and villagers where their day puts them, birds gone or arrived. Views follow from the
  new state.
- This is the core of Review R8 (Later: one owner for the simulation and its time, one catch-up
  rule); do that part here and leave the rest of R8 in Later.
- Tests: skip 1 h, 1 d and 30 d against the same time played in small steps, for crops, soil,
  weather, stations and animals; sleep and pass-out go the same way.

Done (the user's answers of 2026-11-10: the player is unaffected by a console skip, a time
traveller; crops and soil update gradually in 1 h intervals; unloaded chunks do not matter):
`Simulation` (game/state) is the one owner of game time: Main's frames, sleeping, passing out
and the console's `skip` all go through `advance` (played, cut at every full hour) or `skip`
(not lived through: the first 3 minutes are played minute by minute, the rest made up for at
once), and what changes with time is a `SimulationSystem` run in a fixed order. Crops grow, are
hurt and heal every hour (a 24th of a day, in the weather of its day; the end of the day counts
for them by what they were at dawn, so ripening and withering take the days they took); the
tilled soil follows the weather by the hour but is worked out when looked at (`SoilMoisture`), so
an hour costs nothing for 27,000 tiles and a 30-day skip about a second for 250 crops (a
1,000-tile field); reeds, saplings, stumps, bushes, clay spots and desire paths stay nightly
(`NightUpkeep`). Weather, sun, tide, snow and a kiln's work are pure functions of the clock and
needed nothing (tests prove it). Farm animals and villagers in loaded chunks are put on a
tile they could have walked to (`ReachableTiles`) with dice from the world seed and the time,
followers beside the player; the wildlife and the weather show the new time at once. A console
`skip` leaves the player alone; sleeping and passing out keep their player effects. Tests:
`tests/test_time_skip.gd` (1 h, 1 d, 30 d against 5-minute steps; sleep; pass-out; timing),
`test_farming_upkeep`, `test_actors_catch_up`, `test_wildlife_settle`. Left in Later (Review R8):
hunting out of FarmAnimalView, chunk residency apart from drawing, PlayerView's per-frame state,
shared wildlife rules. Pending with the user: a crop planted mid-day now grows pro rata from its
planting hour instead of a full day at the next midnight (about half a day later to ripen on
average, same totals per full day).

## 157. `make test` fails on a test file it skips

- [x] Done

The user, 2026-11-10: "it should fall on broken tests so that they get fixed". A review of task
154 found a test file with a parse error whose tests silently didn't run.
- tools/run_tests.py names each script that failed to load (a parse error) and each test file
  GUT skips because it doesn't extend GutTest, and fails the run for either.

Done: a parse error was already caught, but only as "a script failed to load", without the file;
a test file that parses but doesn't extend GutTest passed the run with a GUT warning. Both now
fail and are named (checked with a broken and a non-GutTest file in a scratch copy).

## 148. The ambience test is flaky: seed its wildlife

- [x] Done

`tests/test_ambience_sounds.gd` sometimes fails because the wildlife it runs isn't seeded (an
extra `frog_croak`). Give the test a fixed seed, or count only the sounds it asserts about, so it
passes every run; no game change.

Done: the test seeds the ambience's dice, and the storm test's second step asserts that no new
loop starts instead of that nothing at all sounds: a bird, a gust or a frog at water near the
player may come in any second, and that was the extra `frog_croak`.

## 147. Frame spikes: find and smooth the long frames

- [x] Done

The user, 2026-11-09: once all current tasks are done. After task 142 the mean frame on the
`make bench` save is about 8 ms, but single frames still take 120 to 190 ms (before 142 too).
- Find what the long frames do (chunk loading and drawing in WorldView, villager or wildlife
  updates, autosave, GC of big arrays): Godot's profiler or timing around the suspects, on the
  bench save and while walking across chunk borders.
- Spread the heavy work over frames (a budget per frame, or a worker thread for pure data) so no
  frame goes over about 33 ms on the bench save; same pictures, same game.
- Merged from Later (task 6 review): a chunk load took about 8 ms, spikes 16 ms at a chunk
  border; generation is pure and could run on a `WorkerThreadPool` task, drawing could be split
  over frames, and `set_cell` skipped for layers a cell doesn't use. Also per frame:
  `Occlusion.building_rect` calls `load()` for a size, and `World.buildings()` copies the array
  (task 14 review): cache them.
- `make bench` reports the longest frame and how many frames went over 33 ms, before and after.

Done: `make bench` now times two scenarios on the bench save (standing for 300 frames, walking
70 tiles east across chunk borders) and lists the frames over 33 ms; `save.gd` times a save.
What the long frames did, headless on the bench save (ms; how often):

| Suspect | ms | How often |
|---|---|---|
| Chunk load: generate (8) + draw (45) + soil (1) | 55 | 7 in a row at each chunk border while walking |
| Passing out: `ActorsUpkeep.skipped` 42, wildlife settle 18, farming 3 | 68 | once, under the fade |
| Passing out: the synchronous save (snapshot 74, JSON text 62, write 10) | 148 | once, under the fade |
| A timed or quick save: snapshot + JSON text on the main thread | 106 | every 10 minutes |
| `FarmingUpkeep` every hour, `NightUpkeep` at midnight, soil refresh queue | 0.005, 0.6, 0.03 | no suspect (the bench save has no crops) |
| `Occlusion.building_rect` `load()` and `World.buildings()` copy | 0.0007 | per frame, no buildings on the bench save; grows with the buildings, not a spike |

Fixed: a chunk is drawn in steps (a row, the objects, the borders) of at most 8 ms a frame (16
ms next to the player's chunk) and the next one loads when it is drawn; the JSON text of a
save is made on the worker (the main thread keeps the snapshot, which shares nothing with the
game); passing out gives the sleep and the save a frame each, the save in the background.
Before and after, `make bench`:

| | before | after |
|---|---|---|
| walking, longest frame | 82 ms | 22 ms |
| walking, frames over 33 / over 16.7 ms | 14 / 14 | 0 / 14 |
| standing, longest frame | 223 ms (the pass-out) | 102 ms (the pass-out) |
| standing, frames over 33 ms | 1 | 2 (both the pass-out, under the fade) |
| mean frame | 7.6 ms | 7.2 ms |
| autosave stall on the main thread | 106 ms | 50 ms |
| world settled at the start | 4.9 s | 5.8 s |

Left: the pass-out under its fade still has two frames of 67 and 102 ms (the villagers' skip,
`ActorsUpkeep`, and the snapshot; sleeping in a bed (`_try_sleep`) still saves synchronously);
the snapshot of a heavy save (50 ms) is one frame of `to_dict` on the main thread, which only
an incremental or cached snapshot would cut; generation (8 ms) stays on the main thread, a
`WorkerThreadPool` task was not needed to stay under 33 ms; the building size cache and the
`buildings()` copy were left as they are (they cost nothing measurable); the start takes about
a second longer as the chunks round the player are drawn within a budget.

## 156. Horses at 32 px: legs with upper legs

- [x] Done

The user, 2026-11-10: "a review of the horse graphics. In 32 they look like they are missing
upper legs as the leg starts slim and almost under the belly." Review the 32 px horse and pony
(tools/art/livestock.py) in every look, pose and facing, as the cow was in task 151: the legs
should start wide at the body (forearm and gaskin), set at the shoulder and the hip, not slim
from under the belly. Fix the drawing, keep the sizes of the cells, and check the saddle and
the riding sprites still fit. Before and after crops and an in-game screenshot.
- The user, 2026-11-10: "when head down eating grass, the head is way too long and they look
  more like ant eaters." The grazing head and neck: a horse's head is about as long as its
  neck is deep; lowered, the neck slopes down from the withers and the muzzle reaches the grass
  in front of the forelegs, not a long thin snout.

Done (second go after the user's reference picture): the forelegs start at the chest and the
hind legs at the rump with a big forearm and thigh (an extra joint mid-forearm and mid-gaskin
keeps them thick down to the knee and hock, shaded with the body so the belly shadow stops
between the legs), the flank is tucked up, and the cannons stay slim. The grazing head is short
and wedge-shaped on a neck that drops nearly straight down, the muzzle just in front of the
forelegs (fifth go, approved by the user). Horse, pony and the saddle and riding sheets; the 16 px
horse had neither fault.

## 158. Frame spikes left after task 147: the save snapshot, the bed's save, the pass-out

- [x] Done

The user, 2026-11-10: "start the performance follow ups" (the leftovers of task 147, see its
Done note in docs/tasks-done.md).
- The snapshot of a timed or quick save (`to_dict` on the main thread) takes about 50 ms on the
  `make bench` save: make it cheap in the frame (for example cache the dict of what didn't change
  since the last save, such as chunks, and rebuild only what did), so a save costs well under
  16.7 ms on the main thread. The snapshot still shares nothing with the game, and a save
  written that way loads the same as one written in full.
- Sleeping in a bed still saves synchronously in one frame: save as passing out does, in the
  background without stalling.
- Passing out still has two long frames under the fade (about 67 and 102 ms: the villagers'
  skip in `ActorsUpkeep`, the wildlife settle, the snapshot): spread them so no frame goes over
  33 ms, the same world after the skip.
- `make bench` before and after (a scenario for the bed if it has none); same game, same saves.

Done: `make bench` now times four scenarios on the bench save (standing, passing out with the
energy set to 0, sleeping in the camp's bed, walking), starting at 10:00 so that no late night
passes out by itself. What the long frames were (headless, ms):

| Frame | ms | What it did |
|---|---|---|
| Sleeping in a bed, the one frame | 196 | the skipped time (about 70) and the synchronous save: snapshot 52, JSON text 60, write 10 |
| Passing out, first frame | 69 | walked minutes 5, farming 5, `ActorsUpkeep.skipped` (villagers, about 42), wildlife settle 18 |
| Passing out, second frame | 84 | the snapshot: `to_dict` 52, of which about 25 was the soil catching up its 27,000 tiles after the skip |
| A timed or quick save | 52 | the snapshot on the main thread (the bench save is heavy: 30,000 tilled tiles, 10,000 piles, 155 villagers) |

Fixed: the bed sleeps like passing out: the sleep (`GameState.sleep_in_over_frames`) and the
save (`SaveService.save_without_stalling`) under the black screen. The time of a sleep is made
up for over frames (`Simulation.skip_over_frames`): the villagers in steps of 8 ms (`Npcs
.catch_up_over_frames`), the soil caught up in steps (`SoilMoisture.catch_up_all_over_frames`),
the wildlife settle, the wake-up and the snapshot a frame each; the same dice in the same order,
and Main holds the world still meanwhile (`_hold_world`): the animals and villagers, and the views
that change it by themselves (chunks streaming in and out, the cats' hunts, the wildlife), until
the player has woken; a quit waits for that, so a save is of a whole morning. So the world ends
as after `skip` (tests/test_actors_catch_up.gd compares whole games, their dice and what the
animals and villagers are in the middle of; tests/test_sleeping_in_bed.gd, on Main, a quit in the
middle of a sleep, the chunks staying as they are, and a cat beside a mouse starting no hunt).
Both steps share one budget, `Simulation.frame_budget_usec` (8 ms a frame). The hotbar wheel's
arithmetic moved out of Main into `HotbarWheel`, as Main reached its 1000 lines. The snapshot copies the big maps as they
are (the terrain edits, soil moisture, wear and clay spots as dictionary copies, the piles as
packed arrays) and a worker makes the save data of them (`GameState.dict_of`), so nothing is
cached and no writer can be missed; `SoilMoisture.catch_up_all` is skipped within the hour it
was done in. A save is byte for byte the one written before (checked on the bench save), and
tests/test_save_snapshot.gd changes every kind of thing after a snapshot and checks the snapshot
is still the game of its moment. Before and after, `make bench`:

| | before | after |
|---|---|---|
| passing out, longest frame | 84 ms (2 frames over 33) | 25 ms (0) |
| sleeping in a bed, longest frame | 196 ms (1 over 33) | 21 ms (0) |
| walking, longest frame | 23 ms | 23 ms |
| standing, walking: mean frame | 6.9, 7.1 ms | 7.1, 7.2 ms |
| snapshot of a save on the main thread | 52 ms | 10 ms |
| JSON text and save data on the worker | 60 ms | 91 ms |

Left: the snapshot is 10 ms, not a few: copying the 30,000 terrain edits and 27,000 moistures
as dictionaries (2 ms each), the piles (3 ms) and the villagers (2 ms) is most of it. A per-chunk
cache of the save data would cut that further but needs every writer of the cached maps hooked,
and the save would then list the edits by chunk instead of in the order they were made; it was
not done. The worker does more than before (it makes the save data), which nothing waits for.

## 160. Small leftovers: the pony on the command line, a test of the AMD path, the herd picture

- [x] Done

The user, 2026-11-10: "implement the rest from Small leftovers" (and drop the cached save
snapshot left from task 158: not done).
- `--livestock` accepts `pony`, as it does the other farm animals.
- A committed test of tools/llm/llm.sh's GPU choice (task 150): a fake device tree and
  `LLM_DRY_RUN=1` for NVIDIA, AMD (with and without `LLM_HSA_OVERRIDE`) and the CPU fallback,
  run by `make test`.
- The README picture docs/screenshots/dogs-cats-horses.png re-taken with the horse of task 156.

Done: `--livestock=pony` puts horses of the pony look near the player (`Livestock.spawn` takes an
optional look; tests/test_livestock.gd). tools/llm/test_llm_gpu.py, run by `make test`, runs
`LLM_DRY_RUN=1 llm.sh up` against a fake device tree for NVIDIA, AMD (with and without
`LLM_HSA_OVERRIDE`, the RDNA2 and 7600 hints, two cards), the CPU fallback and every `LLM_GPU`
choice; llm.sh got `LLM_CDI_DIRS` for it. The picture was not re-taken: the old one is
1000x1040, but the compositor decides the window size here (`--resolution 1000x1040`, also with
`--windowed` and `--position`, still gave 882x1372), and a picture of another shape would not
fit the README. It became task 164 (a screenshot size option).

## 164. Screenshots in the size asked for, whatever the window

- [x] Done

The user, 2026-11-10: "Yes, do that, start it now" (a size option for screenshots inside the
game). `make screenshot` saves the window as it is, and on Wayland the compositor decides the
window's size (882x1372 or 882x439 here, whatever is asked for), so a README picture can't be
re-taken in its old size (task 160).
- A `SIZE=WxH` for `make screenshot` (a game option under it) makes the picture exactly that size,
  the same view and HUD as a window of that size would show, whatever the compositor does with the
  window (e.g. the world and UI drawn into a viewport of that size, or the root viewport's size
  forced); muted and without stealing focus, as now.
- Then re-take docs/screenshots/dogs-cats-horses.png with the horse of task 156 in its old size
  (1000x1040), the same scene as before (the item task 160 left to Later).
- The user, 2026-11-10: "I run KDE with Krohnkite tiling script. So the opening window gets
  tiled immediately ... the window always pops up in the foreground. If we can identify test runs
  of the game I can add rules to not tile the window and maybe put it in the background." Every
  window a tool or an agent opens (`make screenshot`, and any other target that opens one for a
  check) carries a fixed title and, where the display driver allows it, its own app id or window
  class (for example `sandbox-game-test`), different from the game the user plays; documented in
  tools/README.md with a KWin rule and the Krohnkite ignore setting to match it.

Done: `make screenshot SIZE=WxH` (game option `--screenshot-size=WxH`) runs the game in a viewport
of exactly that size (game/scenes/screenshot_frame.tscn, which the Makefile starts instead of the
main scene), stretched as the project's window is (base size, aspect `expand`, the UI scale of
the settings); `ViewMath.window_size` gives the camera and the wildlife view that size instead of
the window's. Tried first: a real window resized (the compositor ignores it), the root window's
size forced, and an embedded Window (its picture came out at the compositor's scale or
unstretched). The window of a check is titled exactly "Sandbox Game (test)" by the game flag
`--with-working-window-title`, which `make screenshot` passes and `make run` does not
(`make run ARGS=--with-working-window-title` does); tools/README.md names it as the text the
user's KWin and Krohnkite rules match. Godot's Wayland driver sets the app id `Sandbox Game`
(the project's name) before the window shows, and the title "Godot" first, then the project's;
the game sets the working title once its first scene starts. docs/screenshots/dogs-cats-horses.png
was re-taken in its old size, 1000x1040, with the 32 px horse: `make screenshot SIZE=1280x1200
ZOOM=1.165 TIME=11:00 ARGS="--livestock=dog,cat,horse --day=40"`, cropped to the 1000x1040 at
x=200, y=100 (the player is then where he was in the old picture, and the HUD is cut off, as in
the old one). The animals are placed at random, so their places differ from the old picture's.

## 159. Cows at 32 px: a neck, the udder between the legs, legs from the body

- [x] Done

The user, 2026-11-10: "The cows don't have a neck, the utter is on top of the leg instead of
inbetween" and "they also have a similar shading and leg position issue as the horses", with a
reference picture (a Holstein from the side: a short deep neck dipping from the withers, a
dewlap, the udder under the belly between the hind legs and in front of them, the legs running
down from the chest and the rump).
- A short, thick neck that dips from the withers to the head, with a dewlap under the throat; the
  grazing head on that neck too.
- The udder under the belly between the hind legs, the far hind leg showing behind it, not
  drawn on the thigh.
- As the horse in task 156: the forelegs start at the chest and the hind legs at the rump, wide
  forearm and thigh shaded with the body so the belly shadow stops between the legs, then knee
  and hock and slim cannons.
- Every look, pose, facing and season of the 32 px cow (tools/art/livestock.py), cell sizes
  kept; before and after crops and an in-game screenshot.
- The user, 2026-11-10, after three goes that each changed the old drawing ("cows third go
  looks even worse"): "drop the current version entirely and start from scratch with my provided
  image as a reference". The cow is drawn anew from the user's references, not from the old cow.

Done: the cow is drawn anew by hand in tools/art/livestock.py, after the user's reference
picture (a pixel Holstein): maps of letters for the body, the neck and the head looking ahead or
grazing, each leg, the tail and the udder (`COW_TORSO` and the pieces after it), laid over each
other for a pose by `cow_frame` and shaded by their letters, the body, neck, head and near legs
as one form lit from the top left, the pied patches with it, the far legs a step darker. The cow
is 64 px from the rump to the muzzle and 35 px to the withers: a deep neck sloping from the
withers to a big head with horns and the ears out to the sides, hanging a little below the back
line in front of the chest, a soft dewlap; the udder far back under the belly, the near thigh in
front of it and the far hind leg behind it; forelegs from the chest with a wide forearm, a knee
and a slim cannon, hind legs from a big thigh with a slight hock. Walking, the legs lean;
grazing, the same head hangs on a neck reaching down in front of the forelegs; lying, the legs
fold under the body and the eyes shut. The user approved the standing pose first ("Those cows
look perfect!"), then the rest was drawn in its style. Every look, action and frame of the 72x54
sheet is kept; every other animal's sheet and the 16 px classic cow are unchanged. The README
picture docs/screenshots/livestock.png was re-taken in its old size, 2756x1040: `make screenshot
SIZE=1520x1360 ZOOM=2 TIME=09:00` and `TIME=01:00` with
`ARGS="--livestock=cow,sheep,chicken,rabbit --day=40"`, each cropped to 1376x1040 at x=125, y=38
and set side by side with a 4 px seam.

## 162. Chunk loading is decided apart from drawing

- [x] Done

The user, 2026-11-10: R8 deliverable 3. Today WorldView, the renderer, decides which chunks are
loaded and unloaded.
- Chunk residency moves to a session controller apart from drawing, keeping `ChunkStreaming.plan`
  and today's budgets (task 147's drawing budget stays in WorldView). Gameplay can ask for the
  chunks an action needs whether or not a renderer is attached.
- Acceptance: a headless controller loads the chunks an action needs without a WorldView;
  detaching or replacing the renderer doesn't unload state the game needs; the hold over a sleep
  (task 158) holds the controller. Screenshots: streaming, seasons, occlusion, tree fall,
  interiors and the art switch as now; `make bench` no worse.

Done: `ChunkResidency` (`game/world/chunk_residency.gd`, a plain class made by Main, no nodes)
decides and does the loading: it follows the focus, plans with `ChunkStreaming.plan` (radius 3 to
load, 5 to unload, nearest first), generates one missing chunk per update (when the view has drawn
the last one) and drops the far ones, and tells by `chunk_loaded` and `chunk_unloaded`. WorldView
only shows a residency: it queues the loaded chunks and draws them in task 147's steps and budgets
(8 ms, 16 ms next to the player), erases the unloaded ones, and refreshes the looks and settles as
before (`is_settled`). `require(tiles)` loads the chunks an action needs at once, with no view;
a view that goes leaves the chunks loaded, and a new one draws them when it starts. The hold over
a sleep (task 158) and indoors sets `ChunkResidency.is_held`: a held residency loads and drops
nothing (tests/test_chunk_residency.gd, tests/test_sleeping_in_bed.gd). Left as it was: the few
places that load a chunk by hand for a look (`GameState._home_bed`, the console's `tp`,
`CampSite`) still call `World.add_chunk` themselves. `make bench` before and after (longest
frame, frames over 33 ms; standing, passing out, sleeping, walking): 26.1 ms (0), 25.8 (0), 42.4
(2), 31.0 (0) before; 18.4 (0), 23.1 (0), 26.1 (0), 23.1 (0) after (a noisy machine); settle 345
frames, 6.9 s before and 318 frames, 6.3 s after. Screenshots at 1000x1040 (camp, night at
23:00, the inside of a house) are the same terrain and objects before and after; only the
animated bits differ.

## 161. Hunting moves out of FarmAnimalView

- [x] Done

The user, 2026-11-10: the rest of review R8 as three tasks (review/code-review-2026-11-09, R8
deliverable 1). Today a cat's hunt is started, tracked and stopped by its FarmAnimalView
(`start_hunt`, `track_prey`, `stop_hunt`), so whether a cat hunts depends on its view existing
and running (task 158 had to hold the world view over a sleep for this).
- The hunt is decided in the game state (Livestock or a small controller); the view only shows
  it. Decide the lifecycle of the ambient prey (mice) it hunts.
- Acceptance: hunting tests run without a FarmAnimalView; a view removed mid-hunt leaves a
  defined result (no cat stranded in a crouch); camera movement alone doesn't change what a saved
  animal does. Same hunts, same looks as now.

Done: a cat's hunt is decided in Livestock (`game/state/livestock.gd`): when a cat picks what to
do next it looks for the nearest `Prey` (`game/state/prey.gd`) within `sight_tiles`, `start_hunt`
makes it crouch, creep and pounce, the catch is rolled with Livestock's dice as the pounce
starts, and a cat that lands catches the mouse still under it. A `Mouse` (still ambient wildlife
of the WildlifeView, near the camera, not saved) owns a `Prey` it keeps up to date (position in
tiles, `is_about`) and registers with `Livestock.add_prey`; the hunt's outcome is left in
`Prey.fate` (caught, or scared from a point) for the mouse to show. Prey lifecycle: a mouse is
about while its node lives; once it is done, caught or freed (`_exit_tree`, so a cleared or
freed wildlife view too) it is no longer about and any cat after it ends its hunt, rests and
idles where it stands. With no wildlife view there are no mice, so nothing hunts and nothing is
stranded; a freed FarmAnimalView changes nothing of a hunt, and a cat far from the camera hunts a
mouse in sight like any other. FarmAnimalView only plays the frames of the activity.
`start_hunt` takes a `Prey`; `track_prey` and `stop_hunt` are gone (the state tracks, and ends
the hunt by itself); `FarmAnimal.prey` is now `pounce_at`, and `hunted` is the mouse. A cat looks
for a mouse at every pick of what to do next, and on waking and after a blocked walk, as the view
did; the state's track of the mouse is one step earlier than the view's was, and a mouse tells
the cats where it is after it has moved (the cats see it a frame late). Skipped time hunts
nothing: `Livestock.update(..., may_hunt)` is off for the walked minutes of a skip
(`ActorsUpkeep.walked_minute`) and `catch_up` abandons any hunt, with no outcome for the mouse.
Task 158's hold stays: the livestock is held over a sleep, which now
holds the hunts; the view stays held for the wildlife. The cat test of
tests/test_sleeping_in_bed.gd now sets a rested cat creeping within pounce reach of a mouse at the
first walked minute of the sleep (and about to pick what to do next on each held frame), and
tests/test_actors_catch_up.gd (sameness) stays green. New tests:
tests/test_cats_hunting.gd (no view: nearest mouse in sight, no mouse, scare, catch, a mouse
moved off, the same dice give the same hunts with each hunt reaching its pounce, a mouse gone,
waking to a mouse, the walked minutes of a skip) and tests/test_cats_and_mice.gd (the
cat's view freed mid-hunt, the wildlife cleared mid-hunt). Screenshots (`--hunt` at 19:00,
1000x1040) look the same before and after.

## 163. PlayerView and the wildlife rules stop repairing and sharing state

- [x] Done

The user, 2026-11-10: R8 deliverable 4 (review A5).
- PlayerView stops setting the held layer every frame; the held look follows the state when it
  changes, and the character preview works when PlayerView isn't processing.
- `WildlifeView.show_wildlife()` stops writing `rules.sun` into the shared
  `WildlifeRules.default_rules()`: the cached rules stay unchanged, the session's sun is passed in
  or held by a small session-bound rules object.
- Acceptance: two sessions with different suns don't change each other's rules; same looks.

Done: the held layer of the appearance now follows the selected item in PlayerState (it listens to
its inventory, as it does to the equipment); PlayerView and CharacterScreen no longer sync it
every frame. The wildlife rules already had `WildlifeRules.for_session(day_sun)` (the only caller,
`WildlifeView.show_wildlife`, uses it, nothing writes `sun` into the default rules); a test now
pins two sessions of different suns. New tests: tests/test_held_layer.gd.

## 149. Harvesting works, and dead plants are hoed away for the next crop

- [x] Done

The user, 2026-11-09: "make sure plants can get harvested and dead plants can be hoed away to
prep the soil for the next produce".
- Already there (tasks review, 2026-11-09): the empty hand harvests a ripe crop and clears a dead
  one, which leaves tilled soil (tool_use.gd); every crop ripens (test_crops.gd). The hoe only
  tills free grass and the scythe only mows, so neither clears a dead crop.
- The hoe clears a dead crop too (and decide with the user whether the scythe should): the tile
  is tilled soil again, ready to plant. Say what the player gets from it (nothing, or a little).
- Tests: each crop of the crop data harvested through a use when ripe, and what the player gets;
  a cleared tile (by hand and by hoe) can be planted, also after save and load.

Done: the hoe now clears a dead crop (the use is the till use, so it costs what tilling costs
(`till`, 2.0), and has the same swing and sound); the tile is tilled soil again, ready to plant.
Defaults, the user may change them: the scythe does not clear dead crops, and clearing a dead
crop (by hand or hoe) gives the player nothing. The empty-hand harvest and clear are unchanged.
Design page: design/farming/crops.md; README farming paragraph. Tests: tests/test_clearing_crops.gd
(every crop harvested when ripe and what it gives, hand and hoe clearing, plantable again also
after save and load, the scythe leaving the crop).

## 168. The language model's trouble shows as a notice in the game

- [x] Done

The user, 2026-11-10, after a run with Gemini printed "WARNING: Language model at
https://generativelanguage.googleapis.com/v1beta/openai/chat/completions: no answer (result 0,
HTTP 503) ... This model is currently experiencing high demand ...": "We need to bring that into
the game somehow as a notification like the "saving ..." etc messages".
- Today ModelChat (game/scenes/model_chat.gd `_send`) only calls `push_warning` (can't send, not
  reachable, no answer); the player sees nothing and the villager quietly speaks a scripted line.
- Show it in NotificationHud (game/scenes/notification_hud.gd, `post` with a key, as "Saving..."
  does): a short line the player understands, e.g. "Villagers' language model is busy (HTTP 503);
  they speak their own lines for now", "... not reachable", "... key refused (HTTP 401/403)",
  "... no answer (timeout)". Use the API's message (`error.message` of the JSON body) when
  there is one, cut short; the full text stays in the log warning.
- One key for the model's notices, so a new one replaces the old and a burst of failed lines
  shows once, not once per villager line; not shown again for the same trouble within a few
  minutes (in data/, e.g. npc_talk.cfg), and a quiet "Villagers' language model answers again"
  once it works after a failure. The default test endpoint that is often not running stays
  silent as today (said once in the log), unless the player has set an endpoint themselves.
- ModelChat stays free of HUD code: it sends a signal (or reports through the session) that Main
  wires to the notifications; the settings page's own notes stay as they are.
- The user, 2026-11-10: "don't show the default text when the request fails. In a chat remove
  the "is typing" message when a request failed." With a language model set, a failed request
  (any of the above, a refusal of ClaudeChat, or an answer that is empty after trimming) no
  longer falls back to a scripted line of data/npc_talk.cfg (NpcDialogue `reply`): the villager
  says nothing, nothing is added to their chat, and the chat screen takes away its typing
  bubble ("...") at once; the player's own line stays, and the player can write again. Scripted
  lines stay for a game with no model set, as today. Check every caller of `reply`/`say` (the
  chat screen, greetings or bubbles) for what an answer of nothing must do.
- Tests with a fake endpoint (503 with an API message, 401, timeout, success after failure,
  the throttling and the silent default endpoint); no scripted line and no typing bubble after
  a failure, scripted lines with no model; a README line.

Done: ModelChat sends `failed(endpoint, trouble, detail)` and `worked(endpoint)` (the detail is the
`error.message` of the API's JSON, also Gemini's list-wrapped one); ModelNotices (game/scenes/
model_notices.gd, one line in Main) shows them in NotificationHud under the one key
`language_model`: a red "Villagers' language model is busy (HTTP 503): <message cut to 60>", "refused
the key (HTTP 401)", "answered with an error (HTTP n)", "gave no answer in time", "is not
reachable", "can't be asked", "gave an empty answer", "gave an answer the game can't read", and
a plain "Villagers' language model answers again" once it works after a shown failure. The same
trouble is not shown again for 300 s; the numbers are `notice_repeat_seconds` and
`notice_detail_length` of [request] in data/npc_talk.cfg. The default test endpoint is silent.
With a model the player set, NpcDialogue `reply` gives "" on any failure (also an empty answer):
`say` adds nothing to the chat, resets `is_answering`, skips `compact` and emits `answered`, so
ChatScreen redraws without the typing bubble and the player may write again; their line stays.
The only caller of `say` is the chat screen (and the debug runner through it); there are no
greetings or bubbles that use `reply`. Decision, the user may change it: on the default endpoint
(the test LLM that is often not running) a failure still gives a scripted line, so a fresh game
is not mute. Not covered: an answer that is empty only after NpcPrompt's trimming (such as a lone
"Name:") gives no line and no notice. Docs: README "When the model fails", design/villagers/
dialogue.md and ideas.md. Tests: tests/test_model_notices.gd, test_npc_dialogue.gd, test_chat.gd.

## 152. Storks nest on roofs and raise their young

- [x] Done

The user, 2026-11-09: "Storks need nests, in breeding season you see offspring that eventually
leaves." Today a `roof_stork` (data/wildlife.cfg) flies in, stands on a roof near the view in
spring and summer and flies off again; there is no nest. Moved here from task 122.
- Nests: a stork's nest (a wide heap of sticks) on a roof ridge of some village buildings, and
  maybe on a pole or a dead tree; where they are comes from the world (seeded, the same in every
  game of a seed), saved if the player can change it. Drawn at 32 px and in the classic art.
- The year of a nest (the North Sea coast, GameClock seasons): empty in winter; the pair arrives
  in early spring and stands on it, clattering (`SoundEvents.animal_alarm` gives the clatter);
  in late spring the young appear, small grey heads over the rim, then larger and whiter through
  summer; the parents fly off to the meadows and back (the hunting `stork`); in late summer the
  young stand on the rim and flap, then leave one by one; in autumn the nest is empty again.
  Numbers and days in data/wildlife.cfg, seeded per nest so not every nest is in step.
- State that must last across days (the pair, the young, how far along) lives in game state and
  is saved; what the player only sees (flaps, clatter) stays in the views.
- Tests for the year of a nest by date, the seeding, save and load; a screenshot in the README.

Done: nests are on roofs only (a kate, longhouse, hall house or barn; about 4 in 10 by the world seed
and where the building stands); no pole or dead tree yet. Nothing is saved, which the task allowed
("saved only if the player can change it"): `StorkNests` derives which buildings have a nest and who
is in it (pair, young, how grown, how many parents are home) from the world seed, the building's
place, the year and the date and sun, so every game of a seed has the same nests, a load finds them
as they were, no save format changed and no upgrade step is needed, and the player changes a nest
only by taking its house down. Numbers and days: the `[stork_nest]` section of data/wildlife.cfg
(pair days 3 to 8, hatching days 17 to 26, young on the rim days 41 to 52, the last leaves by day
60), each nest and year with its own spread. The view (`StorkNestView`, one per nest near the view)
shows the nest all year, the pair as roof storks that fly off to the meadows and back and clatter,
the young as heads over the rim (small grey, half grown, white) and then standing, flapping and
flying off one by one. Choice: the random `roof_stork` stays but keeps off roofs with a nest, and the
pair of a nest are not counted among the roof storks. Art: tools/art/stork_nest.py and
classic/stork_nest.py (sheets `stork_nest` and `stork_chick`). Design page: design/world/wildlife.md;
README wildlife paragraph and docs/screenshots/stork-nest.png. Tests: tests/test_stork_nests.gd (rules,
seeding, the year, save and load) and tests/test_stork_nest_view.gd. Open: parents do not hunt as a
visible `stork` on the meadows (they leave the view), and weather does not keep them on the nest.

## 169. Music: can the game play generated modules? Measurements and viability tests

- [x] Done

The user, 2026-11-10: background music in the style of 1980s home-computer game music (the
user's reference is the C64 game Robin of the Wood): sharp sawtooth leads, short repetitive
parts that loop, with transition parts now and then or a crossfade between looping pieces. The
music is generated as cheap tracker modules from simple data and rendered in the game on a
background thread. Old folk music is the inspiration for the style; the tunes are our own (no
existing song, no melody from any game). This replaces "no background music for now"
(design/presentation/sound.md, 2026-11-05) once tasks 170 and 171 land. A second opinion
(GPT 6.1 Sol, 2026-11-10) shaped this task: measure first, decide after.

This task answers whether the plan works, with numbers, before the music is built:
- A minimal generator in tools/music/ (Python, deterministic, writing into art/generated/ and
  packed into assets/ like the other generated files; check that the raw .mod files are
  exported, as Godot doesn't import them): one short folk-style test piece of our own as a
  4-channel ProTracker MOD, an 8-bar loop and a 1 or 2-bar fill, with single-cycle instruments
  (sawtooth lead, pulse, triangle bass, noise drums) and a small stated effect set with exact
  opcodes (e.g. arpeggio 0xy, portamento 1xx/2xx/3xx, vibrato 4xy, volume slide Axy, set volume
  Cxx, note cut ECx, set speed/tempo Fxx, pattern break Dxx). It must open in OpenMPT or
  MilkyTracker; check it against an independent player (libopenmpt / openmpt123 if available,
  or say how else) rather than a second player of our own.
- A prototype MOD renderer in GDScript (game/audio/ or similar, kept apart from AudioService and
  data/sounds.cfg) that renders a section (an order/row range with a defined entry state) to an
  AudioStreamWAV, on WorkerThreadPool.
- Measurements, written into a report (docs/music-viability.md): render time of the 8-bar
  section and of a 1-minute piece at 22.05 and 44.1 kHz, mono and stereo; memory per minute;
  what the main thread spends (attaching the stream, copies) and whether a frame goes over task
  158's frame budget while rendering, also during a save; on this machine, with the CPU named.
- Viability checks, each a GUT test or a recorded result in the report:
  - the loop is seamless (the samples at the wrap match the continuation, no click);
  - a fill can follow the loop and the loop resume, landing on the bar;
  - AudioStreamInteractive (or AudioStreamPlaylist / two players) can switch and crossfade
    generated AudioStreamWAVs on the beat on Godot 4.7.2 (AudioStreamWAV exposes no BPM: find
    whether a subclass or another stream type is needed);
  - the render matches the independent player within a tolerance (pitch, length, events).
- The report ends with a recommendation: GDScript rendering at runtime, a native renderer
  (GDExtension around libopenmpt), or build-time renders of the generated modules; and the
  numbers behind it. Tasks 170 and 171 are then rewritten from it with the user.
- Not in this task: the Music bus and slider, the director, stems, 8 channels, more pieces.
  Test runs stay muted; nothing plays in the game yet.

Done: report in docs/music-viability.md (Intel Core Ultra 9 185H, Godot 4.7.2, headless, Dummy
audio driver). tools/music/generate.py writes pieces of plain text (tools/music/pieces/, the format
and the effect set with its opcodes in the docstring; other effects, effect memory and voices that
start a section without a struck note or a cut are refused) as 4-channel M.K. modules into
art/generated/music/, packed into assets/music/ by `make art`/`make assets`; the test piece
test_reel is our own reel in A dorian at 106 BPM (the user found 150 too fast), an 8-bar loop and a
1-bar fill. No libopenmpt, openmpt123, MilkyTracker, xmp or mikmod is installed, so
tools/music/check.py checks every module with the system's libmodplug through ctypes (rows, order,
speed, tempo, pattern break; ticks cut to whole samples as libmodplug does; part of `make art`,
skipped where libmodplug is missing). There are no export presets yet: one will need `*.mod` in its
non-resource filter (tools/README.md). The GDScript prototype (game/audio/tracker_module.gd, which
refuses what it can't play, and module_renderer.gd, apart from AudioService) renders parts of the
order list from a defined entry state into plain AudioStreamWAVs, made whole on WorkerThreadPool;
game/audio/music_crossfade.gd crossfades them on the beat with two players. Numbers (`make
bench-music`): the 8-bar loop (18.1 s) in 87 ms (22.05 kHz mono) to 289 ms (44.1 kHz stereo), a
minute in 0.3 to 0.96 s; 2.5 to 10 MB a minute; the main thread spends at most 0.2 ms per render
(take, hand to the crossfade) and under 0.5 ms in a crossfade's frame, and the frames while rendering,
also during a timed save that was written, were as without (mean 6.9 ms, nothing over 33 ms in two
runs); a copy of a minute's data on the main thread would cost 12 to 21 ms. Checks: the loop played
into itself is its start sample for sample, the fill breaks after a bar and the loop resumes on the
bar (tests/test_module_renderer.gd); every effect tick by tick, an arpeggio after a slide as
ProTracker plays it, a tick of no whole number of samples, malformed files
(tests/test_module_effects.gd); the crossfade's new beats fall on the old ones within a frame, also
across a loop's wrap (tests/test_music_crossfade.gd, the mixed bus captured), beginning 58 to 75 ms
after the beat on the Dummy driver's 93 ms blocks; `make music-check` against libmodplug: exact
length, 1 sample offset, loudness correlation 0.94 per tick, spectra 0.98 to 1.0 per row, the
strongest frequency the same in every row. AudioStreamInteractive switches on the beat only with a
script subclass of AudioStreamWAV that tells its BPM (tests/test_music_stream_wav.gd), and such a
stream, once played with Main running, makes the game abort on quit (cause not found).
Recommendation, provisional on the crossfade's lateness on a real audio driver (not measured: no
sound out loud): GDScript rendering at runtime on a worker into plain AudioStreamWAVs, two players
crossfaded on the beat, sample-exact transitions rendered into one stream; not a native GDExtension
(100 times faster, not needed); build-time OGG renders as the fallback. Tasks 170 and 171 are to be
rewritten from it with the user.

## 122. The farm yard: chicken coop, trough, hay rack and draw well

- [x] Done

From review/art-review-2026-11-08 (its task 6 and buildings rows 1 to 3 and 16), left out of
task 111 because each needs game data as well as art: a chicken coop (a building 2x2, low and
boarded, a ramp with cleats to a hatch, a nest-box lid; the hens sleep in it and the eggs are
collected there; an interior map), a trough (a hollowed oak log or a plank box with water) and a
hay rack (oak posts with slanting slats, hay behind them), 2x1 world objects that feed and water
the livestock (SPEC, Livestock), a draw well with a sweep (1x1 plus the sweep above it: an oak
well head on a fieldstone ring, a forked post, the balanced pole, the bucket and a weight stone;
water for the can, the animals and the house) (the stork's nest moved to task 152). Draw them at 32 px in the style of task 111 (tools/art/, a new
yard.py), give them types, recipes and placement (data/, world_object_types.gd), and decide
what each does for the animals.


Done (2026-11-10): the four things are in, in parts of their own, with the user's decisions of the same
day for the animals (see design/farming/livestock.md, "The farm yard"):
- **Draw well** (1x1 plus the sweep above it, see-through from behind): masonry 20 at the workbench
  from 12 stone, 3 planks, 2 logs and 2 fibre; the pickaxe takes it up. It fills the watering can,
  which now holds water (20 waterings, `[can] capacity` in data/energy.cfg, saved): the use key at the
  well or at fresh water (the terrain WATER: rivers, ponds, ditches; never the sea, the mud or the salt
  marsh) fills it, wetting soil takes 1, an empty can says so. Water for the house comes with cooking
  and washing (nothing uses it yet).
- **Trough and hay rack** (2x1, woodworking 10 and 15): each holds a stock of up to 100 units (the
  `stock` in the object's state, saved), shown in four pictures by the fill (empty, low, half from 35%,
  full from 70%), at 32 px and in the classic art. The can pours 10 units into a trough, hay 10 into a
  rack; the trough holds water, the rack feed (any item of `[yard] feed_items`, hay so far), and a
  feeding trough for the pigs of task 165 is the same object with `stock_kind` feed, any kind of
  livestock using it by its species' numbers.
- **Needs** (the user's decisions): every farm animal has a hunger and a thirst that rise with game time
  by species hours, are saved (save version 25) and have NO consequence yet (the place for the later
  better produce is named in the design page). Thirst is met at fresh water or a trough with water, hunger
  at a hay rack by those that eat feed (cow, sheep, horse, rabbit) and by grazing by those that graze
  (those and the hens); dogs and cats eat nothing yet (no feeder). Each drink or meal takes the
  species' units from the stock (cow 5, sheep 3, hen 3 a drink, ...); a skip counts the meals of animals
  that could reach what they need; the console's `noneeds` stops the rise (session only, not saved).
- **Chicken coop** (building 2x2, 12 logs and 4 stone, inside 6x6 with two hay piles as nests): a hen
  within 12 tiles of one with a free roost (6) walks to it at bedtime, sleeps in it out of sight and comes
  out in the morning; going in she lays an egg (0.7) in a nest (4 eggs each); the use key with an empty
  hand at a nest takes the eggs (new item: egg); a skip over her bedtime counts the egg.
Art: tools/art/yard.py and classic/yard.py (rows 51 to 53 of the object atlas, the coop among the
building pictures, icons for the four items and the egg). Save version 25 (the can's water and each
animal's hunger and thirst), the version 14 step dropped in its own commit first. Tests:
tests/test_draw_well.gd, test_yard_stock.gd, test_livestock_needs.gd, test_chicken_coop.gd,
test_save_upgrade_needs.gd. README section "The farm yard" with docs/screenshots/farm-yard.png
(`--yard` shows it, 22 tiles east of the stations).
Chosen as the mildest, the user may change: the can has a limit at all (20; the old can was
bottomless); a coop that is taken down loses its eggs; hens far from any coop sleep outdoors; dogs and
cats just get hungrier with nothing to eat. Open: nothing in the room shows the hens or the eggs
(animals are only drawn outdoors); the eggs have no use yet; a bowl for dogs and cats and grain for
the hens come with the feeding trough of task 165.

## 166. Tilled soil that isn't used grows back over

- [x] Done

The user, 2026-11-10: "tilled tiles that don't get maintained, used for crops etc eventually
turn back to their untilled style". Today tilled soil stays soil for ever.
- Tilled soil with nothing planted on it (no crop, living or dead, no sapling or placed object)
  goes back over the days: first a few weeds and grass tufts on it, then the grass (or the
  ground the tile had before tilling, e.g. the Geest's sand or the marsh) is back. Working the
  tile again (hoeing, planting, watering) starts the count anew. The days (and whether frost or
  winter pauses it) in data/crops.cfg.
- What the tile goes back to must be the tile's own untilled ground, not always grass; what
  lies on it (dropped items) stays.
- Game state, saved, and caught up over skipped time (sleep, pass-out) in the per-frame budget
  of task 158; the views only follow the terrain change (and the in-between weedy look, if any,
  is drawn in the 32 px and classic art).
- Tests: the days to grow back, the reset on work, a planted tile never grows back, the ground it
  goes back to, save and load, catch-up over a sleep; a README note.

Done 2026-11-11: fallow soil (game/state/fallow_soil.gd, World.fallow); weeds after 5 untended days, grass
after 10 (data/crops.cfg [farming]), winter days don't count, a frost day in another season does;
the hoe only tills grass, so the tile goes back to grass in its place's own look. Save version 26
(the upgrade from 15 dropped). The user approved the weeds and the rules the same day.

## 165. Pigs, and pig pens the player builds

- [x] Done

The user, 2026-11-10: "add pigs to the list and pig pens that can be build where pigs can be
in". Run after task 122 (the farm yard), before the gossip tasks.
- Art: a pig at 32 px (and the classic 16 px) in tools/art/livestock.py, with the frames the
  other livestock have (stand, walk, graze or root, sleep, the walk used as run). The user's
  reference is a pixel-art pig from the side (kept in the coordinator's scratchpad as
  pig/user_reference.png; proportions only, not its pixels, not its watermark): a long, deep
  barrel with a nearly level back, a big head held low with a long snout and a big ear flopping
  forward over the eye, short legs, a curly tail, light shading from the top and darker tones on
  the snout, ears, belly and legs.
- Older breeds, not today's pink pig: a bit more furry, which means more colour and more variety,
  as with the cows. Several looks in palette colours, e.g. a bristly red-brown, a sandy one, a
  black-and-white saddleback, a spotted one; bristles shown by a few broken tones along the back
  and flank, not by an outline.
- Game data: a `[pig]` section in data/livestock.cfg like the other animals (speed, what it eats,
  roaming, sleep), in Livestock and the save; what it gives the player is decided with the user
  (none, or meat later with the economy).
- Pig pen: a building the player builds (recipe, placement, data/buildings.cfg or a world object
  set): a low fence of split oak rails or wattle around a few tiles, with a gate and a small
  shelter, plus a trough (task 122). Pigs stay inside the pen they belong to: their roaming is
  bounded by it, they don't walk through its fence, and the gate lets the player in and out.
- Tests: the pig's state, roaming that stays in its pen, building a pen, save and load; the
  README livestock picture and a pen screenshot.

Done (2026-11-11), the art approved by the user ("Not perfect but let's take them the pigs for now",
after two redraws: a short, deep body with the head below the back line, then legs as limbs out of
the body and a tail grown out of the rump), with these decisions (chosen as the simplest, the user
may change them; see design/farming/livestock.md, "Pigs" and "The pig pen"):
- **Pigs:** four looks (red-brown, sandy, saddleback, spotted), drawn by hand as maps of letters at
  32 px (52x32 cell, 40 px long, 23 px tall) and in the classic art, with every livestock frame.
  `[pig]` in data/livestock.cfg: they root for most of the day (the graze, which feeds them), never
  run about, eat at a stock of feed and drink like the others (the needs of task 122: hunger 10 h,
  thirst 8 h, 4 units a meal or drink). They give nothing yet, and have no sound of their own yet.
  Spawned with the console (`spawn pig`).
- **Feeding trough:** the trough with `stock_kind` feed, made as the trough (woodworking 10), drawn
  with a mash of feed at four fills (atlas row 54). Turnips (8), acorns and beech mast (4 each) join
  hay in `[yard] feed_items`, into a feeding trough or a hay rack alike.
- **Pig pen:** not a building but pieces the player makes at the workbench and puts down one by one:
  the pen fence (split oak rails; a log makes two, level 10), the pen gate (3 planks and a log, level
  10) and the pig shelter (a reed-thatched lean-to, 2x1; 6 planks, 2 logs, 6 reeds, level 15),
  atlas rows 55 to 58 (`tools/art/pen.py`, `classic/pen.py`). The fence and the gate join as a line.
  The player walks through the gate shut or open; the farm animals only through an open one
  (`stops_animals`, `GameMap.is_walkable_for_animals`, which Livestock now uses for its steps,
  searches, catch-up and coops; one put under an animal does not trap it), so a pen with its gate
  shut keeps its animals in with the reachability and needs code of task 122 unchanged; the wild
  animals take no notice of it. The use key with an empty hand opens and shuts the gate (it turns
  into the other type, `turns_into`), with the knock of wood put down until it has a sound of its
  own (a job for the sound designer): no save version bump, nothing new is saved.
- `--yard` shows a pig pen with a pig of each look below the farm yard; README pictures
  docs/screenshots/pig-pen.png (both arts) and livestock.png re-taken with pigs. Tests:
  tests/test_pigs.gd, test_livestock_stopped.gd (with a test-only stile), test_pig_pen.gd,
  test_pig_pen_building.gd, and additions to test_yard_stock, test_save_livestock,
  test_chicken_coop and test_woodworking.
Left open: the pigs do not go into their shelter (they sleep where they are); a pen is not a thing
of its own (no owner, no count of its pigs); a ridden horse goes through a shut gate; rooting does
not wear the ground.

## 167. Watered soil fades out at its edge to dry soil

- [x] Done

The user, 2026-11-10: "watered tiles have sharp edges towards other tilled tiles. the watering
needs some fading out unless the neighbouring tile is also watered". Today SoilWetness
(game/scenes/soil_wetness.gd, atlas from tools/art/soil_beds.py) lays a darker brown over each
moister tile on the plain tile grid, cut only by the bed's outline, so a wet tile beside a
drier tilled tile meets it in a hard straight line.
- Where a tile is wetter than its tilled neighbour, its darker brown fades out over a few pixels
  towards that side (a dithered or stepped edge in palette browns, in the style of
  docs/art-style.md); where the neighbour is as wet, there is no edge, as today. Corners too.
  The bed's outer rim stays as it is.
- Both arts (32 px and classic). The atlas will need the neighbours' wetness, not only which
  tiles are tilled: keep its size sensible (e.g. a fade overlay per side and corner drawn on top
  of the step, instead of every combination).
- Performance: redrawing after an hour stays within REFRESH_BUDGET_USEC.
- Tests for which edges fade; before/after crops at 1x and 4x and a README picture.

Done 2026-11-11: a wetter tile's brown runs on into its drier tilled neighbour and fades out there
(6 px at 32 px, 4 px in the classic art, a 4x4 ordered dither through the steps in between), from
a fade atlas assets/soil_fade.png (40 columns: 4 sides x 9 end cuts and 4 corners; 6 step-pair
rows) on 8 TileMapLayers of SoilWetness; equal wetness and snow give no edge. The hourly refresh
does about 5x the work of before, spread over frames within REFRESH_BUDGET_USEC.

## 172. Inside a house the weather is faint, and the hearth crackles

- [x] Done

The user, 2026-11-10: "inside the house the weather sounds should be muffled and very faint. In
a house with a hearth we should rather hear fire crackling as the main thing. Later, once
implemented, the ambient music." Run after task 167, before the gossip tasks.
- Today AudioService muffles the world outside indoors with a low-pass that fades in
  (`Muffle`, game/scenes/audio_service.gd; design/presentation/sound.md): the weather is duller
  but still about as loud. Indoors it should be much quieter as well (rain on the roof and wind
  only faintly), the numbers in data/ (e.g. sounds.cfg or a [muffle] section), fading as now.
- A building with a burning hearth or fireplace (HEARTH, FIREPLACE in world_object_types.gd;
  check how a fire is lit or burns, and whether the oven counts) plays a fire-crackle loop as
  the main indoor sound: positional or by distance to the fire in the room, made by the sound
  generator (tools/audio, a new `*_loop` event, a sound-designer job) in the style of the other
  sounds; silent when the fire is out.
- Later, with tasks 170 and 171: the music indoors (the indoor piece or a quieter mix) — note it
  in task 171, not done here.
- Tests for the indoor volume, the crackle following the fire's state and the player's
  building; listening files for the user (the crackle, and rain heard from inside).

Done 2026-11-11: indoors the Ambience and OutsideEffects buses fade to -24 dB on top of the 700 Hz
low-pass (data/ambience.cfg [indoors] outside_db). A hearth or fireplace (AmbientMotion.has_flames;
the oven has no flames and stays silent) plays a positional fire_crackle_loop on the Effects bus,
on top of the ambience; its reach goes by the room's size (a room of up to 100 tiles: 9 tiles, so
the whole kate hears it; a bigger one: 4 tiles, so the longhouse is silent at the door). The user,
the same day: no noise bed, only crackling; the pops were drum-like (a hollow knock, removed, now
dry bright snaps); the walk renders' seams were a render artifact; "crackling sounds are good".
Fires have no lit or out state yet, so a room with a hearth always crackles.

## 173. Petting animals: a heart once a day, and a friendship value

- [x] Done

The user, 2026-11-11: "you can pet animals. They'll show a small heart above their head. it
increases an internal friendship value by 10 which can increase to 100. you can pet animals as
often as you want but only once a day you'll see the heart and it will increase that value. The
value decreases by 5 a day if not petted. When you pet animals while they are sleeping the
counter decreases by 5 and you see a little swirl above their head. We'll use that value later
for game mechanics." Run after task 172, before the gossip tasks.
- Petting: the use key with an empty hand on an animal (it must not clash with feeding, the gate
  or riding). Each animal keeps a friendship value, 0 to 100. The user, 2026-11-11: the value
  can never go lower than 0 (no loss, sleeping or daily, takes it below 0).
- Awake: the first petting of the day adds 10 (capped at 100) and shows a small heart above the
  animal's head; more pettings that day do nothing and show nothing.
- Asleep: petting takes 5 (floored at 0) and shows a small swirl above its head. Confirmed by
  the user, 2026-11-11: the swirl and the loss come once a day too, and a sleeping petting
  doesn't count as the day's petting.
- A day without a petting takes 5 (at the day change, caught up over skipped time in the frame
  budget of task 158).
- Confirmed by the user, 2026-11-11: the farm animals and the pets (cows, horses, sheep, pigs,
  hens, dogs, cats), not wildlife; a new animal starts at 0. The numbers in data/livestock.cfg.
- The user, 2026-11-11: the tame rabbits can be petted too. Wild animals get the same
  friendship value but can't be petted (it stays at 0 for now); a later feature may let the player
  tame wild animals. Birds are left out. A wild animal is only tracked and saved once its value
  is above 0 (later: the player tried to tame it); all the others are not saved.
  Decided 2026-11-11 after a second opinion: for now only the attribute (a friendship value fixed
  at 0 on wild rabbits, squirrels, deer, mice and frogs, not pettable, not saved); the sparse saved
  store comes with taming (see Later).
- Saved with the animal (a save version bump, following the upgrade-window rule); the heart and
  the swirl drawn in both arts (pixel-artist job), a short sound for the petting maybe reused.
- Nothing uses the value yet; it is for later game mechanics. A console command to show an
  animal's value helps testing.
- Tests: the daily cap, +10 and the 100 cap, the sleeping loss, the daily loss and its catch-up,
  save and load; a README note.

Done 2026-11-11: petting with the use key and an empty hand, last of the empty-hand uses (cow,
horse, sheep, pig, hen, dog, cat and the tame rabbit; not a hen in its coop or a ridden horse).
Awake, the first petting of a day adds 10 (to 100) with a heart; asleep, at most once a day, it
takes 5 (to 0) with a black anime anger mark (the user's swirl replaced, drawn thin); a day without
a petting takes 5, worked out in closed form over skips. The marks stand 2 px above each species'
measured head per pose. Save version 27 (the upgrade from 16 dropped). Wild ground animals (wild
rabbit, squirrel, deer, mouse, frog; WildlifeRules.GROUND_KINDS) carry a friendship value that is 0
and stays 0, not saved; the saved store comes with taming (see Later). Console `friendship [n]`.

## 174. Tilled soil reaches nearer the tile edges, and seeds and plants sit centred

- [x] Done

The user, 2026-11-11, with a screenshot of a 2x2 bed (32 px art): "tilled soil needs to be closer
to the tile edges but not a straight line. The seeds and plants need to sit a bit more centered."
Today the bed's outer rim (tools/art/soil_beds.py, the bed shapes) is drawn well inside the
tiles, so a small bed reads as a rounded blob with a wide border of grass; and the sown seeds sit
low in their tile (near its bottom edge) rather than in the middle of it.
- The bed's outer edge comes close to the tile edges (a pixel or two in, not a wide margin), still
  ragged and organic rather than a straight ruled line; corners stay softly rounded. Both arts;
  the wetness overlay and the fade of task 167 and the weeds of task 166 follow the new shape.
- Seeds, sprouts and crops are drawn centred on their tile (check every crop stage and both arts;
  tall crops may still stand from the tile's lower part if that reads better, say so).
- Before/after crops at 1x and 4x and an in-game shot for the user; README pictures re-taken.

Done 2026-11-11: the soil edge (tools/art/terrain.py and classic, `edge_shapes`/`coverage` with an
inset and a ramp) runs 1 to 4 px inside the tile edge, ragged, and only the corners round off over
about 6 px (3 in classic); the wet overlay, the fade of 167 and the fallow weeds (now placed on the
bed by `soil_beds.spot_on_bed`) follow it. Crop stages that fit their tile are centred on it
(`canvas.centred_on_tile`); tall grown crops still stand from the tile's lower part. README
pictures re-taken.

## 177. Darker nights, and a lantern to carry

- [x] Done

The user, 2026-11-11: "darkness should be much stronger. You'll need to carry a lantern to get a
brighter circle around you to see better (right now via spawn command). it doesn't need fuel right
now, but holding it pressing space will turn it on and off."
- Night: much darker than today's bluish, readable night (DayNightTint.NIGHT, game/scenes/
  day_night_tint.gd, "night stays bluish and readable, not black"). Dusk and dawn ramp into it;
  moonlight may lift it a little if the weather/moon model has it. Light sources (campfires,
  windows, the hearth glow, fireflies) still read as light in the dark. The numbers in data/.
- A lantern item: no recipe yet, got through the console's spawn/give command. Held in the hotbar
  and selected, the use key (space) switches it on and off; lit, it casts a warm circle of light
  around the player (a soft radial light, flickering a little), off, nothing. No fuel for now.
  Its lit state is saved; it shows in the player's hand (lit and unlit) and as an icon, both arts
  (pixel-artist job). Maybe a small sound on switching (reuse one).
- Indoors stays as it is (the fixed warm tint), unless the lantern is easy to make count there too.
- Tests for the night darkness, the switching and the light following the player; screenshots
  for the user at night with and without the lantern, both arts; README note.

Done 2026-11-11: the night tint (DayNightTint, a CanvasModulate; numbers in data/lighting.cfg) is
Color(0.13, 0.16, 0.3), luminance 0.16 (was 0.47); the fires, windows, hearth and fireflies are
additive PointLight2Ds, so they stand out more. The lantern: `give lantern`, space or a click with
it selected switches it, a warm flickering light of 5 tiles on the player while it is held (in the
bag it stays lit but gives no light: the user's call), saved (save version 28, the upgrade from 17
dropped). The user: "lanterns and nights look great". README night pictures re-taken.

## 175. Rain visibly wets the soil, and wet soil is a patch, not a square

- [x] Done

The user, 2026-11-11, with two screenshots in the rain (32 px art): "rain doesn't seem to wet the
soil? and wet soil has a clear border, it should be more like a patch not like a square."
- Rain: find out why a bed stays dry-looking in the rain. Leads: data/crops.cfg `rain_wets` is
  0.1 an hour only for the heaviest rain (lighter rain adds less), the moisture steps of
  SoilWetness (game/scenes/soil_wetness.gd) need a whole step's worth before the brown changes,
  and the view follows the moisture only at its hourly refresh. Rain should darken the soil
  noticeably within the first hour or so of steady rain, and heavy rain soak it; maybe a quick
  surface darkening while it rains. Keep the growth balance of the crops in mind (moisture_min
  and moisture_best) and say what changes there.
- The user, the same day: "actually during rain, the soil even dried out". Likely cause, in
  FarmingUpkeep.moisture_change (game/state/farming_upkeep.gd): every hour takes a 24th of the
  whole day's drying (its sun hours and strongest wind included), and that can outweigh
  `rain_wets * rain` in light or moderate rain, so a rainy hour dries the soil. Also check that
  `rain_in_hour` agrees with the rain shown on screen at the player's place and hour. While it
  rains, the soil must not dry (no sun or wind drying in a wet hour), and it must get wetter.
- Wet patches: a watered tile (or a few) beside drier soil still reads as a square block with a
  clear edge, even with the fade of task 167. Wetness should look like an organic patch: an
  irregular, blotchy outline that wanders across the tile edge (varied per tile, seeded by
  position), not a straight dithered band along the grid. Both arts. Works together with task
  174's new bed edge.
- Tests for the rain wetting and the patch edges; before/after crops and in-game shots in the
  rain for the user.

Done 2026-11-11: an hour with rain never dries (FarmingUpkeep.moisture_change) and its rain is the
mean of minutes 10, 30 and 50 (it was the hour's start only, so showers were missed); `rain_wets`
0.2; after an hour with rain the surface looks a step darker until a dry hour (SoilWetness,
GameState.last_hour_rain). Wet soil is a patch: the edge between wetter and drier soil wanders up
to 9 px (4 classic) across the tile line, on a 4-tile wavy line per grid line, with rounded corners
and filled hollows (assets/soil_edge.png, 24 TileMapLayers); the 167 fade is gone. The user: "wet
patches look good for now", to be tried in the game.

## 192. Smarter test runs: only the tests a change touches, and a full run now and then

- [x] Done

The user, 2026-11-11, after the merge check moved to testing the branch tip only: "Can we run
tests in a smarter way? some tests might not have to run all the time, resp tests probably have to
run only for specific parts that they touch. If assets change we might want to only run the asset
tests. every now and then we run a global test and if that one would fail we bisect test again."
And: "make sure that the whole branch is considered not only a commit: if we merge a new feature
but the last commit only adds docs, we still want to run tests for all touched code paths."
- A selector (e.g. tools/select_tests.py) and `make test-changed BASE=<ref>` that looks at every
  file changed between BASE (main) and HEAD, the whole range, never just the last commit:
  - docs only (README, docs/, design/, TASKS.md, *.md): no tests;
  - tools/: the Python tool tests (and the art check `make art` when a generator or art/generated
    changes);
  - art/generated, assets, data/*.cfg: the asset and data tests and the GUT tests that read them;
  - game/ and tests/: the GUT tests that reach a changed script through class_name references,
    preload/load paths and scenes, followed transitively; a changed test file runs itself.
  - Anything it can't place (project.godot, addons/, the Makefile, run_tests.py, an unresolvable
    reference) runs everything. When in doubt, run more.
- tools/run_tests.py takes a list of test files (sharded as today by build/test-times).
- A periodic full run on main (e.g. `make test` after every 5 merges or at the end of a batch, the
  coordinator's job): if it fails, bisect over the merges since the last green full run.
- Workers use `make test-changed` while developing and one full `make test` before reporting.
- Tests for the selector (docs-only, tools-only, a data file, a game script reaching its tests, an
  unknown path running all, a docs-only tip of a branch that changed code still selecting that
  code's tests); README/docs: how to run it.
- Measure: how many tests and how long for a few recent branches (e.g. 174, 175, 177) against the
  full run.

Done 2026-11-11: `make test-changed BASE=main` (tools/select_tests.py) selects by the whole range
merge-base..HEAD plus uncommitted and untracked files: docs run nothing; tools/ runs the tool tests
and the GUT tests that name the tool's res:// path; generator folders (any file but test_*.py) add
`make art`; data, maps and art go through their readers (maps and resources through data files,
packed art through its atlas); game/ and tests/ follow class names, res:// literals (prefix and %),
relative extends/preload, scenes, resources and shader includes transitively; a lost class_name,
a deleted script and any unknown path run everything, keeping the art check. tools/run_tests.py
takes a file list. Reviewed twice by Sol (six false-negative paths found and fixed). Measured:
task 174's range selects 41 of 261 files, 175 and 177 almost all (the game code is coupled).

## 193. Console: `killall <kind>` removes everything of a kind

- [x] Done

The user, 2026-11-11: "we need a way to easily remove things. add a /killall which then takes the
list of the spawn command and removes all of that type from game and savegame."
- `killall <kind>` takes the same kinds as `spawn <kind>` (game/state/console.gd: the farm animals
  and pets, the wild animals spawn knows, `npc` with a villager id, the wild rabbit's own name)
  with the same completion and the same "unknown kind lists the kinds" answer, and removes every
  one of that kind: from the running game (views freed, followers, hunts, coop roosts, pen and
  trough reservations released) and from the state that is saved, so the next save no longer has
  them. It says how many it removed.
- Villagers: `killall npc <id>` removes that named villager (data/villagers.cfg); `killall npc`
  alone removes every villager without an id (made up from the tables or by `spawn npc`) and keeps
  the named ones, which need their id (the user, 2026-11-11, replacing "asks for an id"). Removing a villager the story or a building depends on
  must not break the save or the game (check homes, work places, gossip, chat history).
- Wild animals are not saved (task 173), so for them it clears the ones alive now (they may come
  back by the spawn rules); say so in the answer.
- A ridden horse: unmount first, or refuse; say which.
- Tests for each kind group (a farm animal, a pet, a wild animal, a villager), the count, the save
  after removal, and unknown kinds; design/presentation/console.md line.

Done 2026-11-11: `killall <kind>` shares spawn's kinds and completion (KIND_COMMANDS) and removes
every one of the kind from the game and the save (Livestock.remove_species, Npcs.remove,
WildlifeView.remove_kind; views freed by `removed` signals), answering with the count; wild animals
are cleared for now and may come back. `killall npc <id>` removes a named villager; a bare
`killall npc` removes the villagers without an id and keeps the named ones. Riding a horse:
`killall horse` refuses ("get off first").

## 189. Windows can be dragged

- [x] Done

The user, 2026-11-11 (next in the queue, after 177 and 175): "make our Modal UI movable. since
all dialogs use it already it should then replicate for all windows. add a flag to enable or
disable that, have the esc and options menus disable it so that those have their fixed positions.
Movable modals don't save their position."
- In Modal (game/scenes/modal.gd), which every window and dialog uses: the player drags a window
  by its title bar (or its frame, if there is no title bar; not by its content, so buttons, lists,
  sliders and drag-and-drop of items keep working), with the mouse; it stays within the screen.
- A flag on Modal (e.g. `is_movable`, on by default) turns it off; the Escape (pause) menu and the
  options/settings menu set it off and keep their fixed places. Check every window that uses Modal
  and list which stay fixed. The user, the same day: confirmation dialogs stay fixed too.
- Positions are not saved: a window opens where it opens today every time (also after a resize
  of the game window).
- Tests for dragging, the flag, the screen bounds and not saving; README line.

Done: 2026-11-11. Modal windows are dragged by their frame or by any spot that takes no clicks; `is_movable` (on by default) is off for PauseMenu with its settings pages and for ChoiceDialog (every yes/no question). Kept on screen on drag and resize, reset to the middle on open, never saved. ChatScreen's `_input` LineEdit became `_line_edit`. Tests in tests/test_modal_dragging.gd.

## 178. Harvests vary a little, and now and then give a seed

- [x] Done

The user, 2026-11-11: "harvesting gives different amounts of produce with a slight variance, for
instance 2-3 carrots with an average of 2. seeds happen occasionally, both configurable in the
config."
- Today each crop's `yield` in data/crops.cfg is a fixed count, and a harvest gives one seed back
  every time ("How many produce items one harvest gives (and one seed back)").
- Per crop in data/crops.cfg: the yield becomes a small range around an average (e.g. carrots 2
  to 3, averaging 2; an average and a spread, or min, max and average; pick the clearest config
  shape and say why), drawn per harvest; and a seed chance per crop (the seed back is occasional,
  not every time). Keep the farm's economy in mind: say what the seed chance means for keeping a
  crop going, and pick sensible defaults per crop for the user to confirm.
- A crop's damage or quality, if it changes the yield today, keeps working with the range.
- Deterministic in tests (a seeded or injected random source). Tests for the range, the average
  over many harvests, the seed chance, and the config check; README and design/farming notes.

Done: 2026-11-11. data/crops.cfg gives each crop `yield_min`, `yield_max`, `yield_average` and `seed_chance` (replacing `yield`); a harvest draws a whole number in the range whose long-run mean is the average, and a seed only by chance. The dice are `GameState.harvest_rng` (not saved), injected in tests. Defaults: grains and pumpkin 0.7 seed chance, roots and flax 0.5 to 0.6, regrowing crops 0.2; carrots 2 to 3 averaging 2.3. Values open to the user's tuning.

## 179. Picked-up items go into the hotbar first, then the backpack

- [x] Done

The user, 2026-11-11: "picked up items should first be placed in the quick bar, if that one is
full in the inventory."
- Check what happens today: Inventory.add (game/state/item_slots.gd) puts items onto existing
  stacks with room first (anywhere, the backpack too), then into free slots in
  `_free_slot_order`, which lists the hotbar first but moves the selected slot to the very end;
  ground pickups, harvests, foraging and other gains may go through other paths. Find where the
  user's case differs (e.g. a stack in the backpack taking the item before a free hotbar slot, or
  the selected slot being skipped) and decide with the rule: hotbar first (stacks there, then free
  hotbar slots), then the backpack. Whether the held (selected) slot should take new items or stay
  last, and whether a matching stack in the backpack should beat a free hotbar slot: pick a
  default, explain, and the user confirms.
- Same rule for every way the player gains items (pickups, harvest, forage, eggs, crafting
  output if it goes to the inventory).
- Tests for the order; README line.

Done: 2026-11-11. Before, a matching stack anywhere (the backpack too) took an item before a free hotbar slot. `Inventory._add` now fills: hotbar stacks, free hotbar slots but the selected one, backpack stacks, free backpack slots, and the empty selected slot last (an empty hand stays empty; the user to confirm). Every gain path goes through it; chest takes, drag and shift-click keep their explicit order. `can_exchange` tries the same order (`_new_trial()`).

## 180. Ringing the bell in the bell frame

- [x] Done

The user, 2026-11-11: "clicking / e on the belltower while being close (1 tile) should ring the
bell." The bell frame (the church's free-standing wooden bell tower, task 102; building_types.gd,
data/buildings.cfg, design/building/first-buildings.md) has no inside and no use today.
- Within 1 tile of the bell frame, a click on it or the interact key (E) rings the bell: a bell
  sound (none exists yet: a bronze church bell strike with a long decay, made by the sound
  generator in tools/audio in the style of the other sounds, a sound-designer job), heard far
  (positional, with a long reach outdoors and faint indoors as the other outside sounds), and the
  bell swinging in the frame for a moment if the art allows it (both arts).
- Ringing again while it still sounds: decide (restart, overlap, or wait for the swing), and say
  why. No game effect yet (later: calling the villagers, gossip, events).
- Tests for the reach, the input and the sound; a listening file for the user; README line.

Done: 2026-11-11. E or a click within 1 tile of the bell frame rings it (E leaves it to a bed in reach; food in hand eats on a click). A new generated bronze bell strike (tools/audio/bell.py, 2 variants, about 11 s), positional with `reach_tiles=120`, faint indoors on the OutsideEffects bus; a new ring overlaps the old, at most 3 bell voices (`voices` in data/sounds.cfg). The bell is its own sprite and swings as a damped pendulum, in both arts. The user approved the sound and the art.

## 197. Harvests: the usual amount, now and then one more or one less

- [x] Done

The user, 2026-11-11, on task 178 (merged with a range and an average, e.g. carrots 2 to 3
averaging 2.3): "what I meant is carrots give mostly 2, rarely only 1 or 3. Same should be the case
for most crops. Normally they get a median amount, sometimes there's a good or a bad harvest of one
plant"
- Replace `yield_min`, `yield_max` and `yield_average` in data/crops.cfg with the usual count per
  crop (`yield`) and the chances of a bad and a good harvest of that plant (one less, one more),
  e.g. `poor_harvest_chance` and `good_harvest_chance`; a defaults section or a shared default so
  most crops just use it (start with about 0.15 each, so 70 % of plants give the usual amount).
  Never below 1: a crop whose usual count is 1 (pumpkin) can only have a good harvest.
- Usual counts: today's averages rounded (turnip, cabbage and others: pick and list them); carrots
  2. Keep `seed_chance` as it is.
- Keep `CropLife.harvest_of(crop, rng)` and `GameState.harvest_rng`; CropRules checks the new keys
  (chances 0 to 1, together at most 1, usual count at least 1).
- Tests: the usual count is the most common, one less and one more occur at about their chances,
  never 0, the config check. README, design/farming/crops.md, the crops.cfg header.

Done: 2026-11-11. Each crop has `yield`, its usual count (cabbage and pumpkin 1; turnip, carrot, onion, buckwheat, peas, beans, strawberries 2; potato, wheat, rye, flax 3); `[farming]` holds `poor_harvest_chance` and `good_harvest_chance` (0.15 each), which a crop may override. One roll gives one less or one more, never below 1. The range keys of task 178 are gone; `seed_chance` stays.

## 198. Crafting with a full inventory drops the result on the ground

- [x] Done

The user, 2026-11-11: "Crafting with full inventory: items will get dropped on the ground"
- Today a craft whose result doesn't fit is refused (Crafting.Result.NO_ROOM, the "Inventory full"
  note in CraftingScreen; game/state/crafting.gd says "nothing is dropped on the ground"), and
  `take_out` leaves done work in the kiln when it doesn't fit.
- Instead: the craft goes ahead. The materials are taken, the result goes into the inventory in the
  usual order (task 179), and what doesn't fit is dropped on the ground at the player's feet, as
  other drops are (World.drop_items / GroundItems.drop). The same for taking done work out of a
  station: what doesn't fit lands at the station, by the player. A short note says it was dropped.
  Works indoors too, wherever ground items can lie; if a map can't hold them, say so and keep the
  refusal there.
- NO_ROOM and its note go if nothing else uses them; update the class comment, the README and
  design pages on crafting.
- Tests: a craft with a full inventory drops the result and takes the materials; a part that fits
  goes in and the rest drops; the materials freeing a slot is used first; taking out from a station
  with a full inventory drops.

Done: 2026-11-11. Outdoors a craft that does not fit goes ahead: the materials are taken first, what fits goes in (hotbar first) and the rest drops at the player's feet (`Result.DROPPED`, "Inventory full: the rest was dropped on the ground"). Taking done work out of a station drops what does not fit by the station, on the player's side (`take_out` returns a Result). Indoors nothing can lie on the floor, so the refusal (NO_ROOM, "Inventory full, and nothing can be dropped indoors") stays there.

## 181. Villagers never stand in a doorway

- [x] Done

The user, 2026-11-11, with a screenshot of a villager drawn standing in the door of a thatched
house (in the door's frame, the wall around them): "this should not be possible, a villager
standing on top of a door. they should always be in front or eventually (task for later) be inside
the house."
- Find why a villager ends up on a building's door tile (or another tile of the building): their
  walk target or schedule spot (home, work, the door as a destination), pathing that treats the
  door tile as walkable for them (the player walks through doors into interiors), spawning or
  catch-up placing them there, or the draw order making a villager in front of the door look as if
  they stand in it.
- Villagers stop on the tile in front of the door (outside the building's footprint) and are drawn
  in front of the wall; any villager found on a building tile (old saves, catch-up) is moved to
  the nearest free tile in front. Same for the animals if they can end up there.
- Tests: a villager going home or to work ends in front of the door, never on a building tile,
  over play and over a skip; README not needed unless something visible changes.
- Later (a separate task, see Later): villagers go inside their houses.

Done: 2026-11-11. The cause was placement: a door tile is walkable (the player walks in), and villagers used the player's `can_stand_at` for spawn, strolls and catch-up. `Npcs.can_stand_at` now excludes every building tile, and a villager found on one is moved to the nearest free tile (normally in front of the door). Farm animals and pets: `World.is_walkable_for_animals` excludes building tiles, and a skip moves an animal off. Not covered: wild animals (WildlifeView uses `world.is_walkable`), which can still stand on a door.

## 200. Items can lie on the floor indoors

- [x] Done

The user, 2026-11-11: "Dropping items inside should work"
- Today ground items live only in `world.ground_items`: interiors (game/state/interior.gd) have
  none, so `GameState.drop_from_inventory` refuses indoors (`is_inside()`), and task 198 kept a
  full-inventory craft indoors refused ("Inventory full, and nothing can be dropped indoors").
- Give interiors their own ground items (the same GroundItems, per map, saved with the interior;
  save version bump with its upgrade, per the save rules): dropping (the drop key and dragging a
  stack out of a window onto the floor) works inside, piles show on the floor in both arts, the
  player picks them up as outside, and they stay when the player leaves and comes back.
- Then the indoor case of task 198: a craft that doesn't fit drops the rest at the player's feet
  indoors too; the NO_ROOM refusal and its indoor note go if nothing else needs them.
- Anything outdoor-only about ground items (wind, rot, animals eating, rain, the item settle and
  auto pickup) is checked and either works indoors or is left out on purpose; say which.
- Floor tiles only: never on walls or furniture that blocks; scatter stays inside the room.
- Tests: drop and pick up inside, saved and loaded, leaving and coming back, a full-inventory craft
  indoors drops, the drop tiles stay on the floor. README, design pages, docs.

Done: 2026-11-11. Ground items belong to each map (GameMap): interiors keep their own piles, saved with them (save version 29; the upgrade from 18 dropped). Dropping, dragging a stack out of a window, pickup, settle and pull work inside; piles lie only on free floor (never walls, blocking furniture or the doormat; a crowded room uses its nearest free floor) and show in both arts. A craft or take-out that does not fit drops the rest indoors too; Crafting.Result.NO_ROOM is gone. No wind, rot, animal or rain behaviour exists for piles anywhere. A `--floor-items` screenshot option.

## 182. Leaves fall and blow in autumn wind

- [x] Done

The user, 2026-11-11: "in autumn, there should be falling leaves when windy. we should have the
animation from lumbering, we could use that for blowing some leaves around? Some just falling,
some carried off by the wind."
- Reuse the falling-leaf particles of tree felling (game/scenes/hit_particles.gd,
  HitEffect.Kind.LEAVES_AUTUMN and LEAVES_GREEN: palette leaves with a sway as they fall).
- In autumn (and a little in late summer and early winter, by how much foliage the trees still
  carry in the season looks), deciduous trees near the player shed leaves now and then: more in
  stronger wind and in gusts (task 176's gusts when they exist, the sway shader's fronts), none in
  calm. Some drop and sway down beside the tree; in wind, some are carried off downwind, drifting
  and tumbling for a while before they land or leave the view. Conifers shed none (or a rare
  needle). Leaf colours follow the tree's season look.
- Cheap: a cap on the leaves alive at once, spawned only for trees on screen near the player,
  nothing per tile per frame; nothing saved. Numbers in data/ (a new section or ambience.cfg).
- Off indoors. Both arts.
- Tests for the rate by season and wind, the cap, and the drift direction; a short clip or a few
  frames for the user.

Done: 2026-11-11. In wind above 3 m/s, deciduous trees near the player shed leaves by their season look (autumn colours fully, green trees a little from summer day 20, conifers a rare needle, none under snow), more in stronger wind and the shader's gust fronts (`AmbientMotion.gust_front` copies sway.gdshaderinc). Some drop beside the tree, some drift downwind up to about 10 tiles. At most 24 alive; random tile picks near the player; nothing saved; off indoors. Numbers in data/leaf_fall.cfg. The user merged it to try in game (the leaves are small, 3 to 5 px).

## 183. Flocks of birds migrate: south in autumn, north in spring, gone in winter

- [x] Done

The user, 2026-11-11: "flocks of birds in autumn should move from north to south only, migrating.
in spring the other way round, in winter they should not be there at all. in summer they just roam
around however they like."
- The sky flock (data/wildlife.cfg [flock], game/scenes/wildlife/flock.gd) crosses the sky now and
  then; its `season_factors` are [1.0, 1.0, 0.8, 0.3] (winter still 0.3) and its heading is not
  tied to the season.
- Autumn: flocks fly north to south only (a heading within a small spread around due south, maybe
  in V or skein shape if the art has it), a bit more often in the migration weeks. Spring: south
  to north. Winter: no sky flocks at all (season factor 0). Summer: as today, any heading,
  wandering. Check the season boundaries the game uses (and whether early/late season shares
  exist) so the change is smooth.
- Only the sky flock; the greylag geese and dunlin on the ground keep their own rules (say if
  they should follow too).
- Numbers in data/wildlife.cfg. Tests for the heading by season and none in winter.

Done: 2026-11-11. The sky flock (its V) flies south within 25 degrees in autumn and north in spring, any way in summer, and not at all in winter (`season_factors` [1, 1, 1, 0]); twice as often in the middle 14 days of autumn and spring; a 6-day fade at the season edges. Keys `migration_spread_degrees`, `migration_days`, `migration_boost`, `fade_days` in [flock] of data/wildlife.cfg. The greylag geese and dunlin keep their own rules. Later the same day the user asked for the geese to migrate too: the skein of flying geese got the same keys (south in autumn, north in spring, any way in winter, none in summer as before).

## 205. The console log scrolls

- [x] Done

The user, 2026-11-11: "The console needs scrolling. Use shared code for it. Start this now"
- Today the console (game/scenes/console_view.gd) shows only the last `VISIBLE_LOG_LINES` lines
  of `_log_lines` in a clipped Label; older lines (long `help` output, spawn lists, the track
  list of task 184) can't be seen.
- Make the log scroll with the shared scrolling code (ScrollingList, game/scenes/scrolling_list.gd,
  as the panels use it; extend it rather than writing a second scroller, if the console's case
  needs something it lacks): the mouse wheel and the scroll bar, and Page Up / Page Down (or
  Shift+Up/Down if those are free; keep Up/Down for the input history) while the input line has
  focus. A new line scrolls to the bottom unless the player has scrolled up to read (then it
  stays, as chat windows do); opening the console shows the bottom. The visible height stays
  `VISIBLE_LOG_LINES`. Keep a cap on the kept lines (e.g. 500) so the log can't grow forever.
- The log text stays selectable or not as today; the console stays on top and keeps its focus
  rules.
- Tests: long output can be scrolled to its first line, a new line keeps the view at the bottom,
  scrolled up it stays, the cap. README or docs/ui.md line.

Done: 2026-11-11. The console log sits in a ScrollingList (new opt-in `fixed_height`, `keeps_bottom`, `scroll_pages`, `scroll_to_bottom`): the wheel, the bar and Page Up/Down scroll it, a new line keeps the view at the bottom unless the player scrolled up, opening shows the bottom, the visible height is the old 8 lines, and the log keeps at most 500 lines.

## 184. Console: /play and /stop the music, and a music volume in the audio settings

- [x] Done

The user, 2026-11-11: "add a command /play <trackname> to play the background music. add /stop to
stop it. add settings in the audio settings about volume."
- A first, small way to hear the music in the game before the music director (tasks 170 and 171):
  the console's `play <track>` renders a piece (art/generated/music/*.mod: today sketch_tide,
  sketch_harbour, test_reel; the names without the prefix may do) with the ModuleRenderer on the
  worker thread pool (game/audio/, task 169) and loops it; `stop` fades it out. An unknown name
  lists the tracks. Playing another track while one plays crossfades or stops the old one
  (MusicCrossfade exists: use it if simple).
- A "music" audio bus and a Music volume slider in the audio settings (game/scenes/audio_page.gd),
  saved with the other settings, with mute at 0; test runs stay muted. This takes over task 171's
  "a music bus with its own slider in Settings" (note it there).
- No automatic music yet: nothing plays unless the console says so.
- Tests for the commands (known, unknown, stop), the bus and the slider's setting; README and
  design/presentation/console.md lines.

Done: 2026-11-11. The console `play <track>` (names with or without their prefix; Tab completes) renders the module on the worker thread pool and loops it on a new Music bus, `stop` fades it out over 2 s, another `play` crossfades on the beat over 4 s, a repeated `play` of the same track starts nothing new; an unknown name lists the tracks. A Music volume slider in the audio settings (0 mutes). Console reaches the MusicPlayer only through injected Callables (layering), and says "No music here" when unwired. Nothing plays on its own.

## 186. Footsteps are silent on snow

- [x] Done

The user, 2026-11-11: "there is no sound walking on snow". SoundEvents.footstep returns
`step_snow` when `is_snowed`, the step_snow files exist and are as loud as the others, and
data/sounds.cfg has the event; so find where it goes wrong: what passes `is_snowed` (SnowCover's
cover at the tile, maybe only partly snowed tiles or the dusting look), whether a snowed tile
makes no step event at all (e.g. the walk sound keyed on the terrain or a look that has no
entry), or the playback. Fix it; a test with a snowed tile giving the snow step in play, not only
the pure function. Coordinate with task 185 (snow as an overlay): the step should follow the snow
cover there too.

Done: 2026-11-11. Full snow already gave the snow step; the silence was light snow, where a spot drawn snowy (the dual-grid blend of 4 corner tiles) still counted as grass by its own tile. `WorldView.is_snow_drawn_at(position)` now decides the step from the cell drawn under the feet: snow or dusting on at least 2 of its 4 corners gives `step_snow`. Frost stays a grass step; riding has none. Task 185's GroundCover replaces it later. An end-to-end test with a real WorldView.

## 188. The energy and health bars move to the top right

- [x] Done

The user, 2026-11-11 (to run before task 187): "Move energy and health indicator to the top right
of the screen. add a bag icon right next to the quick bar, a bit separated. this icon when clicked
or b is pressed should open the bag which is the inventory (the build menu now only opens when the
hammer is in hand). The bag opens a bit on the right of the screen, the character part (and later
the character attributes) get their own window that opens on C." Split into 188, 190 and 191 at
the user's word the same day (they don't depend on each other).
- The energy and health bars move to the top right corner of the screen (mind the notifications
  and the clock that may sit there; say where those go). Both window sizes the game supports.
- Tests for the placement if the HUD has them; a screenshot for the user; README picture if it
  shows the HUD.

Done: 2026-11-11. VitalsHud is anchored to the top right (4 px in, growing leftwards); `BOTTOM` follows `BAR_COUNT`, and the F3 coordinates readout starts under the bars. The clock and notifications stay top left. Only docs/screenshots/build.png was re-taken; about 30 hand-made README composites still show the bars beside the hotbar (no recipe exists for them).

## 206. Tool designs: rusty iron tools redrawn from scratch, and four better grades (design only)

- [x] Done

The user, 2026-11-11: "We need better tools. Redesign the tools to be rusty ones, let the agent
design them from scratch. The current ones still look distorted. Then design 4 more quality
levels. The current ones will be 'rusty iron <tool>', then we'll have 'iron', 'brittle steel',
'steel' and 'sharp steel'. Only do the designs and give them to me for approval. Make sure the
tools don't look distorted or in any other way deformed." Run by a worker on Fable with the
pixel-artist instructions (.claude/agents/pixel-artist.md), at the user's request.
- The tools: hoe, axe, pickaxe, watering can, scythe, shovel, hammer (game/state/item_types.gd;
  check for others). Today's art comes from the generator (tools/art: items.py and the held-tool
  code) and looks distorted.
- Design every tool from scratch, not by patching the old drawing: clean, straight, true shapes,
  no warping, skew, broken lines or squashed parts; each sprite in every view it has today (the
  inventory icon and the held/in-hand frames, in both art sets, 32 px new and 16 px classic).
- Five grades of each tool, told apart at a glance by the metal (and the handle where it helps),
  same silhouette per tool: rusty iron (today's tools: rust-brown, pitted, dull), iron (plain grey
  iron), brittle steel (lighter, cold bluish, a hint of a crack or a rough edge), steel (bright,
  clean), sharp steel (bright with a keen highlight on the edge). Wooden handles may age too.
- Design only: render contact sheets (all tools by grade, at 1x and an enlarged view, both arts,
  icon and held) into the scratchpad for the user's approval. Changes to the generator code are
  fine on the worker's branch so the sheets come from the generator, but nothing is merged, no
  items or game code are added, and the current art stays until the user approves.
- Task 207 then makes them items.

Done: 2026-11-11, approved by the user on the third try (worker on Fable at the user's request). The old tools looked distorted because handles were rasterised at 51 degrees, heads were curves at odd angles with dome shading, and outline colours changed along the shape. All seven tools are now hand-drawn letter maps with each head square to its handle in the handle's 45-degree view (the can upright, mirrored), in five grades told apart by the metal: rusty iron (rust pits, dull handle), iron, brittle steel (cold blue, a hairline crack), steel, sharp steel (near white, a keen edge); the pick's arms bend gently. The can is of the grade's metal, the spade all iron. The generator code is on branch `tools-206-designs`, not merged: task 207 builds on it. The user chose the Roman numeral to be drawn by the inventory UI.

## 190. A bag button by the hotbar, and B opens the bag

- [x] Done

From the user's words under task 188.
- A bag icon (both arts, pixel-artist job) beside the hotbar, set a little apart from it; clicking
  it or pressing B opens the bag. The bag is today's inventory screen (Tab), placed a bit to the
  right of the screen centre instead of where it is now. Tab no longer opens it: only B (the user,
  2026-11-11); Tab is left free (unbound) for later.
- B is the hammer key today (`select_hammer`, which puts the hammer in hand and opens building).
  The build menu now only opens with the hammer in hand (the hammer selected in the hotbar, then
  the build key/use); B no longer selects the hammer. Update the controls page and the README's
  key list.
- Tests for the keys, the button and the window place; screenshots for the user; README.

Done: 2026-11-11. A bag button (a light leather satchel, one picture for both arts) sits a little apart, right of the hotbar; clicking it or pressing B opens the bag, placed right of the screen centre. Tab is unbound. The hammer has no key of its own: the build menu opens with the hammer selected in the hotbar. Old settings that bound B to another action give B back to the bag (with the usual "bound twice" warning). A hotbar key or the mouse wheel resumes build mode after Escape or a right click.

## 191. The character window on C

- [x] Done

From the user's words under task 188. Before task 187, whose attributes it will show.
- The character part of today's inventory screen (the figure, equipment) moves into its own
  window opened with C; the bag (task 190) keeps the items.
- C is the crafting key today (`crafting`): crafting needs another key or a place in the bag
  window. The user, 2026-11-11: crafting moves to Shift+C for now; a better place is to be found
  later, maybe no hotkey at all but something like Minecraft (crafting at a table or in the
  inventory's own grid).
- Escape closes it as the others; it uses Modal (and is movable once task 189 is in).
- Tests for the key and the window; screenshots for the user; README and controls page.

Done: 2026-11-12. The bag (B, the satchel button) keeps the backpack, the weight, the trash can and dropping on the ground; the new character window (C) has the figure, the equipment slots, a trash can and the skills tab (K). Both are Modals that lend the HUD hotbar as their quick bar (HotbarWindow). Crafting is on Shift+C: settings can now store Shift ("key:67:shift"), but a Controls-page rebind still binds without Shift. Old settings give C to the character window. With one window at a time, equipping is by right click in the bag or a drag from the hotbar in the character window. A TrashCan bug that swallowed the first click is fixed.

## 187. Character attributes: strength, agility, HP and stamina

- [x] Done

Run after task 191 (the character window it shows in).

The user, 2026-11-11: "we want some basic rpg elements, character attributes specifically
Strength, agility, hp, stamina. strength increases carrying capacity, agility i don't know yet, hp
is obvious and stamina increases energy max. build the system so that we can easily expand on it
later."
- Today PlayerState has fixed MAX_ENERGY and MAX_HEALTH constants (game/state/player_state.gd),
  and carrying is the slot count of the hotbar and the backpack (Inventory).
- A small attribute system on the player: Strength, Agility, HP and Stamina, each a level with a
  base value, kept in data/ (e.g. data/attributes.cfg: base levels, what one level gives), saved,
  shown in the inventory/character screen. Built to grow: an attribute is data plus the
  effects it has, read through one place (e.g. `Attributes.value(STRENGTH)` and derived stats
  like `max_energy`, `max_health`, `carry_capacity`), so later attributes, bonuses (food, items,
  levels, skills) and NPC/animal attributes can be added without touching every caller.
- Effects now: Stamina raises the maximum energy; HP is the maximum health; Strength raises the
  carrying capacity: decide what that means with the user before building (more backpack slots,
  bigger stacks, or a weight limit, which doesn't exist yet). Agility: no effect yet (a later
  idea: walking speed, fewer stumbles, faster work), only the value.
- How attributes grow (levels from use, from skill levels, from items) is left open: a console
  command to set them for testing. Keep the game exactly as today at the base values.
- Plan first: a short plan for the user (the data shape, the strength question), then build.
- Save version bump with the upgrade rule; tests for the derived stats, the save and the base
  values matching today; README and design notes (design/player/).

Done: 2026-11-12. data/attributes.cfg with AttributeRules and Attributes (player.attributes): Strength, Agility, Stamina and HP, base level 10 (1 to 100); `value()` adds transient bonuses (`add_bonus`/`remove_bonus`, nothing gives one yet). Stamina sets max energy (+10 a level), HP max health (+10), Strength the carry capacity in kg (+4), the free weight above which tool use costs more energy; pickup is never refused (the user's choice). At base: 100, 100, 40 kg, as before. MAX_ENERGY/MAX_HEALTH are gone; sleep fills are now a share of the bars. The character window lists the levels and the derived numbers; the bag reads "Carrying x / y kg". Agility has no effect yet. Save version 30 (the upgrade from 19 dropped); console `attribute <name> <level>`. Plan: docs/plans/187-attributes.md.

## 194. Cloud shadows drift over the ground

- [x] Done

The user, 2026-11-11: "add clouds to the weather system. cloudy weather shows cloud shadows on the
ground when the sun is out (no actual clouds are drawn). it can be slightly darker when there is a
closed sky with only clouds. the shadows should move corresponding with wind speed. the clouds only
affect the visuals, they have no effect on the plants etc."
- The weather already has `cloud_cover` (0 to 1, game/state/weather.gd; the forced weathers set it).
  Use it for the look only: no change to sunlight hours, crops, drying or anything in the state.
- By day with the sun out and partial cover: soft cloud shadows on the ground (a cheap overlay or
  shader, e.g. a scrolling noise mask darkening the world a little), more and larger shadows with
  more cover, none under a clear sky. They drift downwind at a speed that follows the wind speed and
  direction (the same wind the sway shader and gusts use). Under a closed sky (cover near 1) no
  moving shadows but the whole scene slightly darker (with the day/night tint and the overcast
  logic of task 177 in mind; don't double-darken). Fade with dusk; none at night or indoors.
- Shadows fall on the ground and what stands on it alike (one screen-space or world-space overlay
  under the UI); they move with the world when the camera moves (world-anchored, not stuck to the
  screen). Both arts.
- Cheap: one overlay, no per-tile work; numbers (shadow strength, size, speed per m/s, closed-sky
  darkening) in data/ (lighting.cfg or ambience).
- Tests for no shadows when clear or at night, darkness under a closed sky, drift following the
  wind, no state effect; screenshots and a short clip or frames for the user; README note.

Done: 2026-11-12. One full-viewport overlay (game/scenes/cloud_shadows.gdshader) in WeatherView draws soft noise patches in world pixels; they drift with the same wind as the fog and sway. Strength = strength x daylight x sun out (no rain or snow shown) x open sky; a closed sky (cover 0.75 to 1) fades them out and keeps only task 177's darkening. DayNightTint exposes `daylight` (0 at night and indoors). Numbers in data/lighting.cfg [cloud_shadows]. `cloudy` and `overcast` can be forced (--weather, console). The drift offset grows without bound like the fog's (float precision after many hours; not seen). The closed-sky darkening is still the constant OVERCAST_DARKENING in day_night_tint.gd.

## 196. Windows get a close button, and a click outside closes them

- [x] Done

The user, 2026-11-11: "add a close button to the modal. clicking outside it should have the same
effect as the registered close key"
- Modal (game/scenes/modal.gd) gets a close button (a small X in the panel's top right corner,
  both arts, palette colours, a hover look) on every window. Pressing it does exactly what Escape
  does in that window: it goes through `_takes_escape()`, so where Escape first goes back a page
  (the pause menu's settings pages, the storage screen's and the character screen's own steps, the
  trash-can question) the button does the same. One code path for Escape, the button and the
  outside click.
- A left click on the dimmed area outside the panel does the same as Escape, for every window,
  including the fixed ones (the pause menu and ChoiceDialog, where Escape's answer, such as "no",
  is what the click gives). `closes_on_backdrop_click` and the windows' own `_on_backdrop_input`
  give way to it, or are dropped if nothing else needs them.
- Must not break: letting a dragged stack go on the dimmed area still drops it (`_drop_outside_panel`)
  and doesn't close the window. A window drag (189) whose release ends outside the panel doesn't
  close it. A press that starts inside the panel and ends outside doesn't count as a click outside.
  Clicks on the HUD's hotbar while a window is open keep working.
- The close button takes no part in the window drag (pressing it doesn't start one).
- Tests: the button and the outside click match Escape (closing, going back a page, the dialog's
  answer); a stack dropped outside still drops; a drag ending outside doesn't close. README, docs/ui.md
  and design/presentation/menus-and-hud.md. Screenshots of the button on a few windows, both arts.

Done: 2026-11-12. `Modal.request_close()` is the one path for Escape, the pause key, the close button and a left press on the dimmed area outside the panel; it asks `_takes_escape()` first, so pages go back, ChoiceDialog gives its safe answer and the trash-can question keeps. `closes_on_backdrop_click` is gone. The × (13 px, generated in tools/art/ui.py, one picture for both arts) is a sibling of the panel drawn over its top right corner, so it never starts a drag, and follows the panel. Presses on the HUD hotbar strip (slots, gaps, bag button) don't count as outside (`_keeps_clicks_at`, set by HotbarWindow). Not retaken: npc-chat.png, font-umlauts.png, station-menus.png and skills.png still show windows without the ×.

## 195. Tidal water can't be walked on (bug)

- [x] Done

The user, 2026-11-11 (a screenshot of the player standing far out in high water): "bug: you can
walk on tidal areas while water is there. right now you should not be able to walk on or in the
water, we'll add something later"
- Today the tide is a look only (game/state/tide.gd, game/scenes/mud.gdshader): MUD is walkable at
  any tide. Make it follow the water: a MUD tile under water at the current tide can't be walked
  onto, the same as SEA. Wading or swimming comes later, so keep the rule in one place that a later
  task can change.
- Which tiles are under water must match what the player sees. The shader floods each pixel where a
  relief (two layers of integer-hashed value noise, the dark troughs a bit lower) lies below
  `mix(LOW_WATER, HIGH_WATER, tide)`. Move that relief into state code (a GDScript port that gives
  the same numbers, with a test that pins it against the shader's constants), and call a tile
  flooded when the water covers its centre, or most of it. Pick whichever looks right at the edges,
  and show both in screenshots.
- No one is cut off by the rising water. Someone standing on a tile that floods can still walk off
  it, but can't step from dry ground onto flooded mud. Villagers, farm animals and wild ground
  animals obey the same rule; wading birds may stay. Pathing avoids flooded tiles. A path that was
  open when it started and floods on the way stops at the water's edge.
- Placing, building, dropping items and tilling on flooded mud are refused, as on water.
- Update the comments in tile.gd and tide.gd ("walked on at any tide"), and the design and README.
- Tests: tiles flood and dry with the tide, no stepping onto flooded mud, walking off a tile that
  floods, NPC and animal paths avoid the water. Screenshots at high and low water for the user.

Done: 2026-11-12. The mud shader's relief is ported to `Tide.relief_at` (a test pins the constants against mud.gdshader). A mud tile is flooded when more than half of a 4x4 grid of relief samples lies under the water (the user saw both rules; they differ by a tile or two at the edges); each tile's flood height is cached, so a check is a lookup. `World.is_ground_walkable` is the one place the rule lives. Whoever stands in the water can step off it and wade on over connected flooded mud (`GameMap.is_wadeable`), for now. Villagers, farm animals and wild ground animals obey; the wading birds (oystercatcher, dunlin) skip it and keep their `flooded_tide` 0.6. Piles are refused on flooded mud. The jetty and rowing boat can still be placed on it.

## 176. Wind gusts are heard with the wind you see, and as loud as the wind

- [x] Done

The user, 2026-11-11: "with 5m/s wind speed the sound sometimes has loud gusts of wind while
nothing is moving. feels like the sound is off."
- Today the sound and the picture don't share their gusts. AmbienceSounds (game/scenes/
  ambience_sounds.gd) plays the `wind_gust` sound at random (`gust_chance` per second, scaled by
  the wind loop's level, data/ambience.cfg [loops]) and always at the sound's full volume, while
  the sway shader (game/scenes/sway.gdshaderinc, AmbientMotion.gust_for) shows gusts as fronts
  sweeping downwind every GUST_SPACING px at GUST_SPEED, only above GUSTS_FROM (3 m/s) and faint at
  5 m/s. So at 5 m/s a full-volume gust can sound while the grass barely stirs.
- Tie the gust sound to the visible gusts: compute on the CPU when a gust front passes the player
  (the shader's formula, from the same wind direction and time) and play/swell then, so a gust is
  heard when the grass and trees near the player bend. No gust sound below the speed where gusts
  show.
- Scale the gust sound's volume (and the loop's swell) with the wind strength, so a light breeze
  gives at most a soft rustle and a storm a loud gust.
- Indoors the gusts stay faint, as the rest of the weather (task 172).
- Tests: no gust below the threshold, gust volume grows with wind, the gust timing matches the
  shader's front at the player's place; a listening file at 5, 10 and 15 m/s for the user.

Done: 2026-11-12. AmbienceSounds watches `AmbientMotion.gust_front` at the player (the sway shader's formula, clock and wind) and plays `wind_gust` once each time a front rises past `gust_front_from`; none at or below 3 m/s, where no gusts show. Its level is `gust_soft_level + (1 - soft) * strength` (`AudioService.play` takes a level), and the wind loop swells by `gust_swell * strength`. The random `gust_chance` is gone. Gusts come every 4 s at any speed (the shader's front spacing). Indoors the ambience bus muffles them. Listening files at 5, 10 and 15 m/s were an offline render with the game's timing.

## 199. Process stations: the kiln and the oven get a 3x3 load, an activation button and a progress bar

- [x] Done

The user, 2026-11-11: "The killing [kiln] does the recipes on the side and offers an inventory 3x3
slots. You put in raw material and fuel (wood for now) and after some time you'll get the resulting
material. Only one recipe per craft. Add a little fire button to start the process with a progress
bar above the greyed out inventory. Clicking a recipe adds the required materials from your
inventory." Then: "the oven should work the same. Make that a type of crafting station code that's
reusable. We'll have more use for it in the future." And: "leave out the ash. Only allow to put in
what fits a recipe. If there's too much of a kind leave it in as is. That'll make the code easier
and better reusable. We can later expand on it. Maybe the kiln implementation can turn it to ash,
the cooking station to burnt food. The 'fire button' should just be an activation button where the
implementation can add a symbol. So the cooking station and kiln might add a fire, a saw mill might
add a saw blade, a fish breeding pond might add a fish."

Today:
- The kiln is a crafting station. Picking a recipe takes the materials and starts the firing.
  - Its recipes are bricks, bricks_large and bricks_master in data/recipes.cfg, with `hours=12`
    and logs among the materials.
  - The firing runs in StationWork. Opening the menu when it's done takes the result out.
  - Task 198 drops what doesn't fit by the kiln. This task replaces that path.
- The oven's recipes are made at once, with no time and no fuel: bread, berry_tart and feast_cake.

**One reusable kind of station, a process station** (name it to fit the code). The kiln and the
oven both use it. A later station is a config section plus its recipes, with no new code. Examples
are a forge, a smokehouse, a saw mill and a fish pond.
- A station becomes one by its config in data/stations.cfg:
  - that it is a process station;
  - its grid size (3x3 for both);
  - the icon of its activation button (a fire for the kiln and the oven).
- There is no separate fuel concept. Wood is simply one of a recipe's materials, as the logs are
  in the brick recipes today. A saw mill or a fish pond then needs nothing special.
- **The window:**
  - The station's recipes are listed on the side, with the grid and the activation button
    beside them.
  - The grid is the station's own storage. It is saved with the station, with a save version
    bump and its upgrade per the save rules.
  - The player moves stacks in and out as with a chest: drag and shift-click.
- **Only what fits a recipe goes in, filtered as the grid fills.** The user, 2026-11-11: "once you
  add ingredients, the materials you can add is filtered by the recipes. If you have one that
  needs wood and stone and one that needs coal and stone, you can add stone and still be able to
  put in wood and coal. But if you start with coal, you can only put in [stone]. Grey out items in
  your inventory part that you can't put in. Materials not in a recipe are of course greyed out
  from the beginning. Quantities work similarly: you can only put in as much stone as you have
  either coal or wood. If you put in too much stone for the wood recipe but have enough coal, the
  wood recipe gets greyed out." (Their example says "only wood" after coal; read it as the other
  material of the coal recipe, stone. Say so in the report.)
  - The rule: the grid's contents must always be part of one load of at least one of the
    station's recipes, at some amount that fits the grid (the ratios of its materials kept). A
    recipe still possible is "open"; one the contents rule out is greyed out in the list.
  - An item, or a count of it, that would leave no open recipe is refused: a drag or shift-click
    moves only as many as keep a recipe open (none if no count does).
  - The player's inventory beside the grid greys out the stacks that can't go in now. Items in no
    recipe of the station are greyed out from the start.
  - Taking items back out of the grid opens recipes again.
  - Keep this rule in the shared code as one plain function over the recipes and the contents
    (pure state code, well tested), so the window only asks it.
- **The recipe list:**
  - There is one recipe per kind of result: one "Bricks", not today's three brick recipes.
  - Under each recipe is an amount: a small number field to type in, and +/- buttons.
  - The +/- buttons only go as high as the player's materials allow and as fits the grid. A
    typed number is held to the same limit.
  - A Max button by each recipe sets the amount to the most the player's materials, the grid and
    what is already in the grid allow.
  - A recipe the player can't make even once, or one the grid's contents rule out, is greyed out
    and can't be clicked.
  - Clicking a recipe moves the materials for the chosen amount from the inventory into the grid,
    counting what is already in it.
- **The activation button:**
  - It starts the run when the grid holds at least one recipe's materials, one recipe per run.
    Which recipe the grid matches when it could hold more than one is up to you; say which.
  - The button shows the station's icon.
- **While it runs:**
  - A progress bar shows above the grid, and the grid is greyed out and locked.
  - The time comes from the recipe's `hours`.
  - The station shows its activity in the world, using the existing lit look and light, if any.
  - It goes on with the window closed and with the player away, in game time.
- **When done:**
  - The materials of the amount made are used up, and the result is in the grid.
  - With the filter there are no leftovers (the user, 2026-11-11: "This way we should also never
    have too much of anything in the station"): the grid can only hold parts of one recipe's
    loads, and the activation button runs only when it holds whole loads (n full loads of the open
    recipe, no part load), so a run uses up everything that is in the grid. A part load keeps the
    button greyed out with a short note of what is missing. Nothing turns into ash or anything
    else; leftover handling (ash, burnt food) is not needed and not built.
  - The player takes the results out like from a chest, only as much as fits. The rest stays in
    the station.
  - Nothing new goes in, and nothing new starts, until every produced item is taken out (the user,
    2026-11-11: "You can't start anything new in the crafting station unless the produced items
    are all taken out"): while results are in the grid, the recipe list and the inventory beside
    it are greyed out with a short note, and the grid only lets things out.
- **Skill:**
  - Recipe `level` locks stay, for later recipes that unlock at a skill level, and each run
    practises the recipe's skill.
  - The masonry levels that made bricks_large and bricks_master pay off become a bonus on the one
    Bricks recipe: at a high enough skill a run gives extra bricks besides the ones selected,
    automatically.
  - The old recipes gave one brick per raw brick and saved wood (6 bricks for 2 logs, 12 for 3,
    18 for 3). The new bonus is extra bricks instead, for example a share of the load at level 50
    and a larger one at 70.
  - Pick the rule and the numbers and put them in data/, where the user tunes them; no need to ask.
  - Make the bonus a setting of the shared code, per recipe or per station, so the oven could get
    extra loaves the same way later. The oven gets none for now.
- **The oven:**
  - Its recipes get a baking time and wood among their materials. Pick them (bread about an hour)
    and put the numbers in data/.
  - Their cooking levels stay as recipe locks.
  - It works indoors and outdoors, as it is placed today.
- Other stations (the workbench and the hearth) keep today's instant crafting menu.
- **Tests:**
  - the shared code with a station defined only in test config;
  - the grid saved and loaded;
  - only recipe materials accepted, the filtering as the grid fills (the user's wood/coal/stone
    example as a test, with quantities), recipes greyed out by the contents, inventory items
    greyed out, taking out reopening recipes;
  - the Max button;
  - a recipe click moving materials;
  - the amount limits;
  - the button refused without a full recipe;
  - locked while running;
  - the button greyed out on a part load, a run using up the whole grid, the result after the
    time;
  - taking out only what fits, and nothing going in or starting while results are left;
  - the kiln and the oven.
- **Docs and screenshots:**
  - README, the design pages on crafting, the kiln and the oven, and docs/ui.md.
  - Screenshots of the kiln and the oven windows: empty, loaded, running and done.

Done: 2026-11-12 (worker and reviewer on Opus). Shared code: `ProcessLoad` (the pure load rule over the recipes and the grid), `ProcessStation` (the grid as the object's storage, the run settled lazily on the game clock, results), `ProcessScreen` and `ProcessRecipeRow`; a station is a process station by data/stations.cfg (grid size, button icon). A mixed grid runs the first recipe in recipes.cfg order whose whole loads match. The filter looks at the grid's contents only, not the inventory. The grid is repacked after anything comes out, and a recipe click is refused if the grid has no room, so nothing can be lost. One Bricks recipe (6 raw bricks + 2 logs -> 6 bricks, 12 h) with `bonus=[[50, 0.25], [70, 0.5]]`; a craft practises at the level of the highest bonus step reached, so masonry reaches 100. The oven: a log per load; bread 2 from 4 flour in 1 h, berry tart 2 in 1.5 h, feast cake 1 in 3 h. A run takes the recipe's hours whatever the loads. StationWork and task 198's drop-by-the-kiln path are gone. Save version 31 (upgrade from 20 dropped); a firing kiln keeps its load. No lit look while running (the kiln and oven have none). `--process=<kiln|oven>,<phase>` for screenshots. Plan: docs/plans/199-process-stations.md.

## 201. Wild animals keep away from villagers and buildings (mice excepted)

- [x] Done

The user, 2026-11-11, after task 181 left wild animals able to stand on a door tile: "Wild animals
should stay away from NPC's and buildings, except mice maybe."
- Today wild ground animals (WildlifeRules.GROUND_KINDS: rabbit, squirrel, deer, mouse, frog; and
  the birds that land) walk on `world.is_walkable` (game/scenes/wildlife/wildlife_view.gd), which
  includes door tiles, and only shy from the player (`flee_tiles`, `alert_tiles` in
  WildlifeRules).
- Never on a building tile, the door included, for every wild kind (mice too); and none spawns or
  lands on one.
- Keep a distance from buildings and from villagers, as from the player: they don't spawn or settle
  near them, and flee or turn away when a villager comes as near as their flee distance (a
  per-kind distance in data/, e.g. the same `flee_tiles`, or a smaller one for buildings). Mice are
  the exception: they live by the fields and the houses and may come close to buildings and
  villagers (but still never onto a building tile). Pick the other kinds' distances; the user tunes
  them in data/.
- Cheap: villagers are few, but don't scan every villager per wild animal per frame if a spatial
  lookup exists; say what you used.
- Tests: no wild animal on a building tile over play and spawning; a rabbit or deer moves away from
  a villager; mice may stay near a house; the config check. Design note on wildlife.

Done: 2026-11-12. `WildlifeView.can_stand` refuses every building tile, the door included, for all kinds (waders keep their flooded-mud rule; roof storks and flying kinds don't stand). Spawning and settling avoid a building within the kind's `building_tiles` (data/wildlife.cfg: deer 6, geese 5, stork and waders 4, rabbit 3, bird, squirrel, frog and gull 2) and a villager within its `flee_tiles`. `Animal._nearest_threat` makes them flee the nearer of the player and the villagers. Mice have no `building_tiles` and `ignores_villagers=true`. No spatial lookup exists: the villagers' feet are copied once a frame while animals exist; buildings are looked up by tile. An animal wandering up to a house on its own isn't driven off.

## 202. Storks come too often

- [x] Done

The user, 2026-11-11: "Storks spawn too frequent"
- Wild storks today (data/wildlife.cfg): `[stork]` (hunting on wet ground, cap 2, spawn_chance
  0.03, spring and summer) and `[roof_stork]` (on a roof near the view, cap 2, spawn_chance 0.02);
  plus the nest pairs of task 152, which belong to their nest and are not counted.
- Find out what the player sees as "too often": how many storks are about at once and how often a
  new one flies in, in spring and summer, near the village and the wet meadows; whether settle on
  skip or chunk streaming tops them up again and again, or a stork that flies off is replaced at
  once. Measure it (a short headless run counting stork arrivals per game hour) before and after.
- Make them rarer: a lower cap and spawn chance, a longer gap before one comes back after leaving,
  and roof storks only now and then; numbers in data/ (the user tunes them). Keep the nest pairs
  as they are.
- Tests for the rate (arrivals per hour within a bound) and the cap; design note.

Done: 2026-11-12. Measured with the new tools/bench/storks.gd (headless, writes nothing): before, a player walking by wet meadows saw 0.3 to 1 new storks a game hour, 2 at once, each one scared off replaced within the hour; after, 0.06 to 0.12 an hour, at most 1. data/wildlife.cfg: stork cap 1 and spawn_chance 0.008, roof_stork cap 1 and 0.003, and the new optional `return_gap_minutes` (stork 120, roof_stork 240): after one leaves, no other comes for that long, on spawn ticks or settling. Nest pairs unchanged. The gap isn't saved.

## 203. Wattle fences and stone walls can be made and placed

- [x] Done

The user, 2026-11-11: "Are the willow fences or the stone walls that the map generated creatable?
If not they should"
- Today the world generator lays them along field boundaries (WorldObjectTypes.WATTLE_FENCE, hazel
  rods woven between stakes, cut with the axe for 2 fibre; STONE_WALL, dry fieldstones, taken
  apart with the pickaxe for 3 stone; both `connects: field_boundary`, drawn tile by tile), but
  there is no recipe or item for either: the player can only take them down.
- Add both as things the player makes and places piece by piece, as the pig pen's fence (task
  165: a `pen_fence` item from a workbench recipe, placed on a tile, joining its neighbours):
  - a wattle fence piece: made by hand or at the workbench from rods or sticks and fibre (pick
    what fits the items that exist; hazel rods if there is such an item, else branches or
    sticks), cheap;
  - a stone wall piece: stacked by hand from stone (about the 3 stone it gives back), no station.
  Pick the recipes, skill and level (woodworking for the fence, masonry for the wall if fitting);
  numbers in data/.
- Placed pieces are the same world objects as the generated ones: they join each other and the
  generated runs (the `field_boundary` connection), block walking, are taken down with the same
  tool for the same drops (take care the drops don't make more than the recipe cost, or say why),
  and are saved like other placed objects. Both arts (the art exists).
- Placement: the same rules as the pen fence (free tile, not on water, buildings or paths that must
  stay open); a placement ghost if the pen fence has one.
- Tests: crafting, placing, joining a generated run, taking down, saving. README (building or
  crafting section), design pages.

Done: 2026-11-12. Items `wattle_fence` (workbench, woodworking 5: 1 log + 4 fibre -> 2) and `stone_wall` (by hand, masonry 5: 3 stone -> 1), icons in both arts from tools/art boundaries.py. The generated objects got `placeable_in: OUTDOORS`, so placed pieces are the same objects: they join generated runs, block walking, save alike, and come down with the axe or pickaxe (or the hammer's take-down, like every placed thing) for 2 fibre or 3 stone, never more than the cost (the log is lost). No hazel-rod item exists, so the fence uses a log. Design: design/building/fences-and-walls.md.
