# Documentation review, 2026-11-06

Scope: README.md, SPEC.md, TASKS.md, QUESTIONS.md, docs/architecture.md, docs/art-style.md,
docs/tasks-done.md, docs/code-review-2026-11-06.md, docs/ideas/crafting-and-professions.md,
maps/README.md, tools/README.md, the Makefile help text, the header of
`game/scenes/startup_options.gd`, the console command table, `data/*.cfg`, the input map in
`project.godot` and `game/state/save_file.gd`. `docs/archive/` is only checked for wrong
links. Reviewed commit of main: `8ac9a98`. There is no AGENTS.md or CLAUDE.md in the repo.

How to use this file: each finding has an ID (D1, D2, ...) that stays stable. Write your
answer on the `Decision:` line (keep / change / drop, or a note). Nothing here is fixed yet;
this review only reports. Line numbers are those of `8ac9a98`.

## Summary

The docs are in good shape and most claims check out. All 24 screenshots in
`docs/screenshots` are used by the docs and every referenced one exists. Building costs and
sizes match `data/buildings.cfg`, interior sizes match the `.tmx` files, the palette count
(43 + 21 = 64) matches, and the README key table matches the input map except for F2.

The biggest problems:

1. README says beds don't block walking; SPEC and the code say they do (D1).
2. The README controls table misses F2 (fast forward), and the SPEC console section misses
   `nocost` and `skill` (D2, D3).
3. SPEC is "the single source of truth" but is 1165 lines, mixes built and merely planned
   decisions, repeats art detail that belongs in art-style.md or the task logs, and has no
   status marker per decision. The same facts (costs, skills, paths, the hall house) live in
   four to six files (D35 to D37).
4. A few statements are now false: TASKS "Later" says storks exist "since task 60", the
   crafting ideas doc says "nothing decided" and "the chest is the only recipe", the code
   review reads as a plan although all of it is done (D14, D16, D17).
5. architecture.md has no section for sound, weather and seasons, lighting, build mode or
   interiors, and no file in the repo states the working rules (worktrees, atomic commits,
   README and screenshots per feature, quiet test runs); they exist only in the user's
   memory (D23, D24).

---

## 1. Inconsistent

### D1. README says beds don't block walking; SPEC and code say they do

**Where:** README.md lines 222-224 ("Beds don't block walking, so you can't get stuck behind
one."); SPEC.md line 239 ("Beds block walking (the bedroll does not)"); TASKS.md task 78
(the head text says the bed no longer blocks walking, the "Fix" paragraph reverts that).
**Finding:** The README repeats the first version of task 78, which was reverted. Task 78's
own head text still says the opposite of its fix note.
**Suggestion:** Change the README sentence to: you wake lying in the bed and get out with
your first step, onto the free tile beside it. Reword task 78's head text or point it to the
fix paragraph.
Decision: _(keep / change / drop)_

### D2. README controls table has no F2 (fast forward)

**Where:** README.md "Controls" table (lines 318-334); `project.godot` action
`toggle_fast_forward` (F2); `game/scenes/main.gd` lines 15-17 (60x speed); `game_settings.gd`
lines 79 and 101 (it shows in Settings → Controls as "Fast forward. Only for testing.").
SPEC.md never mentions it.
**Finding:** A rebindable key the player sees in Settings is documented nowhere. The README
says "these are the default keys" and lists all the others.
**Suggestion:** Add `F2 | Run time faster (testing)` to the README table and one line to SPEC
"Menus and settings". Also F6 (cycles the hair style, `player_view.gd`, flag header): list it
as a debug key or say in architecture.md "Debug flags" that it exists.
Decision: _(keep / change / drop)_

### D3. SPEC console section lacks `nocost` and `skill`, and calls `spawn` "later"

**Where:** SPEC.md lines 408-415 ("Commands: help; tp; give; god; nodrain; noweight. Later
commands: spawn ..., weather, snow, crop, reset, skip"); `game/state/console.gd` `COMMANDS`
has 14 commands, including `nocost` and `skill`. `nocost` is mentioned in SPEC line 1041 and
`skill` under Professions, not in the console list. The README table is complete.
**Finding:** The SPEC list is two commands short and "Later commands" is a leftover from when
they were planned.
**Suggestion:** Replace the sentence by the full list, or say "see `help` and the README
table" and decide which doc owns the command list (D26).
Decision: _(keep / change / drop)_

### D4. SPEC says weather has no effect on the game; crops react to it

**Where:** SPEC.md line 530 ("Effects for now are visual only ... Nothing in the game reacts
yet (crops, floods, frozen rivers, energy and the like come later)"); SPEC "Farming" (crops
need warmth, rain and sun, die from frost and wind); README "Farming" ("the weather speeds it
up, slows it down or damages it").
**Finding:** Direct contradiction inside SPEC. Weather already drives crops, soil moisture,
reed regrowth and snow cover.
**Suggestion:** Reword to "The weather's effects on looks, crops, soil moisture and reeds are
built; floods, frozen rivers and effects on walking or energy are not."
Decision: _(keep / change / drop)_

### D5. Planned weather and flood rules sit in "Decided" next to built features

**Where:** SPEC.md from line 577 ("Weather and seasons change the map: frost freezes rivers
...", "Weather is per biome", "Floods only reach floodplains", "Floodplains are farmland with
a risk").
**Finding:** None of these is built, but they stand in the same list as built and tested
behaviour with no marker. A reader (or an agent writing a task) cannot tell.
**Suggestion:** Move them under a "Planned" heading in the same section, or tag every SPEC
bullet as built / planned (D36).
Decision: _(keep / change / drop)_

### D6. The README's list of data files is incomplete

**Where:** README.md lines 384-385 ("energy, crops, buildings, recipes, weather, seasons,
vegetation, flowers, wildlife, sounds, ambience"); `data/` has 16 files. Missing from the
list: `landscape.cfg`, `livestock.cfg`, `paths.cfg`, `skills.cfg`, `stations.cfg`.
**Finding:** Five of 16 files are not named in the developer list (most are named in the
feature text).
**Suggestion:** Say "every `data/*.cfg` has the meaning of its keys in its header" and put a
table in architecture.md (D27).
Decision: _(keep / change / drop)_

### D7. Architecture says Main refuses to start on any invalid rules; two are not checked

**Where:** docs/architecture.md lines 96-98 ("`Main._ready` refuses to start ... if any of
them is invalid") and "Adding a data file" step 4; `game/scenes/main.gd` lines 75-90 checks
13 rules classes plus `Vegetation`, but not `WeatherRules` or `FlowerRules`, although both
have `is_valid()`.
**Finding:** The docs describe a rule the code does not fully follow. A broken `weather.cfg`
or `flowers.cfg` is reported by `push_error` but does not stop the start.
**Suggestion:** Either add the two to the check (a code task) or say in architecture.md which
rules are checked at start. Your call.
Decision: _(keep / change / drop)_

### D8. "Save version N" means two different things

**Where:** SPEC.md line 280 ("A version 10 save moves what lay in the two dropped hotbar
slots") vs TASKS.md task 72 ("Save version 11: the upgrade moves ..."); SPEC lines 307
("Old saves (version 8)"), 988 ("A save from before (version 11)"), 1110-1111 ("saves of
version 9 and before ... Save version 10"); TASKS tasks 52, 53, 54, 57, 66, 72, 73, 74, 77.
**Finding:** Sometimes N is the version a change introduced (task 72: "version 11"),
sometimes the version of the old save that gets upgraded (SPEC line 280: "version 10").
Both are right for the same change, but the reader must know that `_upgrade_from_version_N`
takes a save of version N to N+1. Task and version numbers also run out of order (task 66 =
v8, 52 = v7, 53 = v9, 72 = v11, 57 = v12).
**Suggestion:** State one convention at the top of `save_file.gd` and in architecture.md
"Saving" ("version N is what a save has after the change"), then fix SPEC lines 280, 307, 988
and 1110 to it. Add the table of D25.
Decision: _(keep / change / drop)_

### D9. The starting kit is described in three places that do not add up

**Where:** SPEC.md line 321 (hoe, axe, pickaxe, watering can, scythe, shovel, a bag of turnip
seeds), line 1042 (a hammer), the "Character screen" bullet (clothes, hats, jacket, spare
shirt); TASKS.md task 72 ("The 8 starting items fill the hotbar"); README "Build anywhere".
**Finding:** No single list of what a new game starts with. The seed count and the hotbar
order are in no doc.
**Suggestion:** One bullet in SPEC "Player": hotbar = ..., backpack = ..., worn = .... The
other places link to it.
Decision: _(keep / change / drop)_

### D10. `rabbit` means the wild rabbit in one flag and the tame one in another

**Where:** `game/scenes/startup_options.gd` header: `--wildlife=` lists `rabbit` (wild),
`--livestock=` lists `rabbit` (tame); console `spawn rabbit` (tame) and `spawn wild_rabbit`
(README line 309, SPEC line 411); QUESTIONS 14 is the only place that says so.
**Finding:** The same word names two animals depending on the command.
**Suggestion:** Add one line to README "Livestock" and to the flag header: "`rabbit` is the
tame rabbit in `spawn` and `--livestock`, the wild one in `--wildlife`". Or rename the
wildlife flag value to `wild_rabbit` (a code change; your call).
Decision: _(keep / change / drop)_

### D11. QUESTIONS still says "free 20 kg" and writes "wood" and "reed"

**Where:** QUESTIONS.md lines 33-35 ("a new game still carries under the free 20 kg"); line
90 ("100 wood, 40 stone, 50 clay, 80 reed").
**Finding:** The free weight is 40 kg since task 72. The items are called logs and reeds
(`ItemTypes.LOGS`, `REEDS`, `cost_logs`).
**Suggestion:** Fix both, or date the items so they read as notes of the day (see D12).
Decision: _(keep / change / drop)_

### D12. QUESTIONS.md says answered questions move to SPEC, but 18 decisions stay

**Where:** QUESTIONS.md lines 3-5 and 7-100 (items 1-19; item 13 is missing); line 102-104
("Questions: No open questions right now.").
**Finding:** The header says answered items are removed, yet 18 items stay under "Decisions
taken without you (please confirm or change)". Many are already described in SPEC or TASKS.
Whether you confirmed any is not recorded, so "No open questions" is misleading. Item 19 is
the defaults of tasks 79-82, which are not built.
**Suggestion:** Add a status per item (`open`, `confirmed`, `changed`). Move confirmed ones
out (their text is in SPEC). Say that numbers are not reused, so the gap at 13 is fine.
Decision: _(keep / change / drop)_

### D13. TASKS 79-82 and QUESTIONS 19 hold the same defaults twice

**Where:** TASKS.md lines 593-640 (each task says "Defaults (QUESTIONS.md 19)" and then
repeats them); QUESTIONS.md lines 94-100.
**Finding:** Same text in two files; one will be edited and the other not.
**Suggestion:** Keep the defaults in the tasks and reduce QUESTIONS 19 to "tasks 79-82 went
ahead with the defaults in TASKS; confirm or change".
Decision: _(keep / change / drop)_

---

## 2. Outdated

### D14. TASKS "Later" says the stork's clatter exists "since task 60"; task 60 is not done

**Where:** TASKS.md lines 644-647 ("`SoundEvents.animal_alarm`, which since task 60 also gives
the stork's clatter") vs task 60 (line 205, `- [ ] Done`); `grep -i stork` in `game/` and
`data/` finds nothing.
**Finding:** The note describes the future as the past.
**Suggestion:** Reword to "which will also give the stork's clatter (task 60)", or move the
note into task 60.
Decision: _(keep / change / drop)_

### D15. TASKS "Later" holds notes that are done, duplicated or no longer true

**Where:** TASKS.md lines 642-743.
**Finding:**
- Lines 652-653 and 662-664 both ask to split `World`'s object edits out. Task 68 already
  moved `pass_night` out, so the two overlap and one is half done.
- Lines 684-686 "Extra vegetation (done, branch `extra-vegetation`)" is a done item.
- Line 697 "Pines read as olive-brown blobs ... (redrawn in task 51)" is done.
- Line 698 "The sleeping bag (1x2, vertical) reads like an upright sign" is probably fixed by
  task 52 (new bedroll) and task 78 (the bed in layers); check.
- Lines 691-692 about `generate.py` "shared sprites ... defined several times" may be fixed
  by task 65's split; check.
- Lines 741-743 end with "Harvesting trees and rocks ..., saving and loading, inventory,
  energy, weather, biomes, combat, reputation ... real art" as if all of it were still
  ahead; most is built.
- Line 674 "Held art and use poses for axe, pickaxe, scythe and shovel" is still open; keep.
**Suggestion:** Walk this list once: delete done items, merge duplicates, move real open ones
into a "Known issues" list with a file name each. Replace the last paragraph by a line that
matches SPEC "Deliberately left out".
Decision: _(keep / change / drop)_

### D16. The crafting ideas doc still says "nothing decided" and "the chest is the only recipe"

**Where:** docs/ideas/crafting-and-professions.md line 3 ("Status: idea collection, nothing
decided"); section 6 (lines 500-546: "**Today:** ... the chest is the only recipe"; a new
`skills.cfg` and `stations.cfg` as future files; "save version bump ... like version 7 and 8
did"); section 7 (questions 1, 2, 6, 9 and 12 are answered by task 74, SPEC "Professions"
and "Livestock").
**Finding:** Task 74 built woodworker, cook, mason, skills, stations, the skills tab, the
total cap and the kiln. The doc's status and its "Today" section say the opposite, and
answered questions are listed as open.
**Suggestion:** Change the status to "ideas; the first three professions are built, see SPEC
Professions". Mark in section 7 which questions are answered and where. Replace "Today" in
section 6 by "Built in task 74" or delete it. Link the doc from SPEC "Later features".
Decision: _(keep / change / drop)_

### D17. The code review reads as a plan, and architecture.md links it as one

**Where:** docs/code-review-2026-11-06.md lines 25-74 ("What will be done, in order"), lines
92-95 ("For you to decide: `.deploy-key/` ... see QUESTIONS.md"); docs/architecture.md lines
182-183 ("the review this documentation comes from, with what is planned to get simpler");
TASKS.md tasks 63-71 are all done.
**Finding:** All nine packages are done; the review still says "will be done". The
`.deploy-key` item points to QUESTIONS.md, which has no such item. The folder is not in the
working tree, and it is not in `.gitignore` either, although the review says it is. The
numbers it quotes (871 lines in main.gd, 1031 tests, "ten rules classes") are from before
the work.
**Suggestion:** Put a status line on top ("all done: tasks 63-71") and change the tense, or
move the file to `docs/archive/` and change the architecture link to "the review that led to
this page". Drop the dead `.deploy-key` item or move it to QUESTIONS.
Decision: _(keep / change / drop)_

### D18. Some "Done" paragraphs quote sizes that no longer hold

**Where:** TASKS.md line 232 ("docs/architecture.md (~80 lines ...)"; it has 183); lines
318-319, 369, 388 (line counts of GameState, main.gd, world_view.gd at the time of the task).
**Finding:** Fine as a log, but nothing says they are a snapshot.
**Suggestion:** Do nothing, or add one line at the top of TASKS.md: "Done paragraphs are
logs; numbers in them are as of the day they were written."
Decision: _(keep / change / drop)_

### D19. SPEC "Tile state" says dynamic properties are "for now only frozen"

**Where:** SPEC.md lines 143-146; `game/state/tile.gd`; TASKS task 66 (kept `frozen` only),
task 77 (wear is world data, not a tile property).
**Finding:** True, but the section never says where soil moisture, wear and snow cover live
(World dictionaries; snow derived from the weather). A newcomer who reads "a tile is state"
looks for them in `Tile`.
**Suggestion:** Add one sentence on where each lives, and that `frozen` is a hook no rule
sets yet.
Decision: _(keep / change / drop)_

### D20. SPEC "Saving" and "Milestones" describe the first version only

**Where:** SPEC.md lines 133-141 ("Saving (first version)": "player state (position, current
map, home, appearance, inventory) + clock"; "No save menu or multiple slots yet"); lines
1133-1151 (Milestone 1: "Sleeping in the sleeping bag advances to the next day"; "Not in the
prototype: ... weather, energy, saving and loading"); TASKS.md lines 3-5 ("Implements
milestone 1").
**Finding:** The save also holds skills and fade marks, livestock, soil moisture, wear, station
work, chests and equipment. The milestone text says weather, energy and saving are "not in
the prototype" and then says they were "added since": it is a history, not a description.
**Suggestion:** Rewrite "Saving" as the current format in one paragraph and link to
`GameState.to_dict`. Rename the milestone section to "History: milestone 1", or replace it by
"Where we are" and a short roadmap.
Decision: _(keep / change / drop)_

### D21. Two sentences in SPEC use words that no longer fit

**Where:** SPEC.md lines 107-108 ("in spring and summer the green flowers with the meadow and
pasture flowers of the region": words are missing); line 749 ("a sleeping bag on 1x2").
**Finding:** The first reads as nonsense; the second uses the old name (see D42).
**Suggestion:** "in spring and summer the grass flowers with the meadow and pasture flowers of
the region"; "a bedroll on 1x2".
Decision: _(keep / change / drop)_

### D22. tools/README.md has a broken sentence

**Where:** tools/README.md lines 48-49 ("`generate.py` imports all the others and none of them
imports it; most import `canvas.py`, and" then "Of the art modules, `palette.py` imports
only ...").
**Finding:** Two sentences were merged by a bad edit; the first ends in "and".
**Suggestion:** "... most import `canvas.py`. Of the art modules, `palette.py` imports only
`seasons` (for its colours) and `canvas`."
Decision: _(keep / change / drop)_

---

## 3. Missing

### D23. No file states the working rules of the project

**Where:** the repo root has no AGENTS.md or CLAUDE.md; TASKS.md lines 10-20 list five rules.
The user's memory holds more: SPEC and TASKS are living docs updated with each decision;
README and screenshots are updated with every merged feature; test runs are muted, never
steal focus and never touch the real save; one commit per change, never squashed; main is
pushed after a merge; questions go to QUESTIONS.md when the user is away; work happens in
worktrees and is reviewed before merge.
**Finding:** A new contributor or a fresh agent session cannot learn these rules from the
repo. The Makefile enforces some of them (`make screenshot` is muted and uses its own save)
but does not say why.
**Suggestion:** Add a short `AGENTS.md` (or a "Working rules" section in TASKS.md) with these
rules, the source-of-truth table of D26, and the main commands. Keep it to one page.
Decision: _(keep / change / drop)_

### D24. architecture.md has no sections for sound, weather and seasons, lighting, build mode, interiors, wildlife or the player

**Where:** docs/architecture.md "The main objects" (lines 27-84) covers Main, GameState,
ToolUse, GameMap and World, WorldView, Livestock and Crafting. Missing, with the classes a
section would name:
- **Sound:** `AudioService`, `GameSounds`, `AmbienceSounds`, `SoundEvents`, `SoundRules`,
  `Muffle`; how a happening becomes an event and then a file in `data/sounds.cfg`
  (tools/README.md has only the "adding" half).
- **Time, weather, seasons, snow:** `GameClock`, `Sun`, `Weather`, `WeatherRules`,
  `SnowCover`, `SeasonBlend`, `SeasonRules`, `SeasonalArt`, `Vegetation`; the 2-3 day blend;
  how a season look is chosen per tile.
- **Lighting and the look pipeline:** the SubViewport, `CameraController`, `DayNightTint`,
  `ObjectLight`, the shaders (sway, water, fire, see-through, sharp bilinear), `Occlusion`.
- **Building and interiors:** `Builder`, `BuildMode`, `BuildPanel`, `BuildingRules`,
  `Interior`, `InteriorLoader`, `InteriorView`, `Interaction`, `Targeting`.
- **Ambient wildlife:** the `Animal` classes in `game/scenes/wildlife/` and `WildlifeRules`
  (only "view only and not saved" inside the Livestock bullet).
- **The player:** `PlayerState`, `Equipment`, `Inventory`, `Appearance`, `EnergyRules`,
  `PassOutMessage`, `TirednessView`; the sleep and pass-out flow.
**Finding:** Newcomers must find these by file name. `game/state/` alone has about 70 classes.
**Suggestion:** Add a "Subsystems" section with one short paragraph per item (what it owns,
the entry class, its data file, its test file), or a class map table.
Decision: _(keep / change / drop)_

### D25. No table of save versions

**Where:** `game/state/save_file.gd` (VERSION 15, 14 upgrade steps); SPEC and TASKS mention
versions 7 to 15 in many places (D8); architecture.md "Saving".
**Finding:** What each version changed can only be found by reading the code or searching the
tasks.
**Suggestion:** A table in architecture.md "Saving": version | task | what changed | test
file. It is also the place to say that save changes are checked on a copy of the user's
real save (as the tasks report).
Decision: _(keep / change / drop)_

### D26. No statement of which doc owns what

**Where:** SPEC.md line 5 ("the single source of truth for what the game is"); README.md line
386 ("Design: the design is in SPEC.md"); architecture.md lines 3-4; art-style.md lines 3-5.
**Finding:** Only SPEC claims ownership, and it is not true for everything: art rules are in
both SPEC and art-style.md, tuning numbers are in `data/*.cfg` and in SPEC prose, keys are in
`project.godot`, README and SPEC, building costs in five files.
**Suggestion:** A table in AGENTS.md (or README for developers): what | source of truth |
others only link. Proposal: numbers -> `data/*.cfg`; keys -> `project.godot`; design
decisions -> SPEC; art look -> art-style.md; how the code is built -> architecture.md; open
work -> TASKS.md; finished work -> tasks-done.md; user questions -> QUESTIONS.md; the
player's view -> README.
Decision: _(keep / change / drop)_

### D27. No overview of the data files

**Where:** `data/*.cfg` (16 files); architecture.md "Data files and how to add content".
**Finding:** Each file has a good header comment, but nothing lists which files exist, which
rules class reads each, and what it tunes. `vegetation.cfg` has no `_rules` file (said in
passing). `weather.cfg` and `flowers.cfg` are not checked at start (D7).
**Suggestion:** A table in architecture.md: file | class | what it tunes | checked at start.
It also settles D6.
Decision: _(keep / change / drop)_

### D28. The length of a game day in real time is not documented

**Where:** `game/scenes/main.gd` line 15 (1.5 game minutes per real second: a day is 16 real
minutes, a 120-day year about 32 hours); nowhere in README or SPEC.
**Finding:** A basic number for balance, and for the "tune in play" numbers in SPEC.
**Suggestion:** One sentence in SPEC "Calendar" and one in README "Day, night and light".
Decision: _(keep / change / drop)_

### D29. README has no section on the ambient wildlife

**Where:** README.md "Features". Birds, flocks, rabbits, squirrels, deer, bees and butterflies
(SPEC "Ambient wildlife") appear only as sounds, bees in the flower paragraph, and in the
console table.
**Finding:** Wildlife is a visible feature, and the README is meant to list what works.
**Suggestion:** A short "Wildlife" paragraph next to "Livestock", with a screenshot (the
`--wildlife=` flag makes one).
Decision: _(keep / change / drop)_

### D30. How the screenshots were made is not recorded

**Where:** docs/screenshots (24 files); README "make screenshot"; TASKS "Screenshot: ..."
lines.
**Finding:** Each picture needs a command (`AT`, `TIME`, `ARGS`, a day, flags). Without a list,
every refresh is guesswork, and the rule "update README and screenshots with every merged
feature" depends on it.
**Suggestion:** `docs/screenshots/README.md` with one line per picture: its exact `make
screenshot` command, and which are composites. A `make screenshots` target could be a later
task.
Decision: _(keep / change / drop)_

### D31. architecture.md lists three test base classes; there are more

**Where:** docs/architecture.md lines 150-158 (`ResourceCase`, `EnergyCase`, `CropCase`);
`tests/` also has `save_upgrade_case.gd` and `hotbar_hold.gd`; the `save_file.gd` header
(step 4) tells you to add a save upgrade test.
**Finding:** The list is incomplete, and the helper every save change needs is not named.
**Suggestion:** Add `SaveUpgradeCase` and `HotbarHold` to the list.
Decision: _(keep / change / drop)_

### D32. Debug flags can't be passed to `make run`, and the docs don't say what to do instead

**Where:** README "Running the game" (only `godot --path . -- --new-game`); architecture.md
"Debug flags" ("Pass them to `make screenshot` with `ARGS=`"); the Makefile `run` target
takes no ARGS.
**Finding:** To play with a flag (a day, a weather) the way is `godot --path . -- --day=45`,
shown only for `--new-game`.
**Suggestion:** One line in architecture.md "Debug flags" with that command, or a Makefile
task to let `make run ARGS=...` pass them.
Decision: _(keep / change / drop)_

### D33. Pigs and geese of art-style item 8 are in no task, and task 60 is partly done

**Where:** docs/art-style.md "Bigger items" 8 ("Still to do: storks, geese, pigs, horses");
TASKS.md tasks 60, 79, 80.
**Finding:** Task 60 still reads "red-brown cattle and sheep (on dykes and pasture)", which
task 73 drew as livestock. Horses go to task 79. Geese and pigs are in no task. The chain
60 -> 80 -> 82 and 79 -> 81 -> 82 is spread over four task texts.
**Suggestion:** Rewrite task 60 as "storks and geese; livestock on the dykes", add pigs to
"Later", and put the dependencies in one line above the open tasks.
Decision: _(keep / change / drop)_

### D34. No single "known gaps" list for what is built but incomplete

**Where:** TASKS "Done:" paragraphs end with "Not done: ..." (task 73: animals don't avoid
each other; 74: no look for a firing kiln, no live refresh; 75: meadowsweet; 77: no mud in
rain); SPEC has "Not yet" (Professions) and "Later" (Livestock).
**Finding:** The honest list of open edges is spread over six task paragraphs and SPEC.
**Suggestion:** Collect them under a "Known gaps" heading in TASKS.md, one bullet each with
the task number.
Decision: _(keep / change / drop)_

---

## 4. Structure and source of truth

### D35. SPEC.md is 1165 lines and mixes five kinds of text

**Where:** SPEC.md as a whole. Examples: the hall house, thatch and window-pane paragraphs in
"Building and land" are art descriptions; "Flowering meadows" and "Desire paths" sit under
"Art pipeline" (lines 107-132) though they are world rules; tree facts are in four sections
("Lighting and look", "Time, seasons and weather", "Resources", "World"); "As built (task
51)" and "decided ... changed ..." layers make it a log.
**Finding:** The file is both a design document and a changelog. The vision is 30 lines and
the rest is detail; the intended design is hard to read apart from the history.
**Suggestion:** Keep SPEC to decisions (what and why, with numbers as links to `data/*.cfg`).
Move picture descriptions to art-style.md and "as built" text to tasks-done.md. At least
move desire paths and flowering meadows to "World" or "Time and seasons", and gather the
tree facts under one "Trees" subsection.
Decision: _(keep / change / drop)_

### D36. No built / planned marker on SPEC decisions

**Where:** SPEC.md "Decided" sections: Combat (line 818), Reputation (line 1049), "Weather and
seasons change the map" (line 577), "Defence" (line 933), "Buildings are presets with
customisation" (line 940), tool upgrades by a smith (line 320).
**Finding:** "Decided" holds what exists (energy, crafting) and what is only intended (combat,
reputation, floods, smith upgrades, attachment points). Nothing in the text marks which.
**Suggestion:** Add `[built]`, `[partly]` or `[planned]` to each bold lead-in, or split each
section into "Built" and "Planned". The README status line can then follow from it.
Decision: _(keep / change / drop)_

### D37. The same facts live in many files and will drift

**Where:** The hall house is in README, SPEC (three places), TASKS 59, art-style item 7,
QUESTIONS 18 and `data/buildings.cfg`; building costs in five files; the skill rules in SPEC,
TASKS 74, QUESTIONS 15, README and `data/skills.cfg`; desire paths in README, SPEC (two
places), TASKS 77, QUESTIONS 17 and `data/paths.cfg`.
**Finding:** Drift has already happened (D1, D3, D4, D11). A tuning change touches up to five
files.
**Suggestion:** One place for numbers (the data file); the others say "see `data/x.cfg`".
README says what the player sees; tasks-done says what was done; neither restates design.
Decision: _(keep / change / drop)_

### D38. TASKS.md is a log, a task list and a backlog in one file

**Where:** TASKS.md (743 lines): tasks 52-82 with long "Done:" paragraphs, then 100 lines of
"Later" notes from old reviews (tasks 3, 6, 14, 15, 16, 29, 33, 35).
**Finding:** The open work (tasks 60-62 and 79-82) is a small part. Tasks 52-78 are finished
and carry as much text as tasks 1-51 did before they moved.
**Suggestion:** Move 52-78 to `docs/tasks-done.md` (numbers stay valid, as for 1-51) and split
"Later" into "Known issues" and "Ideas". TASKS.md then holds the rules and the open list.
Decision: _(keep / change / drop)_

### D39. art-style.md "Changes to make" is now mostly a record

**Where:** docs/art-style.md lines 312-419 (quick wins "kept here as the record of why";
bigger items 1-7 struck through with long "Now: ..." paragraphs); TASKS tasks 52-62 say
"bigger item N". Item numbers (1-10) and task numbers (52-62) are two sets.
**Finding:** The second half of the guide is history that SPEC and tasks-done already hold.
The open items (8, 9, 10) are three entries among about 100 lines.
**Suggestion:** Keep in art-style.md only the open items and the "Still to do:" bullets of
finished ones; move the records to tasks-done. Put the task number next to each item
("item 8 -> task 60").
Decision: _(keep / change / drop)_

### D40. docs/ has no index, and SPEC points into the archive for numbers

**Where:** SPEC.md line 316 (scale numbers "in `docs/archive/art-review-2026-11-05.md`");
docs/art-style.md line 247 ("this guide is the current word"); no `docs/README.md`.
**Finding:** A live doc relies on an archived one for numbers (character height, tree scale).
The docs folder has several kinds of file and no map.
**Suggestion:** Copy the scale numbers into art-style.md and drop the SPEC link. Add a
`docs/README.md`: one line per file with purpose and "live" or "history" (including
`docs/review/` and `docs/ideas/`).
Decision: _(keep / change / drop)_

### D41. README is long (388 lines) and carries design and art detail

**Where:** README.md "A world that changes with the seasons" (lines 32-70) and "Build
anywhere" (lines 156-190): tree species, flower names, thatch and gable details.
**Finding:** The first screen is good; the middle repeats SPEC and art-style.md (D37).
**Suggestion:** Shorten each feature to 3-5 sentences, keep the screenshots, and link to the
SPEC section for the rest.
Decision: _(keep / change / drop)_

---

## 5. Terminology

### D42. Bedroll, sleeping bag, sleeping mat

**Where:** README says "bedroll" (line 223). SPEC says "bedroll" in "Starting shelter" and
"sleeping bag" at lines 228, 262 and 1142 ("Sleeping in the sleeping bag"); ids:
`data/energy.cfg` `sleeping_bag`, `WorldObjectTypes.SLEEPING_BAG`, `camp.sleeping_bag_pos`;
`startup_options.gd` ("beside the sleeping bag").
**Finding:** It is a bedroll in the game and a sleeping bag in the id. SPEC says the id stays,
which is fine, but the prose still says "sleeping bag".
**Suggestion:** "Bedroll" in all prose (SPEC lines 228, 262, 749, 1142; the flag header). The
id `sleeping_bag` appears only in code font, with a note in the glossary (D49).
Decision: _(keep / change / drop)_

### D43. Logs and wood, reeds and reed

**Where:** SPEC.md "Harvesting, reworked" ("the item `wood` becomes `logs`"); QUESTIONS 18
("100 wood ... 80 reed"); everywhere else "logs" and "reeds"; `buildings.cfg` `cost_logs`,
`cost_reeds`.
**Finding:** Only QUESTIONS uses the old words.
**Suggestion:** Use item names (logs, stone, clay, reeds) in every doc. See D11.
Decision: _(keep / change / drop)_

### D44. Profession, craft, skill

**Where:** README "Crafting and professions" ("Three crafts can be learnt"); SPEC
"Professions" ("Each craft has a skill ..."); code `Skills`, `SkillRules`; UI "skills tab";
the ideas doc says "profession".
**Finding:** Three words for one thing.
**Suggestion:** "Skill" in UI and code, "craft" in prose (woodworking, cooking, masonry),
"profession" only as a section name. Say so once in SPEC.
Decision: _(keep / change / drop)_

### D45. Oven, bake oven, hearth

**Where:** README ("the hearth of a house or the camp's fire ... and the bake oven"); SPEC
Professions ("the house hearth and the camp's fire are the hearth station", later "the
oven"); TASKS 74 ("oven"); `data/stations.cfg`.
**Finding:** "Oven" and "bake oven" name one station. "Hearth" is both a station and a piece
of furniture (the open hearth of the interiors).
**Suggestion:** "Bake oven" for the oven, "hearth station" for the cooking place where the
distinction matters; ids unchanged.
Decision: _(keep / change / drop)_

### D46. Inventory, backpack, hotbar, character screen

**Where:** README "Character, inventory and equipment"; SPEC ("inventory screen", "character
screen"); flag `--inventory` ("open the character screen"); action `inventory` (Tab).
**Finding:** "Inventory" means the backpack, or backpack plus hotbar, or the Tab screen. The
flag and the action are called `inventory`, the screen "character screen".
**Suggestion:** Define once: "inventory = backpack (20 slots) + hotbar (8); the character
screen (Tab) shows it with the equipment". Use these words everywhere.
Decision: _(keep / change / drop)_

### D47. Task numbers as the subject of sentences in SPEC

**Where:** SPEC.md has about 30 mentions of "task N" (e.g. "Task 74, decided by the user"; "As
built (task 51)"); the README has none.
**Finding:** Useful for history, meaningless to a reader of the design.
**Suggestion:** Keep a task number only as a trailing "(task N)", never as the subject.
Decision: _(keep / change / drop)_

### D48. Wildlife and livestock share one folder and one view

**Where:** README "Livestock" and the console table (farm animals vs wild ones); SPEC "Ambient
wildlife" and "Livestock"; code: `FarmAnimal` and `Livestock` in `game/state/`,
`FarmAnimalView` and `WildlifeView` in `game/scenes/wildlife/`; `data/wildlife.cfg` and
`data/livestock.cfg` both have a `[rabbit]`.
**Finding:** The docs keep the two apart; the scene code puts both under "wildlife". A
newcomer looks for livestock drawing in a livestock folder.
**Suggestion:** One line in architecture.md: "`game/scenes/wildlife/` draws both the wild
animals and the livestock (`farm_animal_view.gd`)". Renaming the folder is optional.
Decision: _(keep / change / drop)_

### D49. No glossary of the setting's words

**Where:** README and SPEC use Knick, Geest, marsh, Kate, Diele, Flett, Grote Door, Uhlenloch,
Durk, Alkoven, Bilegger, Warft, Ewer, Haubarg, dyke, Fething. art-style.md explains most of
them in passing.
**Finding:** No page defines them for a reader who doesn't know Schleswig-Holstein. German and
English words alternate (Knick or hedge, Kate or cottage).
**Suggestion:** A short glossary in art-style.md: term | meaning | in-game name. Rule: the
German word in italics at first use, then the game's name. Include the bedroll and the terms
of D42 to D46.
Decision: _(keep / change / drop)_

### D50. Spelling and naming conventions are not written down

**Where:** docs use British spelling ("colour", "grey"); code identifiers use "color"
(`UiColors.BACKDROP`, the `color` key of `window_light`); task 71 settled this in code only.
Docs also write `hall house` and `hall_house`, `Kate` and `kate`.
**Finding:** Not wrong, but undocumented.
**Suggestion:** One line in TASKS "Rules for every task" (or AGENTS.md): prose uses British
spelling, identifiers use the Godot spelling; a name in backticks is an id, a name in plain
text is the display name.
Decision: _(keep / change / drop)_
