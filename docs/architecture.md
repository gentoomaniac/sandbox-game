# Architecture

How the code is organised, and where to look first. For what the game is meant to be, read
[SPEC.md](../SPEC.md); for how to build and run it, the README.

## Three layers

```
data/*.cfg            numbers and content you can edit by hand
game/state/           the game as plain classes: no nodes, no input, no drawing
game/world/           world generation, chunk planning, the interior map loader (also no nodes)
game/scenes/          everything you see and hear: nodes, views, menus, shaders, sound playback
```

The rule that holds the project together: **scenes read the state and send it actions;
the state never knows about scenes.** That is why almost everything in `game/state/` and
`game/world/` is tested headless with GUT, and why `game/scenes/` is checked by eye with
`make screenshot`.

Names are not always where you would guess: the `World` class (tiles, chunks, objects,
buildings) is in `game/state/world.gd`. `game/world/` holds the code that builds a world
and plans which chunks to load (`WorldGenerator`, `FieldLayout`, `ChunkStreaming`, `CampSite`,
`InteriorLoader`, `PositionHash`). `WorldGenerator` makes the natural land (river, wetland,
forests) and lays the worked land of `data/landscape.cfg` over it: the fields of a `FieldLayout`
with Knicks, walls and fences on the Geest, ditches in the marsh, and dykes. In the west it makes
the coast (task 61, same file): a coast line x = f(y) like the river's centre line, the sea dyke on
the first land, and beyond it the foreshore (salt marsh, tidal mud with tideways, the sea), with a
Warft and an Ewer here and there.

## The main objects

- **Main** (`game/scenes/main.gd`, `main.tscn`) is the one scene. It owns the `GameState`,
  turns real time into game minutes, sends input to the state and creates the views and
  screens. Its `_ready` runs in steps: load the game, make the views, connect the state and
  the views, apply the start options. Every screen (`CharacterScreen`, `CraftingScreen`,
  `StorageScreen`, `ConsoleView`, `ChatScreen`) has `open()`, `close()` and `is_open()`, and
  Main keeps them in one list (`_screens`). The debug flags are parsed by `StartupOptions`; `DebugRunner` does
  the ones that wait for the world to be drawn (see below).
- **GameState** (`game/state/game_state.gd`) is one game: the world, the clock, the sun, the
  weather, the snow cover and the player. It is the entry point for actions (`walk`, `use_at`,
  `sleep_in`, `pass_door`, `pass_out`, `go_to_home_bed`, `teleport_to`), and what gets saved (`to_dict`, see `SaveFile`). It owns
  the clock and gives it to the World; `current_map` follows from the building the player is in.
- **ToolUse** (`game/state/tool_use.gd`) is what the use action does: the `Use` outcomes, what
  each tool does on a tile, and the energy it costs. GameState makes one per call
  and forwards `use_at`, `use_tile`, `use_facing_tile` and `can_use_held_item` to it (kept in a
  field, the two would hold each other and never be freed). To change what a hoe
  does, open this file.
- **GameMap** is a place the player can walk: either **World** or **Interior** (the inside of
  one building). The player is on one map at a time; the world stands still while they are
  inside.
- **World** holds the loaded chunks of tiles (`Tile`, `Chunk`), the objects on them
  (`WorldObject`: trees, crops, furniture), buildings and, in `ground_items` (`GroundItems`),
  the items lying on the ground. Line objects (Knicks, walls, fences, dykes) are one object per
  tile whose type `connects`; `World.connections` says which neighbours a tile joins, and the
  view draws the picture of that connection mask. The wear of desire paths is World's too
  (`wear_tile`, `wear_stage`, `regrow_paths`; numbers in `data/paths.cfg`, `PathRules`):
  `GameState.walk` and `Livestock` wear each tile entered, and a tile that turns trodden or
  a path emits `tile_changed`, so the view redraws the cells around it as for a tilling. The
  view draws worn tiles on the `TRODDEN` and `PATH` layers of `TerrainTileset`. The nightly upkeep of what the player changed is
  `NightUpkeep`, which is given the world. Every change goes through it, and it emits signals that the views follow.
- **WorldView** (`game/scenes/world_view.gd`) draws a `World` into a SubViewport at one art
  pixel per screen pixel; `CameraController` shows that viewport on the window, so the world
  scrolls smoothly. `InteriorView` draws an `Interior` in its place while the player is inside.
  WorldView streams chunks and draws terrain, objects, falling trees and the see-through
  effect; it owns two small views, `BuildingViews` (building sprites, window lights, snowy
  roofs) and `DecorationView` (flowers, pebbles, clay hints; the wildlife asks it where flowers
  bloom). The meadow flowers are sown per tile when a chunk is drawn, by `FlowerRules`
  (`data/flowers.cfg`) from two noises and the tile's habitat, and bloom by the curves of
  `Vegetation`; nothing about them is saved. What a tile looks like is one int, its tile code: layer, season look and weather look
  packed together (`TerrainTileset.tile_code`, read with `layer_of`, `season_of`, `weather_of`;
  the bit fields are documented there).
- **Tide** (`game/state/tide.gd`) says how high the water stands at a moment of the clock; it is a
  look only. Main gives it to `AmbientMotion.show_tide` every frame, and `mud.gdshader` on the
  mud layer floods the mud by it, with the water's ripples of `water_surface.gdshaderinc` (which
  `water.gdshader` shares).
- **Livestock** (`game/state/livestock.gd`) holds the farm animals (`FarmAnimal`) and moves
  them: GameState owns it and Main calls its `update` every frame while the player is
  outside. The numbers are `data/livestock.cfg` (`LivestockRules`). The WildlifeView draws
  them: one `FarmAnimalView` (an `Animal` like the wild ones, but its state comes from the
  FarmAnimal) for each animal near the view. A horse is saddled by `ToolUse` (`SADDLE`,
  `UNSADDLE`) and ridden through `GameState.mount` and `dismount`: `PlayerState.horse` is the
  horse ridden (not saved), which `PlayerState.move` takes along and `Livestock.update` leaves
  alone (`FarmAnimal.is_ridden`); `PlayerView` draws the rider's riding sheets on the ridden
  horse's sheets while the horse's own view hides. A dog given a bone (`ToolUse`, `GIVE_BONE`)
  follows the player until a game minute it keeps (`follow_until_minute`). Wildlife is view only and
  not saved; livestock is state and saved, and shares the wildlife's drawing, sheets and
  sounds. A group of birds is one `Animal` with a sprite per bird: `Flock` (sparrows or a
  skein of geese crossing in a V) and `GooseFlock` (geese grazing, then taking off together).
  Storks on roofs (`Stork`) stand on the top edge of the house's picture as it is shown
  (`WorldView.building_picture`, so snow is counted), just in front of where the house sorts
  (`BuildingViews.sort_position`); flying birds cast `GroundShadows`. A hunter finds its prey
  with `WildlifeView.nearest_animal` (a stork its frogs, `Frog`; a cat its `Mouse`), asked when
  it picks what to do next, not every frame. A cat is state and a mouse is not, so a hunt is
  split: the cat's `FarmAnimalView` finds the mouse, starts the hunt in Livestock
  (`start_hunt`, `track_prey`, `stop_hunt`: the cat crouches, creeps and pounces, by the
  `[hunting]` numbers of `data/livestock.cfg`) and draws the catch as the cat pounces (the mouse
  is caught, or dashes off with `Mouse.flee_from`). Nothing of a hunt is saved.
- **Npcs** (`game/state/npcs.gd`) holds the villagers (`Npc`: name, sex, look as an
  `Appearance`, who they are (age, trade, personality, background, habits), position, anchor,
  chat history and memories) and moves them like the livestock: GameState owns it, Main calls
  its `update` every frame while the player is outside, and the numbers, names, clothes and
  background tables are `data/npcs.cfg` (`NpcRules`); the villagers written by hand, spawned by
  id, are `data/villagers.cfg` (`VillagerRules`). Each is drawn by an `NpcView` among the world
  view's entities, with the player's sheets and frames. E speaks to the villager
  `Interaction.npc_to_chat` names, before any chest, station or bed; `ChatScreen` shows the
  chat with both portraits (`Appearance.portrait_layers`) and pauses the game while it is open.
- **What villagers say** comes from one place, `NpcDialogue.reply` (`game/scenes/`, a node, as
  it talks to the network), which the chat awaits; the wait is the villager's
  (`Npc.is_answering`). With a language model set in Settings the chat of the
  provider (`ModelChat`: `OpenAiChat`, one POST to an OpenAI-compatible `/chat/completions`, or
  `ClaudeChat`, one POST to Anthropic's `/messages` with the system lines on top; both run while
  the game is paused, with a time-out and no redirects, so a key goes nowhere else, and both
  list the endpoint's models for Settings; tests put `FakeChat` in their place), else, or when that fails, it says a scripted line. The
  request is built by `NpcPrompt` (`game/state/`): pure functions of the villager, the chat,
  the moment (`NpcMoment`: clock, sun, weather and place, taken from GameState) and the words
  of `data/npc_talk.cfg` (`NpcTalkRules`), so they are tested without a model. The villager keeps the
  last lines of the chat (a setting); `NpcDialogue.compact` sums the lines that drop out up in a
  memory line, the dropped lines waiting in `Npc.uncompacted_lines` (saved) until it is made.
  Only the reply and memory text come from the model; it changes nothing else.
- **Crafting** (`game/state/crafting.gd`) is what the crafting menu does: it checks a recipe of
  `RecipeRules` (materials, the skill level it needs), crafts it and practises its skill on the
  player's **Skills** (`skills.gd`: points per skill, the total cap and the skills that fade,
  rules from `SkillRules`). A recipe is made by hand or at a station (`StationRules`: which
  object types are which station); a slow one (with `hours`, the kiln) is held by its station
  as **StationWork** in the object's `state` until it is done on the game clock. `Interaction`
  says which chest or station E opens; `CraftingScreen` shows the recipes of one place.
- Other views each draw one piece of state: `PlayerView`, `WeatherView`, `WildlifeView`,
  `BuildMode` (the ghost, and the red marking and hold of taking down; `Builder` holds the
  mode and what each target gives, `GameState.take_down_building` the rules for buildings),
  `GroundItemView`, and the HUDs and screens (`HotbarHud`, `CharacterScreen`,
  `CraftingScreen`, `PauseMenu`, `ConsoleView` and so on). The hotbar is on a layer above the
  character and chest screens and is their quick bar: they take it in their constructor and
  listen to its slot views, and it passes clicks on to the game when none of them is open.
  A stack let go outside a screen reaches the world as `drop_requested`, which Main hands to
  `GameState.drop_from_inventory`.

## Data files and how to add content

Gameplay numbers live in `data/*.cfg` (ConfigFile syntax, with the meaning of every key in
the comment at the top of each file). The path from a file to the game is usually the same (`vegetation.cfg` is read by
`Vegetation`, which has no `_rules` file; file names are plural, the classes singular):

```
data/<topic>.cfg  ->  game/state/<topic>_rules.gd  ->  a Types class or the state that uses it
```

- A `*Rules` class reads its file with `DataFile.read_sections(path)`, checks it (`problems()`,
  `is_valid()`) and serves the values. `Main._ready` refuses to start, and reports what is
  wrong, if any of them is invalid.
- `BuildingTypes`, `WorldObjectTypes` and `ItemTypes` are the tables of kinds, built from the
  rules and from definitions in code. Look there for what a kind of object or item is.

Typical jobs:

| Job | Where |
|---|---|
| New crop | A section in `data/crops.cfg` and a picture sheet; no code. |
| New building | A section in `data/buildings.cfg`, its two pictures and an interior map ([maps/README.md](../maps/README.md)). |
| New recipe | A section in `data/recipes.cfg` for an item that exists in `ItemTypes`; `station`, `skill`, `level` and `hours` are optional. |
| New station | A placed object kind (`WorldObjectTypes` with `drops`, `ItemTypes` with `places`, its picture in `tools/art/crafts.py`), a section in `data/stations.cfg`, and a recipe that makes it. |
| New skill (profession) | A section in `data/skills.cfg`, and recipes that name it. |
| New sound | An event in `tools/audio/generate.py`, a section in `data/sounds.cfg` ([tools/README.md](../tools/README.md)). |
| New object or item kind | An entry in `WorldObjectTypes` or `ItemTypes`, and its art ([tools/README.md](../tools/README.md)). |

### Adding a data file

There is no base class: each rules class is plain, so copy one that is shaped like yours
(`EnergyRules` for fixed sections and keys, `RecipeRules` for one section per thing).

1. Write `data/<topic>.cfg`, with the meaning of every key in the comment at the top.
2. Write `game/state/<topic>_rules.gd` with `DEFAULT_PATH`, a `static var _default`,
   `default_rules()` (loaded on first use), `from_file(path)` and the accessors. `from_file`
   is `DataFile.read_sections(path)` handed to the constructor, then a `push_error` for each
   of `problems()`; `DataFile` already reports a file that can't be read.
3. `problems() -> Array[String]` lists what is missing or wrong as `"[section] what"`, and
   `is_valid()` is `problems().is_empty()`.
4. Add `<Topic>Rules.default_rules().is_valid()` to the check in `Main._ready`.
5. Test it: the real file is valid, a file with keys missing reports them (the test counts
   the `push_error`s with `assert_push_error_count`), and so does a missing file.

## Saving

`SaveFile` writes one JSON file (`user://saves/world.json`) with a `version`. Every state
class that is saved has an explicit `to_dict` and a strict `from_dict` (`data["x"]`, never
`data.get(...)` with a default). When the format changes, raise `SaveFile.VERSION` and add an
upgrade step that gives old saves the new field (the rule is at the top of `save_file.gd`).
Things marked
"not saved" in a comment (cheats, a forced weather) live only for the session.

## Settings and key bindings

The default key bindings are the input map in `project.godot` (in the Godot editor: Project
Settings → Input Map). The player changes them under Settings → Controls; `GameSettings`
applies them to Godot's `InputMap` and stores only the differences from the defaults in
`user://settings.cfg`. The same file keeps the display, game and audio settings and the
language model's provider (OpenAI-compatible, Claude or Gemini, which speaks the OpenAI
protocol: a row of
`GameSettings.LANGUAGE_MODEL_PROVIDERS`, with the protocol it speaks) and each provider's own
endpoint, model and key (`GameSettings.language_model` is the chosen one's; the key in plain
text, never in the save, never sent to another provider). The page of it
(`LanguageModelPage`) lists the models the endpoint offers in a drop-down.

## Tests

`make test` runs every `tests/test_*.gd` with GUT, headless. A test file is named after what
it covers and should start with a one-line comment saying what it checks. Shared setup
lives in the `tests/*_case.gd` base classes; extend the one that fits instead of building a game by hand:

- `ResourceCase` (`tests/resource_case.gd`): a `GameState` with a patch of grass in front of
  the player, helpers to put objects there and to let days pass. Felling, mining, foraging,
  chests, building, ground items and most world-change tests extend it.
- `EnergyCase` (extends `ResourceCase`): a game running on its own energy rules, whose numbers
  differ from `data/energy.cfg`. The console, cheat, energy and passing-out tests extend it.
- `LivestockCase`: a pen of grass ringed by water beside the camp and helpers to let the
  farm animals' time pass (`test_livestock.gd`, `test_livestock_following.gd`).
- `CropCase`: crops, their needs and days that meet them (`test_crops.gd`,
  `test_crop_withering.gd`).

Rendering and input are mostly not unit-tested: run
`make screenshot` and look at the picture, e.g.
`make screenshot AT=40,-20 TIME=21:00 OUT=/tmp/shot.png`. It starts a new game with its own
save and does not touch yours.

## Debug flags

Flags after `--` on the Godot command line put the game in a situation for a screenshot or
a manual check: the position (`--at=x,y`), day and time (`--day=`, `--time=`), weather
(`--weather=`), a held item, an open screen, a small field of crops, animals and more.
They are parsed once into typed fields by `StartupOptions`, whose header lists every flag
([game/scenes/startup_options.gd](../game/scenes/startup_options.gd)); Main, `PlayerView`,
`BuildMode` and `AudioService` read those fields. An unknown flag is a warning. Pass them to `make screenshot` with
`ARGS="--weather=rain --day=45"`.

## More

- [docs/art-style.md](art-style.md): the look the art aims for.
- [tools/README.md](../tools/README.md): the generators that draw every picture and make
  every sound. The art is code; there are no hand-drawn PNGs to edit.
- [TASKS.md](../TASKS.md): open work and the rules for every task;
  [docs/tasks-done.md](tasks-done.md): what is finished and why.
- [docs/code-review-2026-11-06.md](code-review-2026-11-06.md): the review this documentation
  comes from, with what is planned to get simpler.
