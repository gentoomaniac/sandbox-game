# Code review, 2026-11-06

A maintainability review of the whole project at main 304b720. The goal, in the user's
words: a human should have an easy time getting into the project and taking it over. Focus
on complexity and what can be simpler. No DRY for the sake of DRY; the Zen of Python
(explicit, flat, simple). Four reviewers read one area each: game state, scenes, the art and
sound generators, and tests/build/data/docs.

## Verdict

The project is in good shape. Comments say why, names are precise, the state/scene split
holds, data files fail loudly, the save format is explicit, there is no deep inheritance or
clever metaprogramming, and 1031 tests pass in 50 s. What makes it hard to take over is
size and missing maps, not bad code:

- a few files carry too much: `main.gd` (871 lines, a 77-line header of ~45 debug flags),
  `world_view.gd` (991, near the lint limit), `GameState` (597, half of it the tool-use
  rules), `World` (650, the only lint exception), `tools/art/generate.py` (2290);
- there is no architecture page, no guide to the art and sound generators, no note on how
  to edit an interior map, and TASKS.md is 1364 lines of mostly finished work;
- a handful of "two ways to do one thing" spots and hidden contracts that a newcomer would
  trip over (listed below);
- test output is noisy (840 harmless warnings hide real ones) and a few leftovers are dead.

## What will be done, in order

Each package is one task in TASKS.md (63 onwards), one commit per change so any can be
reverted. They run one at a time beside the art tasks, ordered so they don't fight over the
same files.

1. **Onboarding docs and build papercuts** (task 63, small, no risk). A
   `docs/architecture.md` (how the code is organised: state, world, scenes, data files,
   tools, tests, which test case to extend, the debug flags); `tools/README.md` (module map,
   adding a sprite/object/colour/sound, seed rules); `maps/README.md` (editing interiors in
   Tiled); finished tasks archived to `docs/tasks-done.md`; SPEC status and target list
   fixed; `make help` as the default target; Tiled optional in `make setup`; `make clean`;
   `tools/requirements.txt` and a `make venv` target `make assets` can stand on.
2. **Quiet, honest tests** (task 64, small). The 843 float/int warnings and the 6 orphans
   fixed so real warnings show; the placeholder `test_pipeline.gd` deleted; one-line
   headers on the 13 test files without one; the collapse-flow test no longer waits real
   seconds; `make test` fails when no test ran.
3. **The art generators split by topic** (task 65, right after the art quick wins, before
   the bigger art tasks): `palette.py`, `canvas.py` (cell sizes, one rect, copy — the four
   copied constants exist only because of a circular import), `terrain.py`, `trees.py`,
   `character.py`, `interior.py`; `generate.py` keeps only the assembly. One numbered table
   of the object atlas rows (today three sources that disagree), the trunk-order coupling
   named on both sides. Seasons: copy once instead of scattered copies (an aliasing trap),
   a per-kind look table so a new object without a winter look fails loudly instead of
   staying green under snow. Palette: duplicate names and unknown colours fail with the
   asset's name. Verified by a byte-identical `make assets`.
4. **Small state cleanups** (task 66): delete unused tile state (`water_level`,
   `snow_depth`, `is_tillable`, `is_plantable`), derive `current_map` from the building the
   player is in (two fields that must agree today), pass the clock into `World` instead of
   overwriting it, one `REACH`, a "how to add a save field" rule in `save_file.gd` with the
   scattered `data.get` fallbacks moved into a versioned upgrade so every `from_dict` is
   strict.
5. **Tool use out of GameState** (task 67): the use-action rules (~250 lines) move to a
   `ToolUse` class, like `Builder` and `Crafting`; GameState keeps one-line forwards. A pure
   move, covered by the tests.
6. **World split** (task 68): ground items into their own class (no chunk coupling), then
   the nightly upkeep; the lint exception goes. One `DataFile.read_sections` helper for the
   ten rules classes and one validation API (`problems()` / `is_valid()`), no base class.
7. **main.gd slimmed** (task 69): the debug flags into a parsed `StartupOptions` plus a
   small runner for the "once the world is drawn, do X" steps, documented in one place
   (unknown flags warn); all screens with the same `open()`/`close()`/`is_open()` and one
   list of them in Main (adding a screen touches four places today); `_ready` in three
   named steps.
8. **world_view.gd** (task 70): one packed per-tile code instead of three parallel arrays
   and the corner assembly written out twice; then the building drawing and the
   decorations as their own small views.
9. **Scene odds and ends** (task 71): one shared noise include for five shaders and the
   palette source named next to shader colours; the "object is gone" contract written once
   instead of re-derived in three places; one backdrop colour and one spelling of colour;
   small per-frame waste (weather text built while hidden, copies of empty lists).

## Left as they are, on purpose

- Outline helpers in the art code differ by art rule; they stay separate.
- Builder and Crafting both compute shortfalls in a short loop; readable, no shared helper.
- The hand-written `to_dict`/`from_dict` loops: explicit beats generic.
- AmbientMotion, HitParticles, FallingTree, the debug scene classes and the audio code:
  long in places but clear.
- Tuned art constants (pixel coordinates, noise weights) stay as numbers.

## Maybe later

- Subfolders for `game/state/` (save, rules, weather, audio) and for `tests/`.
- `GameSettings` (550 lines) split into settings and key bindings.
- A known-keys check for the object types table; ruff for the Python tools.
- Faster slow tests (tiling, snow cover, weather) — 15–20 s of the 50.

## For you to decide

- `.deploy-key/` (the push key) sits in the working tree. It is gitignored and safe, but
  the reviewer suggests keeping it under `~/.ssh` instead. Left as is (see QUESTIONS.md).

The four full reports are summarised above; their detailed findings (file:line, effort,
risk) are carried into the task descriptions.
