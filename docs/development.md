# Development

How to run, test, build and release the game, and the debug commands behind the pictures. For the
code itself start with [architecture.md](architecture.md), and with [ui.md](ui.md) for how to build a
window. `make help` lists the targets and their variables.

## Running the game

The game uses Godot 4.7.2 with GDScript. Make targets wrap every multi-step job.

```sh
make setup   # checks for Godot, Python 3, git and curl (Tiled is optional); downloads GUT;
             # creates a Python venv, builds assets/ and imports the project
make run     # starts the game
```

The pictures and sounds Godot reads are in `assets/`, which is not in git: `make assets` builds
it from the art in `art/` (see [tools/README.md](../tools/README.md)). `make setup`, `run`, `test`
and `screenshot` do that themselves when `assets/` is missing or older than `art/`, so after
pulling nothing needs doing by hand; the first Godot import of a fresh `assets/` takes about a
minute. To replace the art of one entity by hand, drop a file in `art/hand/` (see
[art/hand/README.md](../art/hand/README.md)); `make assets` uses it over the generated one. Start
the game with `make run`: it imports new art first. Starting Godot directly makes the game stop
with a list of pictures that aren't imported yet; run `make assets` and `godot --headless
--import` once then.

On Linux the game uses the X11 display driver (XWayland under a Wayland desktop), set in
project.godot: Godot 4.7.2's Wayland driver sometimes never finishes quitting, leaving the
window open. The game has saved by then. To try Wayland anyway:
`godot --path . --display-driver wayland`.

Quit the game from its menu or by closing the window: Ctrl-C in the terminal ends Godot at once,
without saving (Godot 4.7 lets no script handle the signal), so the play since the last save is
lost.

`make setup` never installs system packages. If something is missing, it prints what to
install, with Gentoo package names where there are some. If your Godot binary has a
different name, pass its path: `make GODOT=/path/to/godot run`.

## Releases

`make export` builds the game for Linux and Windows (x86_64) into `build/export/`, one zip per
platform: `sandbox-game-<version>-linux-x86_64.zip` and `sandbox-game-<version>-windows-x86_64.zip`
(the executable has its data inside). `make export VERSION=1.2.3` names the version, which is also
written into the build's `application/config/version`; without it `git describe` does. It needs the
export templates of the pinned Godot (`.godot-version`): in the editor Editor → Manage Export
Templates, or unpack the `templates/` folder of `Godot_v<version>-stable_export_templates.tpz`
(from the Godot release page) into `~/.local/share/godot/export_templates/<version>.stable/`.
`export_presets.cfg` lists the files the game reads at run time that Godot would drop from an
export (`data/*.cfg`, the Tiled maps, the music); a new kind of such file goes into its
`include_filter`.

To cut a release, tag the commit and push the tag:

```sh
git tag v1.2.3 && git push origin v1.2.3
```

The workflow `.github/workflows/release.yml` runs on tags of the form `vX.Y.Z` (any other tag
fails its first step). It installs the pinned Godot and its export templates, runs `make assets`
and `make export VERSION=1.2.3`, and publishes a GitHub release of the tag with the two zips.

### Breaking changes for the release notes

The release workflow generates the notes from the commits (`--generate-notes`); a change that
breaks a player's save or world is added here by hand when it is made, and goes into the notes of
the next tag.

- **The map generation changed** ([#60](https://github.com/gentoomaniac/sandbox-game/issues/60),
  save version 45). The land is generated from the seed and a save holds only what the player
  changed, so a world made before keeps its buildings, tilled soil and other edits but every
  place the player did not touch is new land: no field grid, fences or ditches, woods in patches
  instead of lone trees, a winding river with creeks. A new game with the same seed starts at
  another camp and looks different from before. Seams between old edits and new land may
  look odd. Saves of version 45 and older are no longer read (their upgrade was dropped to keep
  ten steps).

## Language model

The rule for full or cut-down villager sheets is `needs_key` of the provider's row in
`GameSettings.LANGUAGE_MODEL_PROVIDERS` (`NpcDialogue.has_full_sheets`). `SANDBOX_LLM_URL=http://127.0.0.1:11434/v1
make test` also runs the tests that ask the real model, and `ANTHROPIC_API_KEY=... make test` asks the
real Claude once.

## Tests of saves

A test of what a feature saves gets the game back with `RealLoad.of(self, state)`
([tests/real_load.gd](../tests/real_load.gd)): it writes a current save, loads it with
`SaveFile.load_game` and fails with the problems unless the result is READY. Calling `from_dict` on
`to_dict` directly skips the validator, so a save the loader refuses would pass; only a test of the
codec itself does that, and its name says "codec".

## Adding a saved feature

A new saved field is a format change in three places, in one commit with its test:

1. **The check.** Put the check of the new keys in the domain validator of
   `game/state/save_checks/` that owns the data, or a new `Save<Domain>Checks` class (it takes the
   `SaveContext`, and `SaveValidator._check_game` calls it, in the order its references need). A
   feature that keeps a dictionary in an object's state (like the sales cart's `prices`) adds a
   method to the `_state_checks` table of `SaveObjectChecks`, keyed by its state key, and names the
   key in `OWN_SHAPE_STATE_KEYS` if it is no number; every other state entry must be a number. A
   new optional key needs its check even when it needs no new version. Content that the game may
   drop later (an item, a recipe) goes through `add_missing` with what removes it, not `report`.
2. **The migration**, when the format changes: raise `SaveFile.VERSION`, add
   `game/state/save_migrations/v<old>_to_v<new>.gd` (`static func upgrade(game: Dictionary)`) that
   writes the default into an old save, written out as a literal and not read from data files, so
   that a later balance change leaves old saves alone. Drop the oldest script so that ten remain
   (the rule is at the top of `save_file.gd`). The next version is claimed serially, when the
   branch is integrated: parallel work cannot both take version 57.
3. **The tests.** An old save without the field loads (`tests/test_save_upgrade*.gd`), what the
   feature saves comes back through the loader (`RealLoad`, see above), and a damaged value is
   refused (`tests/test_save_validation*.gd`).

## Pictures for the README and the handbook

The pictures are in `screenshots/`. Take them with `make screenshot`; re-take the ones a change makes
out of date. Recipes that were used (add `--classic-art` for the classic art):

- The box over a crop (`docs/screenshots/crop-state.png`): `make screenshot SIZE=640x360 ZOOM=2 TIME=12:00
  AT=8,5 ARGS="--field=1,1 --mouse-tile=4,3"` (the ripe turnip of the debug field). A seed tooltip:
  `ARGS="--hold=beans_seeds --tooltip=hotbar_0 --mouse-tile=0,0"`. The warning toast shows for a few game
  minutes after an hour ends: start a little before it (`TIME=12:56`, `--screenshot-delay=0.3`).
- The hens of the farm yard: `make screenshot SIZE=1000x560 AT=68,-17 TIME=12:00 ZOOM=1.25
  ARGS="--yard=40,-20 --day=45"`, each art cropped to x 35 to 460, y 190 to 360, one above the other and
  doubled; the hens wander, so each shot looks a little different.
- The pig pen: `make screenshot SIZE=1120x500 AT=73,-6 TIME=12:00 ZOOM=1.25 ARGS="--yard=40,-20 --day=45"`,
  each art cropped to its left 700 px.
- The farm yard: `make screenshot SIZE=1000x700 AT=69,-15 TIME=12:00 ZOOM=0.75 ARGS="--yard=40,-20 --day=45"`
  (`--yard` also shows the stations and the lines across the land, 22 tiles west of it).
- A villager in a room (`docs/screenshots/villager-inside.png`): `make screenshot SIZE=800x560 ZOOM=1
  TIME=12:20 ARGS="--inside=kate --villager-inside=antje --screenshot-delay=1.0"` (she is given the
  house and stays in it at dinner time; she strolls, so each shot differs).
- A speech bubble: `--bubbles` lets a bubble follow the last at once. A lone villager in the rain with
  room above her head: `make screenshot SIZE=640x360 ZOOM=2 TIME=09:00 ARGS="--bubbles --villager=antje
  --weather=rain --camera-shift=0,-10 --screenshot-delay=0.2 --mouse-tile=0,0"`; `--mouse-tile=0,0` keeps the highlight off the villager. The scripted line shows when
  `build/settings.cfg` has an empty `endpoint` under `[language_model]`. The line and the place vary, so
  take it a few times; the two arts side by side are two shots joined.
- A frame of a tool's swing (`--swing-frame` freezes the held tool's swing on a frame, counted from 0): `make
  screenshot SIZE=320x200 ZOOM=2 TIME=12:00 ARGS="--hold=steel_axe --pose=right --swing-frame=3 --mouse-tile=0,0"`.
- The shop (#10): Trienke Lorenzen behind her stall in shop hours, she walks from her cottage so give her
  a minute: `make screenshot SIZE=640x360 ZOOM=2 TIME=07:30 AT=-204,-186 SCREENSHOT_TIMEOUT=300
  ARGS="--day=1 --screenshot-delay=75 --mouse-tile=0,0"` (the stall of seed 1; add `--weather=rain` for
  the rain). The trade screen: `make screenshot SIZE=640x360 ZOOM=2 TIME=09:00 AT=-204,-184
  ARGS="--day=1 --screenshot-delay=2 --mouse-tile=0,0 --trade --console='give logs 5;give egg 8;give fibre 6'"`.
  `docs/screenshots/shop-stall.png` and `shop-trade.png` are the two arts joined, the new one left.
- The console with a long, wrapping line: `"ARGS=--console='weather;god;spawn'"` (several commands, `;`
  between them, need that quoting).
- The build menu: `make screenshot SIZE=1000x700 ZOOM=0.75 TIME=12:00 AT=69,-17 ARGS="--day=45 --yard=40,-20
  --building=kate.brick --ghost=72,-21 --free-build --mouse-tile=0,0"`.
- A talk with the language model: start the test LLM (`make llm-up`; screenshots read
  `build/settings.cfg`, where the default endpoint applies) and run

```
make screenshot SCREENSHOT_TIMEOUT=120 ARGS="--villager=antje '--chat=Moin, Antje!;Do you have butter?'"
# or canned lines, no model asked (you and the villager in turn; a last "..." is them typing)
make screenshot ARGS="--villager=antje '--chat-script=Moin, Antje!;Moin!;...'"
```

## Make targets and tools

`make contrast-sheet` shows plants over the ground of every look.

| Command | What it does |
|---|---|
| `make help` | Lists the targets and variables (the default). |
| `make test` | Runs the GUT test suite headless, in `TEST_JOBS` parallel Godot processes (default 8; `TEST_JOBS=1` runs one process). A shard running longer than `TEST_TIMEOUT` seconds (default 600) is killed and fails. `build/test.log` is the shard logs joined plus a summary; `build/test-<i>.log` are the single logs, and `build/test-times` the file durations that balance the next run. |
| `make test-changed` | Runs only the tests the changes since `BASE` (default `main`) need: the whole branch plus uncommitted files. Prints what it picked and why; runs everything when it can't place a path. Run `make test` before reporting a task. See [tools/README.md](../tools/README.md). |
| `make lint` | Runs `gdlint` and `gdformat --check`. |
| `make format` | Formats the GDScript. |
| `make assets` | Builds assets/ (what Godot reads) from art/generated/ and the hand-drawn art in art/hand/, in seconds; `run`, `test` and `screenshot` do it when needed. Needs Python only, not Godot. |
| `make art` | Draws all pixel art from the palette and all sounds into art/generated/ (deterministic, minutes). Needs Python only, not Godot. |
| `make llm-up`, `llm-check`, `llm-down` | A local test LLM in a container (see [Talking with a language model](../handbook/villagers.md#talking-with-a-language-model)); no test needs it. |
| `make llm-pull`, `llm-models`, `llm-rm` | Fetch, list and delete other models for it, e.g. `LLM_MODEL=qwen2.5:7b-instruct`; then set that model under Settings → Language model. |
| `make clean` | Deletes build/ (test log, screenshots). |
| `make screenshot` | Saves one frame, e.g. `make screenshot AT=40,-20 TIME=21:00`. Muted (`SOUND=1` keeps the sound), the window doesn't take the focus, and it uses its own save in build/ (`KEEP_SAVE=1` loads yours). The window is titled `Sandbox Game (test)` (the game flag `--with-working-window-title`), so window rules can tell it from your game; `make run ARGS=--with-working-window-title` does the same. `SIZE=1000x1040` makes the picture exactly that size and shows what a window of that size shows, whatever size the window manager gives the window (on Wayland it decides). |
| `make world-map` | Draws a top-down PNG of a seed's generated land, headless and without a save: `make world-map SEED=42 AT=0,0 MAP_SIZE=320 MAP_SCALE=3 MAP_OUT=/tmp/map.png` (`AT` is the middle tile; `VILLAGE=1` builds the seed's village Wehlsbüll first and draws that, centred on it, 128 tiles at scale 8 unless given). Colours are in [game/world/map_colors.gd](../game/world/map_colors.gd) (shared with the console's `map`) and [design/world/map-generation-review.md](../design/world/map-generation-review.md); the before and after maps of the map generation review are in `docs/screenshots/map-generation/`. |

- **Art and sound:** all art is generated by Python scripts, from a small fixed palette, and all sounds are synthesised. [tools/README.md](../tools/README.md) has the
  module map and how to add things; the entry points are
  [tools/art/generate.py](../tools/art/generate.py) and
  [tools/audio/generate.py](../tools/audio/generate.py).
- **Interiors:** the rooms inside the buildings are Tiled maps, see
  [maps/README.md](../maps/README.md).
- **Art style:** period, place, materials and what to avoid are in [art-style.md](art-style.md); `make contrast-sheet` shows plants over the ground of every look.
- **Data files:** gameplay numbers you might want to tune live in
  [data/](../data/) (energy, crops, buildings, recipes, weather, seasons, vegetation, flowers, wildlife, sounds, ambience).
- **Items and objects:** their definitions (the topic scripts in `game/state/items/` and `game/state/world_objects/`, gathered by `ItemTypes` and `WorldObjectTypes`) are read-only and checked at start with their references and pictures (both art sets); a mistake is named by item and field, see "Adding a data file" in [architecture.md](architecture.md).
- **Design:** the design is in [design/](../design/README.md): one folder per category.
- **Debug flags:** command-line flags for screenshots and debugging (time, day, weather,
  position and more) are listed in the header of [game/scenes/startup_options.gd](../game/scenes/startup_options.gd).
