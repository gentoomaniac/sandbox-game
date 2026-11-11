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

## 170. Music: the game plays the modules (after 169's decision)

- [ ] Done

Known limitation from 169: MusicCrossfade counts a fade's progress across loop wraps from the time
between audio mixes, which is when they happened, not how much they mixed; an audio thread held up
and then mixing one block looks like a long stretch of play, so a fade into a short loop may end
early by the hold-up (docs/music-viability.md, "Switching on the beat").

To be rewritten from task 169's report with the user. The plan so far: render sections in the
background with a bounded cache (user:// keyed by the module hash, renderer version and mix
settings), never wait for a late render during play (keep looping), sections with explicit
entry state, tempo, meter, loop points and allowed exits.

## 171. Music: what plays when, with loops, transitions and crossfades

- [ ] Done

After task 170. A music director (a scene service) loops a section, plays a fill now and then
and returns on the bar, switches between two loops (later by time of day, season, weather,
indoors) with a minimum time before switching again. A "music" bus with its own slider in
Settings (and off), muted in test runs. Rules in data/music.cfg; tests; README.
- Indoors (from task 172, which leaves the music to this task): inside a building the director
  switches to an indoor piece or a quieter mix of the current one (the weather is faint there
  and a hearth crackles, task 172), crossfading as the player passes the door.
- The user, 2026-11-10, on three ambient sketches: "Tide" (6/8 sway, D dorian) and "Harbour
  evening" (80 BPM capstan bass, A aeolian) are great compositions; "Heath at dawn" is dropped; the
  tempos (60 dotted-quarter, 80 and 92 BPM) are right. The sound quality was bad: held notes
  wavered like a voice breaking, not like vibrato; the instruments must hold notes cleanly.
  After the fix: plain notes, no vibrato; the instrument tone is fine; note switches must not
  click.
  Approved the same day: "Tide" and "Harbour evening" (plain notes, held notes fading out
  rather than stopping) are the first everyday pieces (their data on the sketch branch of 2026-11-10).
- The user, 2026-11-10: the chiptune sound fits the classic 16 px graphics. Each piece gets two
  versions that switch with the graphics setting: the chiptune one with the classic art, a
  fuller one (more channels, softer instruments, still in the folk style) with the 32 px art,
  following the setting when it changes (a crossfade on the bar). The test piece's tempo was too
  fast for the game: calm tempos, around 100-110 BPM.
- The user, 2026-11-10, after hearing the 106 BPM test reel: "it still sounds like festive music
  for special events. The default music should probably be more of an ambient style music with a
  naval flair. Take inspiration from the German band Santiano." So the default (everyday) pieces
  are calm and ambient: slow sustained pads and drones, sparse melody, the sea and the coast in
  them (shanty-like modal tunes, a slow sway like a rolling ship, a low bass like a capstan
  song), our own tunes only, no melody of the band's or anyone else's songs. A second
  inspiration (the user, the same day): the German folk band Faun: medieval and pagan folk,
  hypnotic repeating figures, drones like a hurdy-gurdy or bagpipe, modal melodies like a
  nyckelharpa or flute, frame-drum pulses; again style only, our own tunes. Lively, festive
  pieces like the test reel are kept for special events (festivals, a market day). Later: stems
(AudioStreamSynchronized), more pieces, the season and weather choices.

## 173. Petting animals: a heart once a day, and a friendship value

- [ ] Done

The user, 2026-11-11: "you can pet animals. They'll show a small heart above their head. it
increases an internal friendship value by 10 which can increase to 100. you can pet animals as
often as you want but only once a day you'll see the heart and it will increase that value. The
value decreases by 5 a day if not petted. When you pet animals while they are sleeping the
counter decreases by 5 and you see a little swirl above their head. We'll use that value later
for game mechanics." Run after task 172, before the gossip tasks.
- Petting: the use key with an empty hand on an animal (it must not clash with feeding, the gate
  or riding). Each animal keeps a friendship value, 0 to 100. The user, 2026-11-11: the value
  can never go lower than 0 (no loss, sleeping or daily, takes it below 0).
- Awake: the first petting of the day adds 10 (capped at 100) and shows a small heart above the
  animal's head; more pettings that day do nothing and show nothing.
- Asleep: petting takes 5 (floored at 0) and shows a small swirl above its head. Confirmed by
  the user, 2026-11-11: the swirl and the loss come once a day too, and a sleeping petting
  doesn't count as the day's petting.
- A day without a petting takes 5 (at the day change, caught up over skipped time in the frame
  budget of task 158).
- Confirmed by the user, 2026-11-11: the farm animals and the pets (cows, horses, sheep, pigs,
  hens, dogs, cats), not wildlife; a new animal starts at 0. The numbers in data/livestock.cfg.
- The user, 2026-11-11: the tame rabbits can be petted too. Wild animals get the same
  friendship value but can't be petted (it stays at 0 for now); a later feature may let the player
  tame wild animals. Birds are left out. A wild animal is only tracked and saved once its value
  is above 0 (later: the player tried to tame it); all the others are not saved.
  Decided 2026-11-11 after a second opinion: for now only the attribute (a friendship value fixed
  at 0 on wild rabbits, squirrels, deer, mice and frogs, not pettable, not saved); the sparse saved
  store comes with taming (see Later).
- Saved with the animal (a save version bump, following the upgrade-window rule); the heart and
  the swirl drawn in both arts (pixel-artist job), a short sound for the petting maybe reused.
- Nothing uses the value yet; it is for later game mechanics. A console command to show an
  animal's value helps testing.
- Tests: the daily cap, +10 and the 100 cap, the sleeping loss, the daily loss and its catch-up,
  save and load; a README note.

## 174. Tilled soil reaches nearer the tile edges, and seeds and plants sit centred

- [ ] Done

The user, 2026-11-11, with a screenshot of a 2x2 bed (32 px art): "tilled soil needs to be closer
to the tile edges but not a straight line. The seeds and plants need to sit a bit more centered."
Today the bed's outer rim (tools/art/soil_beds.py, the bed shapes) is drawn well inside the
tiles, so a small bed reads as a rounded blob with a wide border of grass; and the sown seeds sit
low in their tile (near its bottom edge) rather than in the middle of it.
- The bed's outer edge comes close to the tile edges (a pixel or two in, not a wide margin), still
  ragged and organic rather than a straight ruled line; corners stay softly rounded. Both arts;
  the wetness overlay and the fade of task 167 and the weeds of task 166 follow the new shape.
- Seeds, sprouts and crops are drawn centred on their tile (check every crop stage and both arts;
  tall crops may still stand from the tile's lower part if that reads better, say so).
- Before/after crops at 1x and 4x and an in-game shot for the user; README pictures re-taken.

## 175. Rain visibly wets the soil, and wet soil is a patch, not a square

- [ ] Done

The user, 2026-11-11, with two screenshots in the rain (32 px art): "rain doesn't seem to wet the
soil? and wet soil has a clear border, it should be more like a patch not like a square."
- Rain: find out why a bed stays dry-looking in the rain. Leads: data/crops.cfg `rain_wets` is
  0.1 an hour only for the heaviest rain (lighter rain adds less), the moisture steps of
  SoilWetness (game/scenes/soil_wetness.gd) need a whole step's worth before the brown changes,
  and the view follows the moisture only at its hourly refresh. Rain should darken the soil
  noticeably within the first hour or so of steady rain, and heavy rain soak it; maybe a quick
  surface darkening while it rains. Keep the growth balance of the crops in mind (moisture_min
  and moisture_best) and say what changes there.
- The user, the same day: "actually during rain, the soil even dried out". Likely cause, in
  FarmingUpkeep.moisture_change (game/state/farming_upkeep.gd): every hour takes a 24th of the
  whole day's drying (its sun hours and strongest wind included), and that can outweigh
  `rain_wets * rain` in light or moderate rain, so a rainy hour dries the soil. Also check that
  `rain_in_hour` agrees with the rain shown on screen at the player's place and hour. While it
  rains, the soil must not dry (no sun or wind drying in a wet hour), and it must get wetter.
- Wet patches: a watered tile (or a few) beside drier soil still reads as a square block with a
  clear edge, even with the fade of task 167. Wetness should look like an organic patch: an
  irregular, blotchy outline that wanders across the tile edge (varied per tile, seeded by
  position), not a straight dithered band along the grid. Both arts. Works together with task
  174's new bed edge.
- Tests for the rain wetting and the patch edges; before/after crops and in-game shots in the
  rain for the user.

## 176. Wind gusts are heard with the wind you see, and as loud as the wind

- [ ] Done

The user, 2026-11-11: "with 5m/s wind speed the sound sometimes has loud gusts of wind while
nothing is moving. feels like the sound is off."
- Today the sound and the picture don't share their gusts. AmbienceSounds (game/scenes/
  ambience_sounds.gd) plays the `wind_gust` sound at random (`gust_chance` per second, scaled by
  the wind loop's level, data/ambience.cfg [loops]) and always at the sound's full volume, while
  the sway shader (game/scenes/sway.gdshaderinc, AmbientMotion.gust_for) shows gusts as fronts
  sweeping downwind every GUST_SPACING px at GUST_SPEED, only above GUSTS_FROM (3 m/s) and faint at
  5 m/s. So at 5 m/s a full-volume gust can sound while the grass barely stirs.
- Tie the gust sound to the visible gusts: compute on the CPU when a gust front passes the player
  (the shader's formula, from the same wind direction and time) and play/swell then, so a gust is
  heard when the grass and trees near the player bend. No gust sound below the speed where gusts
  show.
- Scale the gust sound's volume (and the loop's swell) with the wind strength, so a light breeze
  gives at most a soft rustle and a storm a loud gust.
- Indoors the gusts stay faint, as the rest of the weather (task 172).
- Tests: no gust below the threshold, gust volume grows with wind, the gust timing matches the
  shader's front at the player's place; a listening file at 5, 10 and 15 m/s for the user.

## 177. Darker nights, and a lantern to carry

- [ ] Done

The user, 2026-11-11: "darkness should be much stronger. You'll need to carry a lantern to get a
brighter circle around you to see better (right now via spawn command). it doesn't need fuel right
now, but holding it pressing space will turn it on and off."
- Night: much darker than today's bluish, readable night (DayNightTint.NIGHT, game/scenes/
  day_night_tint.gd, "night stays bluish and readable, not black"). Dusk and dawn ramp into it;
  moonlight may lift it a little if the weather/moon model has it. Light sources (campfires,
  windows, the hearth glow, fireflies) still read as light in the dark. The numbers in data/.
- A lantern item: no recipe yet, got through the console's spawn/give command. Held in the hotbar
  and selected, the use key (space) switches it on and off; lit, it casts a warm circle of light
  around the player (a soft radial light, flickering a little), off, nothing. No fuel for now.
  Its lit state is saved; it shows in the player's hand (lit and unlit) and as an icon, both arts
  (pixel-artist job). Maybe a small sound on switching (reuse one).
- Indoors stays as it is (the fixed warm tint), unless the lantern is easy to make count there too.
- Tests for the night darkness, the switching and the light following the player; screenshots
  for the user at night with and without the lantern, both arts; README note.

## Later (not part of the prototype)

- **Taming wild animals** (the user, 2026-11-11): wild animals already carry a friendship value
  (task 173); a later feature could let the player tame them. Design notes (second opinion,
  2026-11-11): a sparse store on GameState holds only wild animals whose value is above 0, ships
  together with bringing a tracked animal back near its last tile (wildlife nodes vanish indoors,
  over skips and with distance, so despawn is not death); one live node per id; ids from a saved
  allocator; records {id, kind, friendship, last tile, accounted_day}, decay counted in the state;
  a record goes when the animal dies (cats catch mice, storks catch frogs), drops back to 0 or is
  tamed into the livestock; wild-kind rules with the wildlife rules, not the livestock species
  (both have a "rabbit").

- **Animal breeding** (the user, 2026-11-10): a cheap way to get new animals, but the young take
  at least a year to grow up. With simple traits per animal (one cow gives more milk, another more
  meat) that the young may inherit, as in Palworld, and the looks (breeding only brown cows).

- **Keeping animals is costly** (the user, 2026-11-10): animals should take real work and
  resources, to fit the period.

- **Hired hands** (the user, 2026-11-10): money is hard to come by, so people could be taken on to
  live on the player's plot if the player builds them somewhere to live and produces enough food
  for them.

- **Tombstones** (the user, 2026-11-10): a placed grave marker is always the oak cross; a
  headstone and a fieldstone slab could come as crafted items of their own (their art is already
  drawn in tools/art/church.py).

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
