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

## 62. Post mill

- [ ] Done

docs/art-style.md bigger item 10: a post mill as a landmark prop, placed by the world generator
near settlements or on rises. (The draw well is part of task 122.)

## 122. The farm yard: chicken coop, trough, hay rack and draw well

- [ ] Done

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

## 125. The deed log: what the player does near villagers, and who saw it

- [ ] Done

The deeds come from the action outcomes of task 143: listen to `GameState.action_done` (see
game/state/action_outcome.gd; a hammer take-down is `take_down` for a placed object and
`demolish` for a building).

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
- Reuse what exists: ThoughtBubble (game/scenes/thought_bubble.gd, the player's icon bubbles)
  for the look, NpcMoment (game/state/npc_moment.gd) for the weather and part of the day.
- About the moment (weather, part of the day, the place, what they do), or about the player when
  near, with their opinion and newest stories.
- Asked of the model in the background with the chat's temperature (task 124), dropped if the
  villager is out of view when it comes; without a model, scripted lines per weather and part of
  the day in data/npc_talk.cfg.
- Not saved, not remembered. Bubbles drawn in palette colours, readable at every zoom; a
  screenshot in the README.

## 149. Harvesting works, and dead plants are hoed away for the next crop

- [ ] Done

The user, 2026-11-09: "make sure plants can get harvested and dead plants can be hoed away to
prep the soil for the next produce".
- Already there (tasks review, 2026-11-09): the empty hand harvests a ripe crop and clears a dead
  one, which leaves tilled soil (tool_use.gd); every crop ripens (test_crops.gd). The hoe only
  tills free grass and the scythe only mows, so neither clears a dead crop.
- The hoe clears a dead crop too (and decide with the user whether the scythe should): the tile
  is tilled soil again, ready to plant. Say what the player gets from it (nothing, or a little).
- Tests: each crop of the crop data harvested through a use when ripe, and what the player gets;
  a cleared tile (by hand and by hoe) can be planted, also after save and load.

## 152. Storks nest on roofs and raise their young

- [ ] Done

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

## 158. Frame spikes left after task 147: the save snapshot, the bed's save, the pass-out

- [ ] Done

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

## 159. Cows at 32 px: a neck, the udder between the legs, legs from the body

- [ ] Done

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

## Later (not part of the prototype)

- **Review R8: what is left** (review F2.4/F2.5, A4, package R8; the simulation and its time are
  done, task 154): hunting moves out of FarmAnimalView, chunk residency is decided apart from
  drawing, PlayerView stops setting the held layer every frame, and the wildlife rules stop being
  mutated per session. Large; in small commits.

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

- Season looks follow-ups (from the task 29 review): SeasonBlend `_season_look` indexes the
  shares by hand, a loop would do (`conditions()` already loops); `frost_at` belongs with the
  season rules, not SnowCover. SnowCover's cold start (~80 ms for a fresh region in late winter) could be
  spread over frames. Snow cover of the player's region is applied to the whole loaded
  world for now.

- Split the object edits (`_object_edits`, `replace_object`, `hit_object`, `change_object`,
  `take_off`) out of `World` into their own class with their own tests, and drop the
  `max-public-methods` lint exception in world.gd (the regrowth is in NightUpkeep already).
- Edits of objects that are back to their generated state (a healed tree, a mown tuft that
  regrew) stay in the save forever; drop them. Harmless, bounded by what the player touched.
- Ground items (task 33 review): a pile that falls back onto a non-walkable source may be out of
  reach (`_scatter_tiles` returns the source). A pulled pile moves straight through walls and
  water (the pull reaches 1.25 tiles since 2026-11-05).
- Use (swing) poses for the axe, pickaxe, scythe and shovel; the held art is done (task 119).
- The shovel could later dig up a young sapling to move it.

- Floodplain farming: floodplain is the most fertile farmland, but only grass can be tilled
  now. Tilling it needs a "tilled" tile property that keeps the floodplain flag, so floods
  can still act on it.

Art notes (reviewed 2026-11-09; the rest was redone by tasks 101 to 119):

- The late-evening tint (DAY to DUSK_GLOW, day_night_tint.gd) over green grass reads olive
  rather than warm; check at the sunset hour of summer and autumn. Also check the player's face
  at 20:30 to 22:00 next to the fire (an old note said it turns pink at night).
- Lush and dry grass looked blotchy (dry has its own yellower colours since task 107); keep only
  if a fresh screenshot still shows it.
- tools/art/terrain.py: `brown_caps` is defined twice (and twice in classic/terrain.py); make it
  one module-level sprite. Add `canvas.size(picture)` for the repeated
  `len(picture), len(picture[0])`.
- A test that `_unload_chunk` leaves the decoration cells empty (redrawing is tested by the path
  tests).
- A grass tuft can stay under a boulder's right half at the load frontier (hidden): after a chunk
  loads, recheck the decorations under its objects' tiles that reach into loaded right or bottom
  neighbours.
- `World.add_chunk` replay removes a generated object only at the origin tile of a replayed
  multi-tile object, not at the other tiles it covers.

Saving notes from the task 15 review:

- Ctrl-C/SIGTERM doesn't save; only play since the last autosave (or quick save) is lost.
- `--new-game` without `--save-path` replaces the real save at the first autosave or on quit
  (intended); `make screenshot` uses build/screenshot.save, so test runs never touch it.

See-through notes from the task 14 review:

- A swapped sprite may change draw order against a same-row neighbour tree (small pop): walk
  behind a tree with a neighbour in the same row to see it.

World generation notes from the task 3 review:

- The river is measured by vertical distance to its centre line, so it gets thin (about
  2 tiles) in steep bends. Use perpendicular distance, or a smaller meander.
- The noise seeds use offsets 1 to 18 from the world seed (the wetland's `seed + 1` equals the
  river noise of the next seed; its comment says "independent"), so every noise collides with
  another noise of a nearby seed. Give them large distinct offsets. This changes every world:
  it needs a world version note.

Still missing from the old feature list: combat, reputation (see tasks 125 to 128 and the
relationship system), building expansions, more distinct biomes.
