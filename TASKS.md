# Tasks: Prototype

Implements milestone 1 from the [design](design/README.md). Each task is small enough for one
developer brief. Tasks whose dependencies are done can run in parallel. This file holds only the
open tasks and the later ideas: when a task is merged, it is ticked, given its "Done:" note and
moved with its full text to [docs/tasks-done.md](docs/tasks-done.md) (the user, 2026-11-09).

SPEC.md became the [design/](design/README.md) tree on 2026-11-08. Old task notes below that say
"SPEC" mean those pages; "SPEC.md" and its section names are history.

Finished tasks live in [docs/tasks-done.md](docs/tasks-done.md). Their numbers still mean the
same: the design and code comments refer to them.

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

## 62. Post mill and draw well

- [ ] Done

docs/art-style.md bigger item 10: a post mill and a draw well as landmark props, placed by
the world generator near settlements or on rises.

## 87. Willows that stand out from the grass

Dropped as a task (the user, 2026-11-07): kept as a point for the next graphics review, see
Later.

## 122. The farm yard: chicken coop, trough, hay rack, draw well and stork's nest

- [ ] Done

From review/art-review-2026-11-08 (its task 6 and buildings rows 1 to 3 and 16), left out of
task 111 because each needs game data as well as art: a chicken coop (a building 2x2, low and
boarded, a ramp with cleats to a hatch, a nest-box lid; the hens sleep in it and the eggs are
collected there; an interior map), a trough (a hollowed oak log or a plank box with water) and a
hay rack (oak posts with slanting slats, hay behind them), 2x1 world objects that feed and water
the livestock (SPEC, Livestock), a draw well with a sweep (1x1 plus the sweep above it: an oak
well head on a fieldstone ring, a forked post, the balanced pole, the bucket and a weight stone;
water for the can, the animals and the house) and a stork's nest on a roof ridge (the
`roof_stork` standing in it). Draw them at 32 px in the style of task 111 (tools/art/, a new
yard.py), give them types, recipes and placement (data/, world_object_types.gd), and decide
what each does for the animals.

## 123. Tilled soil: seamless, flat furrows, and its colour follows the moisture

- [ ] Done

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

## 125. The deed log: what the player does near villagers, and who saw it

- [ ] Done

Waits for the review tasks 139 to 143 (the user, 2026-11-09: review items first); the deeds
come from the action outcomes of task 143.

From design/villagers/gossip.md (Deeds). No language model in this task.
- A `data/gossip.cfg` with the deed kinds (felled a tree, built a building, took down a building,
  placed a fence or wall, tilled, sowed, harvested, dug clay, mowed), each with its words and a
  fixed opinion change for later, the radius (20 tiles, 6 at night) and the place words per biome.
- A deed log in the game state, saved (save version bump): each deed within 20 tiles of any
  villager as `{day, minute, kind, count, place, witnesses}`; the same kind and place on the
  same day merge, adding up the count and the witnesses. Kept for 7 days.
- The place in words: "by <name>'s house" for the villager whose home is nearest within 20 tiles,
  else the biome's word.
- Every villager within the radius is a witness and gets the deed as a story they saw at once,
  for now kept in a plain list on the villager (task 126 makes it the gossip buffer). The chat
  prompt tells it as a template line ("Today you saw the newcomer fell 7 trees by Antje's house.").
- Console: `deeds` lists the log.
- Tests: logging, merging, witnesses by radius and night, the place words, save and load.

## 126. Villager memory in three layers: knowledge, short-term, long-term

- [ ] Done

From design/villagers/gossip.md (Memory). Needs 125.
- Knowledge: the sheet, and the village sheet for villagers of data/villagers.cfg (as today).
- Short-term: the chat buffer (`chat_history`, as today) and a gossip buffer of stories (the
  witnessed deeds of 125; a story as on the design page: fact, seen or heard, told_by, seen_by,
  hops, day learned, line, weight, personal), both first in, first out.
- Long-term: memories become `{day, text, weight}` (low, medium, high). Full: the lightest goes,
  between equal weights the oldest. This replaces the merge of the oldest two.
- Leaving the chat buffer: summed up as today, weight medium. Leaving the gossip buffer: low is
  forgotten, else the line moves to long-term with its weight. High: a deed by their own home or
  that of family or friends on their sheet.
- Settings "Stories a villager keeps" (default 10) and "Memories a villager keeps" (default 20),
  next to "Lines a villager keeps".
- The prompt tells knowledge, long-term, gossip and chat in that order; `/clear` forgets all but
  knowledge.
- Save version bump; old memories load as medium.
- Console: `gossip <villager>` lists their stories and memories with weights.
- Tests for the buffers, eviction by weight, save and upgrade; docs in dialogue.md.

## 127. Rumours spread when villagers meet, and change on the way

- [ ] Done

From design/villagers/gossip.md (How stories spread, Whispers). Needs 126. No language model.
- Two villagers within 3 tiles meet, a pair at most once an hour of game time. Each may pass one
  story the other lacks: the weightiest and newest that it has known for at least 2 game hours,
  with a chance by tie (family and friends from the sheet, the 3 nearest neighbours by anchor,
  anyone), values in data/gossip.cfg. The hearer gets it as heard, `told_by` the teller, one hop
  more. A deed's story stops after 3 hops or 7 days.
- Whispers: at each hop a chance (10%) that one thing shifts: the count grows by a table of steps
  ("a dozen", "half a wood"), the place moves to a neighbouring house, or the kind turns into a
  similar one (a table). Seeded, so tests can fix it.
- The template line for heard stories names the teller ("Moiken told me ...").
- Works for all loaded villagers (the moment they come into view or not), not only the ones on
  screen.
- Tests: meetings, chances by tie, the 2-hour wait, the stop, whispers with fixed seeds, saving.

## 128. The judge: villagers word what they saw and heard, and think of the player by it

- [ ] Done

From design/villagers/gossip.md (The judge). Needs 127.
- A background queue, saved, of stories without a voiced line. One call at a time (like the
  memory summary), its prompt in data/npc_talk.cfg with a low temperature of its own: the
  villager's sheet (cut down for a local model), the fact, who told them. It returns JSON
  `{line, change, personal}`; anything that doesn't parse, is out of range or doesn't come is
  the template line, the deed's fixed change and not personal.
- Opinion of the player per villager, saved: one change step is 10 friendship points of
  design/villagers/relationships.md; full for who saw it, half for who heard it; a daily cap in
  data/gossip.cfg. Personal raises the story to high weight.
- The chat prompt tells the opinion in words (the levels of relationships.md, or a plain
  warm/neutral/cold until those are decided).
- Console: `opinion <villager> [points]`.
- Tests with a fake model: parsing, fallbacks, caps, the queue across save and load.

## 129. Newcomers learn the village from the locals

- [ ] Done

From design/villagers/gossip.md (Locals and newcomers). Needs 127.
- Made-up villagers start with no village sheet, only its base line (Wehlsbüll, the North
  Frisian coast, 1750). The sections of data/village.cfg are topics; a villager who knows a topic
  passes it at a meeting as a story, like a deed, with no hops limit and no whispers.
- A learned topic goes into knowledge and is never forgotten; the prompt carries only the topics
  a villager knows (full or cut down by provider, as today).
- Saved (version bump): made-up villagers of older saves start with no topics.
- Tests: learning, the prompt, saving. Docs in villagers.md.

## 130. Bubbles: villagers say a line now and then

- [ ] Done

From design/villagers/gossip.md (Bubbles). Needs 128 for lines about the player; the rest can
come earlier.
- Now and then a villager in view says a short line in a bubble over their head for a few
  seconds: at most one on screen and about one a minute (data file).
- About the moment (weather, part of the day, the place, what they do), or about the player when
  near, with their opinion and newest stories.
- Asked of the model in the background with the chat's temperature (task 124), dropped if the
  villager is out of view when it comes; without a model, scripted lines per weather and part of
  the day in data/npc_talk.cfg.
- Not saved, not remembered. Bubbles drawn in palette colours, readable at every zoom; a
  screenshot in the README.

## 140. Review R2: a broken save is caught before it becomes the game; a failed save says so

- [ ] Done

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

## 143. Review R6: player actions are checked where they are done, and say what happened

- [ ] Done

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

## 147. Frame spikes: find and smooth the long frames

- [ ] Done

The user, 2026-11-09: once all current tasks are done. After task 142 the mean frame on the
`make bench` save is about 8 ms, but single frames still take 120 to 190 ms (before 142 too).
- Find what the long frames do (chunk loading and drawing in WorldView, villager or wildlife
  updates, autosave, GC of big arrays): Godot's profiler or timing around the suspects, on the
  bench save and while walking across chunk borders.
- Spread the heavy work over frames (a budget per frame, or a worker thread for pure data) so no
  frame goes over about 33 ms on the bench save; same pictures, same game.
- `make bench` reports the longest frame and how many frames went over 33 ms, before and after.

## 148. The ambience test is flaky: seed its wildlife

- [ ] Done

`tests/test_ambience_sounds.gd` sometimes fails because the wildlife it runs isn't seeded (an
extra `frog_croak`). Give the test a fixed seed, or count only the sounds it asserts about, so it
passes every run; no game change.

## 149. Harvesting works, and dead plants are hoed away for the next crop

- [ ] Done

The user, 2026-11-09: "make sure plants can get harvested and dead plants can be hoed away to
prep the soil for the next produce".
- Check every crop can be harvested when ripe (each crop of the crop data, in every season it
  grows), and what the player gets; fix what doesn't work.
- A withered or dead crop (frost, drought, past its season, see the crop withering rules) can be
  cleared with the hoe: the tile is tilled soil again, ready to plant, with no dead plant left.
  Say what the player gets from it (nothing, or a little), and whether the scythe or the hand also
  clear it.
- Tests: harvest of each crop, hoeing a dead crop gives plantable tilled soil, saved and loaded.

## 150. The test LLM finds the GPU by itself: NVIDIA or AMD

- [ ] Done

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

## Later (not part of the prototype)

- **Review R8: one owner for the simulation, its time and what is loaded** (review F2.4/F2.5, A4,
  package R8): hunting moves out of FarmAnimalView, the simulation and its time advance in one
  place with one catch-up rule, chunk residency is decided apart from drawing, and PlayerView stops
  setting the held layer every frame. Large; in small commits, after tasks 141 to 143.

- **A relationship system** (the user, 2026-11-08): friendship levels per villager, like Stardew
  Valley, but actions count as well as gifts, in the manner of the Sims (helping, talking,
  events, rudeness, theft, being there in trouble). A first draft is in
  [design/villagers/relationships.md](design/villagers/relationships.md), planned and not
  decided. Plan with the user (its open questions are in QUESTIONS.md), then split into tasks.

- **Economy and currency** (the user, 2026-11-08): small trades with villagers, shops that buy and
  sell for money, and the player's own little stall where villagers occasionally buy produce and
  goods. A first draft is in [design/economy/README.md](design/economy/README.md), planned and
  not decided. Plan with the user (its open questions are in QUESTIONS.md), then split into
  tasks. It also settles where seeds come from once shops exist.

- `WildlifeSprites.frame_index` and `max_frames` allocate on every call (`keys()`,
  `values().max()`); the older animals call them per frame. Cache them per sheet. And rename
  `SoundEvents.animal_alarm`, which since task 60 also gives the stork's clatter, to something
  like `animal_state_sound`.
- A committed pixel guard (a GUT test hashing the tile cells, sprites and lights for a fixed seed
  and a few days) would catch silent rendering changes in refactors like task 70; left out while
  the art tasks change the pictures on purpose, as its golden value would need updating each time.

- World keeps its `max-public-methods` lint exception after task 68 (chunks, objects, soil,
  buildings and clay share the same edits). Getting under 20 would take one more split, most
  likely buildings and their placement rules.

- Season looks follow-ups (from the task 29 review): SeasonBlend's four boundaries
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
  through walls and water (the pull reaches 1.25 tiles since 2026-11-05).
- Task 35 review: time a chunk load with the clay probe and hint layer against the ~14 ms
  baseline; a mown tuft stays an object edit forever after it regrew (drop edits that are
  back to their generated state); ResourceCase `_hold` could just select a hotbar slot.
- Held art and use poses for axe, pickaxe, scythe and shovel.
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

- Pines read as olive-brown blobs with stubby trunks inside forests (redrawn in task 51).
- The sleeping bag (1×2, vertical) reads like an upright sign behind the player; it should
  look flat on the ground. The character's face turns slightly pink at night.
- Seed mound and sprout stages are plain; the hoe is a thin stick from front/back.
- A grass tuft can stay under a boulder's right half at the load frontier (hidden).
- Saves from before 16a put the 1×1 bag where the new spawn is; `add_chunk` replay checks
  only the origin tile of multi-tile objects.
- Interior: the table reads like a chest, the chest is hard to identify, the bed is flat,
  the floor boards are very high contrast.

Saving notes from the task 15 review:

- Only closing the window saves; Ctrl-C/SIGTERM doesn't.
- `--new-game` without `--save-path` replaces the real save on quit (intended); `make screenshot`
  uses build/screenshot.save, so test runs never touch it.

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
