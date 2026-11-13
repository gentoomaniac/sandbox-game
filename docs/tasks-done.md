

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
