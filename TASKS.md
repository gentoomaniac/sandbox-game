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
Settings (and off), muted in test runs (comes with task 184). Rules in data/music.cfg; tests; README.
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

- Task 184 (done 2026-11-11) already added the Music bus and its volume slider in the audio
  settings, and a MusicPlayer behind the console `play`/`stop`; build on those.
## 204. A rooster among the chickens, crowing now and then

- [ ] Done

The user, 2026-11-11: "The chicken need a rooster that's occasionally shouting"
- Today the chickens (data/livestock.cfg, the chicken coop of task 122) are all hens with a cluck
  (`chicken_cluck` in data/sounds.cfg).
- Add a rooster: a chicken flock has one (a flock that gets its first hens gets a rooster too;
  `spawn rooster` in the console; old saves get one per coop or flock, with the save upgrade per
  the save rules). Bigger than a hen, upright tail and red comb and wattles: art in both sets, the
  same moves as the hens (a pixel-artist job); it walks and pecks with them, sleeps in the coop,
  lays no eggs, can be petted (friendship, task 173) and counts as a chicken where the game counts
  them (or say where it doesn't).
- It crows now and then: most at dawn (a run of crows around sunrise), a few times through the
  day, never at night while asleep. A new generated cock-a-doodle sound (2 or 3 variants, a
  sound-designer job), positional, heard across the farm, faint indoors like other outside
  sounds. How often: pick it, numbers in data/ (the user tunes them).
- Tests: a flock has a rooster, it lays no eggs, it crows at dawn and not at night, save and load;
  a listening file and a picture of the rooster in both arts for the user; README, design pages.

## 207. The tool grades as items, given with the console

- [ ] Done

After task 206's designs are approved: the five grades of each tool (rusty iron, iron, brittle
steel, steel, sharp steel) as items in the game, named "Rusty iron hoe", "Iron hoe" and so on; the
current tools become the rusty iron ones (renamed; old saves keep working). For now they come only
through the console `give` (no recipes, no shops). How the grades differ in play (the tool `level`
of item_types.gd, hit points per hit, durability if any) is to be proposed in the brief with the
numbers in data/ (the user tunes them). Both arts from the approved generator code.
- Build on the approved designs of task 206: branch `tools-206-designs` (generator code only:
  tools/art/tool_grades.py, tool_icons.py, classic/tool_icons.py, character.py held tools,
  docs/art-style.md); rebase or cherry-pick it, regenerate the art (`make art`) and commit the
  generated files with it.
- The Roman numeral (I rusty iron .. V sharp steel) is drawn by the inventory UI, not baked into
  the art (the user, 2026-11-11): SlotView draws it bottom left of the slot (the count is bottom
  right, the badge top left), crisp in both arts at every scale; remove the numeral from the
  generated icons (the ground items stay clean).

## 208. Dig up bushes with the shovel and plant them elsewhere

- [ ] Done

The user, 2026-11-11: "Bushes need to be removable. Use a shovel to dig them out and be able to
place them somewhere else"
- The bushes (game/state/world_object_types.gd): BERRY_BUSH (blocks walking, picked for berries,
  regrows), SHRUB and FERN_BUSH (fibre by hand); check for other bush-like plants (the young
  saplings may fit too: say). Today they can be picked or cut by hand, but not moved.
- The shovel used on a bush digs it out whole: the bush becomes an item ("Berry bush", "Shrub",
  "Fern"; icon from its world sprite, both arts) in the inventory (or dropped if full), its tile is
  left as dug earth or grass. The bush keeps what matters (a berry bush's picked/regrow state may
  reset, say which). Digging takes a few shovel hits like other shovel work, with its sound and
  energy cost.
- The item is placed like other placeable things (a placement ghost if they have one) on a free
  tile where a bush can grow (grass or similar, not on water, paths, buildings, farmland), and
  becomes the same world object again, with its season looks and regrowth. Saved like other placed
  objects (save version bump if the save needs it).
- Picking berries and cutting by hand stay as today; only the shovel digs out.
- Tests: digging each bush gives its item, placing it back, refused tiles, a berry bush still
  bears after replanting, save and load. README, design pages.

## 209. Animals stuck at a fence turn left and right for a long time (bug)

- [ ] Done

The user, 2026-11-11: "Sometimes horses, potentially other animals as well, get stuck on a fence
and start spinning left right for a long time."
- Reproduce first: a horse (and the other farm animals and pets: cow, sheep, pig, chicken, dog,
  cat, rabbit) wandering, following the player or grazing next to a fence or wall (the pen fence of
  task 165, wattle fences, stone walls, Knicks, buildings since task 181), and a wander target or
  follow target on the other side. Find the cause: a target beyond the fence with no path, a
  steering that flips its facing every frame when the direct way is blocked, a body wider than a
  tile (the horse) touching the fence on both sides, or a stuck check that never fires.
- Fix it at the cause: an animal never flips its facing back and forth (a short hold on a new
  facing, or face by the path not by each blocked step); a blocked target is given up after a
  short try and a new one picked on its own side; a following animal that can't reach the player
  waits facing them. Same rules for every animal kind, and for villagers if they share the code.
- Tests: a horse with a target behind a fence stops turning within a few seconds and picks another
  target; facing changes at most a few times in that span; the same for a small animal and for a
  following dog.

## 211. Sleeping animals show a "zzz" now and then

- [ ] Done

The user, 2026-11-11: "Add the zzz bubbles occasionally to sleeping animals."
- The player's "zzz..." bubble exists (game/scenes/tiredness_signs.gd, BUBBLE_ICON `zzz`); farm
  animals and pets know they are asleep (FarmAnimalView `is_asleep`, FarmAnimal.Activity.SLEEP),
  and the petting marks of task 173 already sit over each kind's head (FarmAnimalView.HEADS).
- A sleeping animal shows a small "zzz" rising over its head now and then (not all at once and not
  all the time: a random gap per animal, a few seconds shown), sized for the animal, in both arts;
  reuse the bubble art or the petting-mark placement. Farm animals and pets; wild animals too if
  they sleep in the game (say which do). Nothing while awake; it goes when the animal wakes or is
  petted (the anger mark of task 173 wins). Numbers (gap, duration) in data/.
- Cheap: a timer per sleeping animal on screen, nothing for animals off screen.
- Tests: a sleeping animal shows it within the gap and not while awake; screenshots of a sleeping
  cow and chicken in both arts for the user.

## 212. Wild rabbits flee even when asleep

- [ ] Done

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

## 213. Only the music plays while the pause menu is open

- [ ] Done

The user, 2026-11-11: "All sound should stop while being in the menu, except the music"
- While the pause menu (PauseMenu, with all its settings pages) is open, every game sound goes
  quiet: ambience, weather, outside effects, footsteps, animals, the fire loops, the bell, tool
  sounds already playing. The Music bus (task 184) keeps playing. The menu's own UI sounds (if
  any) still play, and the audio settings page still lets the player hear a volume change (a test
  sound on the changed bus, or say why not).
- Pause or mute the game buses (AudioService: Master's children except Music and a UI bus), or
  pause the players, whichever resumes cleanly: closing the menu brings everything back where it
  was (loops continue, positional sounds resume), with a short fade both ways so it doesn't click.
  Other windows (crafting, chest, character, chat, console) keep the sound as today, unless the
  game pauses for them too (then the same rule).
- Tests: buses silent with the menu open and the music not, sounds back after closing; README line.

## 214. Thunder by distance: delay, loudness and sound fit how far the strike was; now and then a close one

- [ ] Done

The user, 2026-11-11: "Thunder and lightning need to carry on loudness and delay to simulate
different distances. Also some different varieties like the occasional close lightning strike"
- Today a lightning flash (data/weather.cfg [thunder], `lightning_per_minute`) is followed after
  `thunder_delay` by one of four `thunder` sounds (game/scenes/ambience_sounds.gd), all the same
  loudness, the delay random and not tied to the flash.
- Each strike gets a distance (drawn per flash, far ones most common): the thunder comes after
  about distance / speed of sound (about 3 s per km; game time or real time: say which, real
  seconds feel right), quieter and duller (low-passed, longer rumble) the farther it is, and the
  flash is fainter and more diffuse the farther it is (a sky glow far off, a bright white flash
  near). Numbers in data/weather.cfg (distance range and weights, loudness and filter by distance).
- Varieties (a sound-designer job, generated in tools/audio like the others): a far rolling rumble,
  a middle-distance roll, and the rare close strike: a sharp crack almost at once with the flash,
  very loud, then a heavy rumble; maybe a bright bolt drawn in the sky or a screen flash for the
  close one (the flash view exists: extend it). The close strike is rare (a few per storm at most).
- Indoors: muffled like the other outside sounds (the OutsideEffects bus); the flash seen through
  windows only as today.
- Tests: the delay grows with distance, loudness falls with it, close strikes are rare and use the
  crack variety; listening files (far, middle, close) for the user.

## 215. Character window: no trash can; the bag can be open beside it to drag gear onto the figure

- [ ] Done

The user, 2026-11-12, after task 191: "The character window doesn't need a trash can. Dragging
into an item slot should happen when the bag is open at the same time."
- Remove the trash can from the character window (CharacterScreen); the bag keeps its own.
- The bag (B) and the character window (C) may be open together, side by side without overlapping
  (both stay movable). Dragging a stack from the backpack onto an equipment slot wears it;
  dragging worn gear back into the backpack takes it off. Hotbar drags and right click keep working.
- Today only one Modal is open at a time ("other windows' keys do nothing"): allow this one pair
  (B over the character window opens the bag and C over the bag opens the character window; each
  key closes only its own window).
  Other windows keep the one-at-a-time rule.
- The user, 2026-11-12: "The idea UI wise is like in world of warcraft." So the usual MMO layout:
  the character window docks on the left side of the screen, the bag at the bottom right above the
  bag button; each opens and closes on its own key or button, independently of the other, and both
  can be open at once while you keep playing. Escape closes all open windows at once. No art or
  look is copied from that game, only this layout and behaviour.
- Tests for both windows open, the drags both ways and the keys; screenshots for the user; README
  and docs (docs/ui.md, design/presentation/menus-and-hud.md, design/player/inventory-and-character.md).

## 219. Cloud shadows look broken: hard lines instead of soft clouds

- [ ] Done

The user, 2026-11-12: "cloud are working but the textures are kind of broken. Full of hard lines
etc doesn't look like good at all."
- The user, 2026-11-13: "on my other system the cloud shadows look great". So the hard lines
  show on one machine only: first find what differs (GPU and driver, the renderer the project
  uses there and its shader float precision, window size and scale, how long the game had run,
  since the drift grows without bound) and reproduce it, before changing the look.
- The shadows of task 194 (game/scenes/cloud_shadows.gdshader, numbers in data/lighting.cfg
  [cloud_shadows], fed by WeatherView) work, but the patches show hard lines. Take screenshots
  first (cloudy weather by day, `--weather cloudy`, both arts, standing still and while they drift)
  and find the cause. Suspects: the value noise interpolates on an axis-aligned grid, so its
  octaves (not rotated against each other) leave straight creases; the CONTRAST stretch and clamp
  flatten whole areas into plateaus with sharp rims; `size` follows the cover live, so the pattern
  rescales around the world origin when the cover changes; the drift offset grows without bound
  and the hash loses float precision after a while (which shows as banding).
- Fix it at the cause so the shadows read as soft, rounded clouds: a smoother noise (gradient or
  simplex noise, rotated octaves, perhaps a little domain warp for billowy shapes), soft edges with
  no straight lines or grid, no pulsing when the cover changes, and a drift kept bounded (wrap it
  without a jump). Still drawn in world pixels so it fits the pixel art; still cheap.
- The weather already has a wind direction (WeatherSample.wind_direction, slowly turning over
  days) and the shadows already drift with the full wind vector; keep that.
- Before/after screenshots for the user (both arts, light and heavy cover); numbers stay in
  data/lighting.cfg.

## 220. Sky flocks flying north or south show the birds sideways (bug)

- [ ] Done

The user, 2026-11-13: "birds flying from north to south or south to north fly sideways".
- Since task 183 the sky flocks (Flock, game/scenes/wildlife/flock.gd: the sparrow V of kind
  FLOCK and the skein of greylag geese, FLYING_GEESE) often fly north to south or south to north,
  but every bird is a side view (the `fly` animation of tools/art/animals.py and
  classic/animals.py) that only flips left or right by `_heading.x`, so a V heading south shows
  birds flying sideways.
- New art (a pixel-artist job, both arts): flying birds seen heading down the screen (the
  front: head and breast, both wings spread) and heading up (the back and tail, both wings
  spread), with the same wingbeat frames as the side view, for the sparrows and the geese.
- The flock picks the view by its heading: the side view (flipped) when it flies mostly across,
  the up or down view when mostly along the screen's vertical (threshold in data or a named
  constant: say which). The shadows stay as they are.
- Tests: the view chosen for headings around the compass; screenshots of a north- and a
  south-bound V of each kind in both arts for the user.

## 221. Rain comes in spells of hours, not days; autumn is the wettest season

- [ ] Done

The user, 2026-11-13: "is the weather affected by skip? I skipped like 20 times and still had
rain" (after `weather auto`). Skip does change the weather (Weather.at is a function of the day
and minute), but a probe over one year (rain > 0.05 per hour, tile 0,0) showed spells far too long
and the seasons unlike the coast:

| seed | wet hours | longest spell | wet hours spring / summer / autumn / winter |
|---|---|---|---|
| 1 | 10 % | 22 h | 27 / 20 / 176 / 58 |
| 12345 | 20 % | 112 h | 358 / 47 / 162 / 12 |
| 987654 | 20 % | 64 h | 254 / 23 / 265 / 22 |

- Tune the weather (game/state/weather.gd, data/weather.cfg: the humidity noise octaves and the
  seasonal curves) so rain comes as showers and passing fronts: a spell lasts hours, rarely more
  than about a day, with dry hours between; the North Frisian coast's year: autumn and early
  winter the wettest, spring the driest, summer showery. Pick the numbers into data/weather.cfg
  (the user tunes them).
- Keep what depends on it working: the forced weathers, snow (SnowCover), soil wetness and
  farming upkeep (rain_in_hour), the thunder, the cloud cover (task 194/219), the ambience.
- A test over a year for a few seeds: the longest spell under a bound, wet hours per season in
  the intended order, a share of wet hours in a range. A short report for the user with the new
  table (as above) and a day-by-day picture of one season.

## Later (not part of the prototype)

- Ice on rivers and ponds in winter (an overlay on water when it is cold enough; frozen water
  can be walked on, see `Tile.frozen`). Split off task 185 by the user, 2026-11-11.

- **Villagers go inside** (the user, 2026-11-11): villagers enter their houses (and the church,
  workplaces) through the door instead of waiting in front of it, and are seen in the interior.

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

- **Where crafting lives** (the user, 2026-11-11): Shift+C is a stop-gap (task 191); find a
  better place, maybe no hotkey but something like Minecraft (a crafting table, or a small grid in
  the inventory).

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
