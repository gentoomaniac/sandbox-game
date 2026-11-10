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

## 165. Pigs, and pig pens the player builds

- [ ] Done

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

## 166. Tilled soil that isn't used grows back over

- [ ] Done

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

## 167. Watered soil fades out at its edge to dry soil

- [ ] Done

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

## 169. Music: can the game play generated modules? Measurements and viability tests

- [ ] Done

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

## 170. Music: the game plays the modules (after 169's decision)

- [ ] Done

To be rewritten from task 169's report with the user. The plan so far: render sections in the
background with a bounded cache (user:// keyed by the module hash, renderer version and mix
settings), never wait for a late render during play (keep looping), sections with explicit
entry state, tempo, meter, loop points and allowed exits.

## 171. Music: what plays when, with loops, transitions and crossfades

- [ ] Done

After task 170. A music director (a scene service) loops a section, plays a fill now and then
and returns on the bar, switches between two loops (later by time of day, season, weather,
indoors) with a minimum time before switching again. A "music" bus with its own slider in
Settings (and off), muted in test runs. Rules in data/music.cfg; tests; README. Later: stems
(AudioStreamSynchronized), more pieces, the season and weather choices.

## Later (not part of the prototype)

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

- **A windmill to build** (the user, 2026-11-10, replacing task 62, a post mill as a landmark
  prop placed by the world generator): the player builds a windmill as a building and grinds
  grain into flour there (the flour recipe moves from the oven to the mill). Art notes on the post
  mill are in docs/art-style.md (Mills, bigger item 10) and review/art-review-2026-11-08 (item 4).

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
