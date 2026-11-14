Tasks done up to 2026-11-14. Later ones are closed issues on the [project board](https://github.com/users/gentoomaniac/projects/2).



## 223. Birds taking off from the ground are seen from the front or behind too

- [x] Done

Done: 2026-11-13. FlightView (game/scenes/wildlife/flight_view.gd) holds the side, front and back
views and the head-on rule (45 degrees), shared by Flock, GroundFlock and Bird. Geese flying off
the marsh (GroundFlock) and sparrows taking off (Bird) pick the view from their flight direction,
unflipped head on; a sheet without the rows (oystercatcher, dunlin, gull, stork) keeps the side
view. The view is chosen at take-off and re-chosen only while a flock wheels. No new art.

The user, 2026-11-13, after task 220: birds taking off from the ground should get the new views
too.
- Task 220 gave the sky flocks (Flock) `fly_down` and `fly_up` rows for the sparrow and goose
  sheets and `Flock.view_of(heading)` (within HEAD_ON_DEGREES of the vertical: front or back,
  unflipped). Ground flocks (GroundFlock, game/scenes/wildlife/ground_flock.gd: sparrows,
  greylag geese and any other ground flock) still fly off with the side view, flipped by
  `_flight_direction.x`.
- Use the same rule for a ground flock's flight (take-off, flying away, landing if it lands
  flying): pick the view from the flight direction with `Flock.view_of` (move it to a shared
  place if that reads better), unflipped head on; the side view as today otherwise. Other single
  birds that fly (gulls, storks, the Bird class) if they share the sheets or have a fly row: say
  which, and give them the same rule only where art exists (no new art in this task unless a kind
  clearly needs it: say so).
- Tests: the view per flight direction around the compass for a ground flock; screenshots of a
  flock taking off upwards and downwards in both arts.

## 125. The deed log: what the player does near villagers, and who saw it

- [x] Done

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

Done: f6be06e6. Nine deed kinds in data/gossip.cfg; witnesses within 20 tiles by day, 6 at night; kept 7 days, pruned on record, new day and load; saved (version 34) in GameState.deeds and each villager's stories; the newest 5 stories are told in the chat prompt; console `deeds`. Not deeds: digging up a bush, taking down placed objects (only demolishing a building), anything indoors.

## 212. Wild rabbits flee even when asleep

- [x] Done

The user, 2026-11-11: "Wild rabbits should run away even when sleeping"
- Find out what the user saw: a wild rabbit (WildlifeRules RABBIT, `flee_tiles`) that rests or
  sleeps (by its phase weights at night, or a resting state) and then ignores the player, or the
  tame rabbit (a farm animal, task 173) asleep. Fix it so a sleeping or resting wild rabbit wakes
  and flees when the player comes within its flee distance (maybe a little closer than when
  awake: a startled jump first). Check the other wild ground animals (squirrel, deer, mouse, frog)
  for the same gap and give them the same rule if they have it. The tame rabbit and the farm
  animals keep sleeping (they are used to the player).
- Tests: a sleeping wild rabbit flees when the player comes near; a sleeping tame rabbit does
  not.

Done: closed without a change (the user, 2026-11-13): sleeping rabbits, wild or tame, keep sleeping.

## 222. Thunder with more variety, lightning that runs across the sky, a branching bolt

- [x] Done

The user, 2026-11-13, after task 214: "The thunder sounds could have a bit more variance, add a
sound that simulates a lightning running across the sky or add a tree rather than a straight
strike."
- More variance (a sound-designer job, tools/audio/weather.py): more variants of `thunder_far`,
  `thunder_mid` and `thunder_close` (today 3 each), differing more in length, rumble shape,
  number of rolls and pitch; seeded as today.
- Lightning running across the sky: a new kind of strike, the sky-crawler (cloud-to-cloud
  lightning): a long crackling, tearing rumble that travels, panned from one side to the other
  over a few seconds (a new sound `thunder_crawl` and a stereo pan or a moving positional
  source), with a flash that flickers along the sky rather than one burst. Its share among the
  strikes in data/weather.cfg [strike].
- A branching bolt: the close strike (and maybe the middle one) draws a bolt in the sky that
  forks like a tree, not a straight line: generated per strike (seeded), a bright core with
  thinner branches, shown for a few frames with the flash, in palette colours, crisp in both arts
  and at every zoom; cheap.
- Tests: the new strike kind's share and sound, the bolt drawn for close strikes only (and its
  branching), determinism. Listening files and screenshots of a bolt and a crawler for the user.

Done: 804b5dc6 and the earlier sound commits. More thunder variants, the sky-crawler (`thunder_crawl`, panned, flickering flash; the helicopter-like flutter removed after the user's listen), and a forking bolt for close strikes (a faint one for middle strikes), seeded, in palette colours (BoltImage), numbers in data/weather.cfg. The user: "good for now".

## 126. Villager memory in three layers: knowledge, short-term, long-term

- [x] Done

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

Done: 2ac0ae12..88329db6. Memories are {day, text, weight}; full: lightest, then oldest, goes. Stories carry the design's fields in a first in, first out buffer; leaving, a low story is forgotten, others become memories. A deed by the witness's own home or that of someone on their sheet is high, others medium; chat summaries medium. Settings "Stories a villager keeps" (10) and "Memories a villager keeps" (20), per language model profile. Stories no longer age out after 7 days (only the buffer evicts; the deed log keeps 7 days), so the prompt tells the whole buffer and `prompt_stories` is gone. Old memories load as medium, day 0. Save version 35 (the upgrade from 24 dropped). `/clear` forgets all but knowledge; console `gossip <villager>`.

## 127. Rumours spread when villagers meet, and change on the way

- [x] Done

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

Done: 0d2929b1..c978f1d2. GossipSpread (a SimulationSystem) lets every villager pair within 3 tiles meet at most once an hour; a story known 2 hours passes on with a chance by tie (0.8 family/friends, 0.5 one of the 3 nearest neighbours, 0.2 anyone), the weightiest then newest the hearer lacks (matched by its `origin`), as heard, low weight, one hop more; stops at 3 hops or a 7-day-old deed. Whispers (0.1): the count steps up a table, the place moves to a neighbour's house, or the kind turns similar; seeded. Heard lines name the teller. Numbers in data/gossip.cfg. The pair cooldown is not saved. Save version 36 (the upgrade from 25 dropped).

## 128. The judge: villagers word what they saw and heard, and think of the player by it

- [x] Done

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

Done: a12925c5..12c89851. Opinion per villager (saved, -100..1000), 10 points a step, half for heard, at most 20 net a day; told to the chat model as cold (< -20), neutral or warm (>= 20), plain words until relationships.md is decided. The queue is the stories not yet judged (`is_judged`, saved); StoryJudging asks the model one story at a time (temperature 0.2), quietly (no failure notice); bad or missing answers give the template line and the deed's fixed change; personal raises the story to high. Each story is judged once, on arrival (later merges of the same deed aren't). Console `opinion <villager> [points]`. Save version 37 (the upgrade from 26 dropped). Numbers in data/gossip.cfg and data/npc_talk.cfg.

## 129. Newcomers learn the village from the locals

- [x] Done

From design/villagers/gossip.md (Locals and newcomers). Needs 127.
- Made-up villagers start with no village sheet, only its base line (Wehlsbüll, the North
  Frisian coast, 1750). The sections of data/village.cfg are topics; a villager who knows a topic
  passes it at a meeting as a story, like a deed, with no hops limit and no whispers.
- A learned topic goes into knowledge and is never forgotten; the prompt carries only the topics
  a villager knows (full or cut down by provider, as today).
- Saved (version bump): made-up villagers of older saves start with no topics.
- Tests: learning, the prompt, saving. Docs in villagers.md.

Done: c99eddb7..37a6e274. `Npc.topics` (saved): villagers of data/villagers.cfg know every section of data/village.cfg, made-up ones none; the prompt tells only the known topics (the block is left out when none). At a meeting each villager may teach the other the first topic it lacks (chance 0.5, data/gossip.cfg); a topic is not a story: no buffer, no judge, no hops, no whispers, no wait, never forgotten. `gossip <villager>` lists the known topics. Save version 38 (the upgrade from 27 dropped).

## 130. Bubbles: villagers say a line now and then

- [x] Done

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

Done: ac491a9b..91a5a8a4. NpcBubbles (state) picks a villager in view (the whole bubble must fit) every 30-90 s of game time while no bubble shows, half the time about the player when within 6 tiles (opinion and the 2 newest stories), else about the weather or part of the day; asked of the model quietly at the chat temperature, max 60 characters, dropped if the villager left the view; without a model, scripted lines from data/npc_talk.cfg [bubble_lines]. The bubble (SpeechBubble, HUD layer, pixel font, cream on ink) shows 5 s, ends when the villager leaves the view or starts a chat, and covers the name tag meanwhile. Not saved. Debug flag `--bubbles` (a bubble at once).

## 170. Music: the game plays the everyday pieces, rendered in the background

- [x] Done

Rewritten with the user, 2026-11-13, from task 169's report (docs/music-viability.md).
- First measure how late MusicCrossfade starts on a real audio driver, silently (e.g. a muted bus
  with a capture effect before the mute); if it is late by more than a few tens of ms, start the
  crossfade a block earlier from a predicted position. Write the number into
  docs/music-viability.md.
- Render on a WorkerThreadPool thread (ModuleRenderer) into AudioStreamWAVs made whole there;
  never copy a stream on the main thread, never wait for a late render during play (keep looping
  what plays).
- A disk cache in user:// keyed by the module's hash, the renderer version and the mix settings
  (rate, channels), bounded in size (data/music.cfg), oldest dropped first; a broken or stale
  file is rendered again. Loading a cached render must not stall a frame either.
- Sections with their entry state, tempo, meter, loop points and allowed exits, read from the
  pieces.
- The everyday pieces "Tide" and "Harbour evening" (tools/music/pieces/sketch_tide.txt,
  sketch_harbour.txt; plain notes, held notes fading out) play on the Music bus (task 184): a
  piece loops a few times, then the other crossfades in on the beat (counts in data/music.cfg).
  Both art settings play the chiptune versions for now (two versions: task 224).
- Off in test runs (the Music bus is muted there); the console `play`/`stop` keep working.
- Known limitation from 169: MusicCrossfade counts a fade's progress across loop wraps from the
  time between audio mixes, so an audio thread held up and then mixing one block looks like a
  long stretch of play, and a fade into a short loop may end early by the hold-up
  (docs/music-viability.md, "Switching on the beat"). Fix it if the measurement shows it matters.
- Tests: the cache (hit, miss, stale, bound), never waiting for a render, the switch on the beat;
  README.

Done: up to 043c2845 (12 commits). Crossfade lateness on PulseAudio measured silently (`make music-latency`): scheduled 2-20 ms after the beat, new beats within a few ms of the old grid; no predicted start needed. Pieces carry beat, bar and section exits (the generator writes <name>.cfg). ModuleRenderer renders and loads on a worker through MusicCache (user://music_cache, key: module sha256, renderer version, mix settings; 64 MB, oldest written dropped; unique tmp files, stray ones swept). EverydayMusic plays Tide and Harbour evening in turn, 3 loops each, 4 s crossfade on the beat (data/music.cfg); off with --mute or the Dummy driver; keeps playing in the pause menu. Tide renders in 1.3 s, loads from the cache in 13 ms. The 169 limitation left as is (needs a 12 s audio hold-up). Harbour evening is about 5.5 dB louder than Tide.

## 225. Crows

- [x] Done

The user, 2026-11-13: wild crows (carrion or hooded crows, rooks) as wildlife:
they walk and hop on fields and meadows, fly off when the player comes near, caw now and
then (art in both sets, generated sounds). They may eat crops: sown seed and ripening crops on
unguarded fields lose some yield or a plant now and then (numbers in data/).
- Tests: the crows' flight from the player, the crop losses (numbers in data/), saving if they
  are saved; art crops in both sets and sound files for the user.

Done: 047bf8e7..d7faf37f, with the art (bffa4b2f, hooded crow, approved) and sounds (738ea0e7, crow_caw x5, crow_flock_rise x2, approved). Flocks of 3-7 hooded crows (a GroundFlock) on grass, floodplain and soil by day, more in autumn and winter, drawn to fresh sowing (spawn accepted by appearing_boost), at most 2 near the player, off in rain, fog, storm. CropRaids: each hour a flock more than 12 tiles from the player raids with chance 0.4, up to 2 unguarded crops within 3 tiles; seed eaten whole (chance 0.5), later stages lose one produce item (harvest never below 1); at most 2 plants and 6 items a day; seeded; flocks and tallies not saved; unloaded chunks never raided. `is_guarded` hook for the scarecrow. Console `crows`, `crows raid`, `spawn crows`, `killall crows`. Numbers in data/crows.cfg, data/wildlife.cfg, data/ambience.cfg.

## 226. Scarecrow

- [x] Done

After 225. The user, 2026-11-13, with the crows: a craftable scarecrow (sticks, straw or
reed, old clothes) placed anywhere (the user, 2026-11-13: "wherever you want, it'll have effect in a certain radius") keeps the crows away from the crops within a radius
(data/). Art in both sets, maybe swaying in the wind; the crows learn to ignore it a little over
time, or not: to be decided.
- Default for the open point: the crows learn to ignore it slowly (a scarecrow keeps them off
  fully for a few days, then less, up to a floor; moving it resets that), numbers in data/.
- Tests: the radius, the learning, crafting and placing; art crops in both sets.

Done: 15384bfb (art, approved "it'll do for now") and up to 0d0a090e. Made by hand from 1 log, 6 hay, 4 fibre (no cloth in the game yet); put down on any free outdoor tile, taken down by axe or hammer; `placed_day` in its object state. Guards crops within 5 tiles: full for 3 days, then falling over 12 days to 0.25 (rolled per tile and day); placing it anew resets that; new crow flocks don't settle where it guards (standing ones stay but can't eat guarded crops). Its coat and straw sway above 2 m/s of wind, faster in stronger wind, always to the right. `crows` lists the scarecrows. Numbers in data/crows.cfg. The art's own ghost picture is unused (its two sizes don't match).
