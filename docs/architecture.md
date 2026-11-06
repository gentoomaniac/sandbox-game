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
ground items) is in `game/state/world.gd`. `game/world/` holds the code that builds a world
and plans which chunks to load (`WorldGenerator`, `ChunkStreaming`, `CampSite`,
`InteriorLoader`, `PositionHash`).

## The main objects

- **Main** (`game/scenes/main.gd`, `main.tscn`) is the one scene. It owns the `GameState`,
  turns real time into game minutes, sends input to the state and creates the views and
  screens. It also parses the debug flags (see below).
- **GameState** (`game/state/game_state.gd`) is one game: the world, the clock, the sun, the
  weather, the snow cover and the player. It is the entry point for actions (`use_at`,
  `sleep_in`, `pass_door`, `pass_out`), and what gets saved (`to_dict`, see `SaveFile`).
- **GameMap** is a place the player can walk: either **World** or **Interior** (the inside of
  one building). The player is on one map at a time; the world stands still while they are
  inside.
- **World** holds the loaded chunks of tiles (`Tile`, `Chunk`), the objects on them
  (`WorldObject`: trees, crops, furniture), buildings and items lying on the ground. Every
  change goes through it, and it emits signals that the views follow.
- **WorldView** (`game/scenes/world_view.gd`) draws a `World` into a SubViewport at one art
  pixel per screen pixel; `CameraController` shows that viewport on the window, so the world
  scrolls smoothly. `InteriorView` draws an `Interior` in its place while the player is inside.
- Other views each draw one piece of state: `PlayerView`, `WeatherView`, `WildlifeView`,
  `BuildMode`, `GroundItemView`, and the HUDs and screens (`HotbarHud`, `CharacterScreen`,
  `CraftingScreen`, `PauseMenu`, `ConsoleView` and so on).

## Data files and how to add content

Gameplay numbers live in `data/*.cfg` (ConfigFile syntax, with the meaning of every key in
the comment at the top of each file). The path from a file to the game is usually the same (`vegetation.cfg` is read by
`Vegetation`, which has no `_rules` file; file names are plural, the classes singular):

```
data/<topic>.cfg  ->  game/state/<topic>_rules.gd  ->  a Types class or the state that uses it
```

- A `*Rules` class reads its file, checks that every required key is there (`problems()`,
  `is_valid()`) and serves the values. `Main._ready` refuses to start, and reports what is
  wrong, if any of them is invalid.
- `BuildingTypes`, `WorldObjectTypes` and `ItemTypes` are the tables of kinds, built from the
  rules and from definitions in code. Look there for what a kind of object or item is.

Typical jobs:

| Job | Where |
|---|---|
| New crop | A section in `data/crops.cfg` and a picture sheet; no code. |
| New building | A section in `data/buildings.cfg`, its two pictures and an interior map ([maps/README.md](../maps/README.md)). |
| New recipe | A section in `data/recipes.cfg` for an item that exists in `ItemTypes`. |
| New sound | An event in `tools/audio/generate.py`, a section in `data/sounds.cfg` ([tools/README.md](../tools/README.md)). |
| New object or item kind | An entry in `WorldObjectTypes` or `ItemTypes`, and its art ([tools/README.md](../tools/README.md)). |

## Saving

`SaveFile` writes one JSON file (`user://saves/world.json`) with a `version`. Every state
class that is saved has an explicit `to_dict` and `from_dict`. When the format changes,
raise `SaveFile.VERSION` and add an upgrade step, so old saves still load. Things marked
"not saved" in a comment (cheats, a forced weather) live only for the session.

## Settings and key bindings

The default key bindings are the input map in `project.godot` (in the Godot editor: Project
Settings → Input Map). The player changes them under Settings → Controls; `GameSettings`
applies them to Godot's `InputMap` and stores only the differences from the defaults in
`user://settings.cfg`.

## Tests

`make test` runs every `tests/test_*.gd` with GUT, headless. A test file is named after what
it covers and should start with a one-line comment saying what it checks. Shared setup
lives in the `tests/*_case.gd` base classes; extend the one that fits instead of building a game by hand:

- `ResourceCase` (`tests/resource_case.gd`): a `GameState` with a patch of grass in front of
  the player, helpers to put objects there and to let days pass. Felling, mining, foraging,
  chests, building, ground items and most world-change tests extend it.
- `EnergyCase` (extends `ResourceCase`): a game running on its own energy rules, whose numbers
  differ from `data/energy.cfg`. The console, cheat, energy and passing-out tests extend it.
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
They are parsed in `Main._ready` and documented in the header of
[game/scenes/main.gd](../game/scenes/main.gd). Pass them to `make screenshot` with
`ARGS="--weather=rain --day=45"`.

## More

- [docs/art-style.md](art-style.md): the look the art aims for.
- [tools/README.md](../tools/README.md): the generators that draw every picture and make
  every sound. The art is code; there are no hand-drawn PNGs to edit.
- [TASKS.md](../TASKS.md): open work and the rules for every task;
  [docs/tasks-done.md](tasks-done.md): what is finished and why.
- [docs/code-review-2026-11-06.md](code-review-2026-11-06.md): the review this documentation
  comes from, with what is planned to get simpler.
