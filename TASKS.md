# Tasks: Prototype

Implements milestones 1 and 2 from the [design](design/README.md). Each task is small enough for one
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

## Milestone 2: a first season without the console

The user, 2026-11-14, from the [game design review](review/game-design-review-2026-11-11/README.md)
(GD1 to GD3, GD5, GD8): add the game parts a fuller loop needs, so a new player can farm, replant,
meet the village and work towards something without console commands. These tasks come before
227 and the rest of the queue. **They don't start until the user says go.**

The user, 2026-11-14: villagers need homes and workplaces, houses a default interior that a
villager's house can override, routines ("work from 7 to 15") whose places come from the
villager, and pathfinding to get there; a shopkeeper with a trading dialog builds on that.

Order: 231 to 233 have no dependencies and can run alongside the rest. The villager chain runs
228 (home and workplace), 237 (own interiors), 238 (pathfinding), 239 (routines), 229 (going
inside), 234 (the village), 240 (the shopkeeper), then 235 (seeds) and 236 (goals). The design
is in [design/README.md](design/README.md#2-a-first-season-without-the-console) and
[design/villagers/routines.md](design/villagers/routines.md).

## 231. A lantern and candles to make

- [ ] Done

Review GD1: the lantern (design/player/inventory-and-character.md) has no recipe; dark nights
need `give lantern`.
- Candles and the lantern get recipes, from things a new game can get. Tallow, beeswax and horn
  don't exist yet; the items there are fibre, logs, planks, hay, reeds and stone. Either add one
  new input with a way to get it in play (say how), or make do with those (numbers and inputs in
  data/recipes.cfg, chosen by the worker).
- The lantern burns its candle down over a few nights and takes a new one (or say why not).
- Tests: the recipes, the burn-down, save/load; the handbook's crafting page.

## 232. Crops tell the player what they need and how they are doing

- [ ] Done

Review GD3: growth hangs on warmth, light, moisture and wind, and a crop can die or wither,
but the seed tooltip says little and the crop state is only in the console's `crop`.
- Seed tooltips in plain words, read from data/crops.cfg: likes cool or warm weather, water
  need (low, middle, high), wind (hardy or tender), about how many days in good weather.
- Looking at a crop (hover or the empty-hand inspect, whichever fits the controls) shows its
  state in a few words: growing, slowed by cold / dry soil / wind, damaged, ripe, will wither in
  N days; the soil's real moisture, not the wet look of rain on the surface.
- A warning before a loss that can still be stopped (dry soil the can fixes, ripe crop about
  to wither), as a short toast once per field, not per tile.
- Tests: the words for each state and crop; the handbook's farming page and its picture.

## 233. A hint for what the next click or E will do

- [ ] Done

Review GD8: the same key does different things (talk before chest, hammer mode, saddle before
petting), and harvesting needs an empty hand that a new player can't see how to make.
- A small hint near the target or under the hotbar names the action that will actually run:
  "E: Talk to Antje", "E: Open chest", "Use: Refill", "Use: Remove saddle", "Use: Harvest",
  from the same code that runs it (no second copy of the rules). Off in the game settings.
- With a full hotbar and a ripe crop in front, the hint says how to get an empty hand.
- Hand crafting gets a visible way in (a button by the satchel) besides Shift+C.
- Tests: the hint matches the action for each case in game/state/interaction.gd (E) and
  game/state/tool_use.gd (Use); the handbook's controls page. May be split into the hint and the
  crafting button if it is too much for one brief.

## 228. A home and a workplace for each villager, and a way to give them

- [ ] Done

The user, 2026-11-13: "A way to assign a house to villagers". Today a villager only keeps near
an anchor (the yard of the nearest building or fireplace, design/villagers/villagers.md); there
is no home.
- A villager gets a home: a building (saved), not just a spot. Villagers of data/villagers.cfg
  get the house their sheet names where one stands, a married couple shares one; made-up ones
  get none until given one. The anchor becomes the yard in front of the home's door.
- The player gives a free house to a villager who has none (or moves one to another house),
  in the game: by default with the hammer's menu on a house ("Give to ...", a list of the
  villagers near) and in the console `home <villager> [here|none]`. A house holds a household
  (the couple and their children), at most as many as its beds or a number in data/.
- The user, 2026-11-14: a villager also gets a workplace, the place their routine (task 239)
  sends them to work: a building (the mill, a barn, the shop), or a spot with a name where there
  is no building (Ocke's landing at the sluice, a field). The sheets in data/villagers.cfg name
  it; the player gives one the same way as a home (`work <villager> [here|none]`).
- Gossip: the place words ("by Antje's house") use the home.
- Save version bump; tests: assigning, moving, freeing when a building is taken down, saving.

## 237. Each house has its own interior: the type's default, or a villager's own

- [ ] Done

The user, 2026-11-14. Today every building of a type copies its type's one interior map
(`interior_map` in data/buildings.cfg) when first entered, and keeps that copy.
- That map stays the default. A building can name its own interior map instead, kept with the
  building (saved), so a villager's house is their very own inside (Antje's dairy, Ocke's nets)
  while the outside stays the type's standard look.
- Villager sheets name the interior of their home (maps/interiors/villagers/<id>.tmx, made in
  Tiled like the others); a house given to a villager without one keeps the default.
- Make one own interior as the example (by default Antje and Hinrich's hall house); more come
  with 234.
- A map that doesn't fit the building's footprint or door is refused when loading the data
  (a catalog check), not in the game.
- Tests: the default, an own map, saving, a bad map refused; docs in design/building/.

## 238. Pathfinding: villagers walk to a place, not just about

- [ ] Done

The user, 2026-11-14: villagers need to get somewhere, not wander at random. Today they keep
near an anchor; nothing in the game finds a way (game/state/reachable_tiles.gd only floods a small
radius for the skip rule).
- A path search over tiles (A* or what fits best) with the same rules as a villager's steps:
  fences, walls, water, buildings, closed gates; lanes and paths cost less, so they keep to them.
  It goes across chunks and through doors (to the door tile, then the interior's own map).
- It must not stutter (see the gossip and flower snow fixes): a limit of tiles searched per
  call and of searches per frame, spread over frames, paths kept and only searched again when
  blocked; long ways cut into legs. Measure it with many villagers, with numbers in data/.
- A villager far from the player (in a chunk that isn't loaded) doesn't search: it is where its
  routine says when the chunk loads, as the skip rule does today.
- A stuck walker gives up after a while and waits or picks another way, never spins (task 209's
  rule for animals).
- Console `goto <villager> <x>,<y>` (or `here`) to watch it; a debug line of the path in F3.
- Tests: a way round a fence, through a gate and a door, none to a closed-in place, the limits,
  a blocked path found again.

## 239. Villager routines: when they are where

- [ ] Done

The user, 2026-11-14: routines are generic, like "go to work from 7 to 15"; the villager's
home and workplace (task 228) say where that is. Needs 228 and 238. **Plan first:** the worker
writes the routine format and the routines into design/villagers/routines.md and the user
approves it before code.
- Routines in data/routines.cfg: a few named ones (farmer, fisher, miller, keeper of the house,
  shopkeeper), each a list of hours and places: sleep at home, work, eat at home, the meeting
  place in the evening, church on Sunday; a weekday and a Sunday plan, and what rain or the
  dark changes (inside sooner).
- Each villager's sheet names their routine; a made-up villager gets one by their work.
- At the place, they do what fits there now and then (walk about the yard, stand at the work
  spot); between places they walk there by task 238, leaving in time to arrive by the hour.
- Replaces the anchor: the anchor rule stays only for a villager without home or routine.
- The `day` text of a sheet is told to the language model as before; the plan says whether the
  routine should be written from it or the other way round.
- Skip and sleep: a villager is where the routine says at the new hour.
- Console `routine <villager>` shows where they are going and why. Save version bump if needed.
- Tests: the place for each hour, Sunday, rain, arriving on time, the skip rule, saving mid-way.

## 229. Villagers go inside

- [ ] Done

After 239. The user, 2026-11-11: villagers enter their houses (and the church,
workplaces) through the door instead of waiting in front of it, and are seen in the interior.
- Their routine (task 239) says when they are inside: they walk (task 238) to the door of their
  home, the church or a workplace building, go in, are seen in the interior when the player is
  there and walk about it, and come out when the routine says; the skip rule puts them inside or
  out as the hour has it.
- Tests: going in and out, the interior shows them, saving where they are.

## 234. The village Wehlsbüll stands in the world, with its people

- [ ] Done

The user, 2026-11-14: the whole village, not one farm. Today villagers come only from
`spawn npc`, and the Warften stand empty. Needs 228, 237 and 239. **Plan first:** the worker
writes the plan (where, which buildings, the steps) into design/world/ and the user approves it
before code.
- World generation puts Wehlsbüll near the start, a short walk from the camp (about a minute):
  the farms on their Warften in the Koog, the church with its churchyard, the houses by the
  dyke and the sluice, the post mill at the Geest edge once it exists (until then its spot
  stays free), lanes between them, fences and walls. Built from the buildings that exist; the
  sheets' homes in data/villagers.cfg say who lives where (a placeholder where no building
  fits yet: say which).
- The eight hand-written villagers live there from a new game, each in their home (task 228),
  with their own interiors (237) and workplaces, spawned once. The village is not the
  player's: building there follows the reputation rule (design/villagers/reputation.md), and
  the area it covers is shown before the player builds.
- A meeting place (the church on Sunday, the Krug or a village green) where villagers come
  together now and then, so gossip has meetings.
- An old save gets the village where its land is still untouched, or keeps its world as it is
  (the plan says which). Save version bump if needed.
- Tests: the village is placed the same for a seed, never on water or the player's buildings,
  every villager has a home; screenshots in both arts; the handbook's villagers and world pages.

## 240. A shopkeeper who keeps shop hours and trades

- [ ] Done

The user, 2026-11-14: a shopkeeper goes to their shop at the routine's hours, stands there and
offers a trading dialog. Needs 234 (the village) and 239 (routines).
- A villager with the shopkeeper routine works in their shop: a building of the village or a
  stall by the lane (the plan of 234 says which, and who keeps it: by default a Höker, a small
  village shopkeeper, as a new hand-written villager with a sheet, or one of the eight).
- In the shop hours they stand at the counter; E on them there opens a trading dialog: what
  they sell and what they take, by barter (no money yet), the stock from data/shops.cfg filling
  up over the days. Out of hours: "The shop opens at 7", and E is the usual talk.
- With a language model the shopkeeper chats as any villager; the trade itself never needs one.
- Docs: design/economy/README.md (the first step of the economy draft) and the handbook.
- Tests: open and closed hours, a trade, a refused trade (not enough to give, a full bag), the
  stock refill, saving.

## 235. Seeds from the shop, and wild seeds

- [ ] Done

Review GD2: a harvest gives a seed back only now and then (`seed_chance` 0.2 to 0.7, low for
the regrowing crops), so a field shrinks each round and seeds come only from `give`. The user,
2026-11-14: a villager trades seeds by barter, and some seeds can be found. Needs 240. May be
split into the shop's seeds and the wild seeds.
- The shopkeeper (task 240) sells seed bags of every crop for produce or goods (prices in
  data/shops.cfg, by weight or worth).
- It always works: no friendship or language model needed, and the price can be paid even after
  a lost harvest (for example with wood, fibre, eggs or a day's work), so the farm can always
  start again. The stock fills up over the days.
- Wild seeds: some plants of the season drop a crop's seeds now and then when foraged (which
  and how often in data/).
- One seed item still plants one tile (review: "what is a bag" is settled as one planting).
- Docs: design/farming/crops.md and design/economy/README.md (the seed line "until a shop
  exists" changes), the handbook's farming page.
- Tests: a trade, a refused trade, the stock refill, save/load; a run over several harvests
  and a lost crop shows the farm never runs out of seeds.

## 236. Small goals from the villagers

- [ ] Done

Review GD1 and GD5: production needs a reason, and the first days need something to work
towards before the first turnips are ripe (nine good days). Needs 234, 239 and 235. **Plan first:**
the worker writes the plan (asks, the list, rewards, the opinion path, the steps) into
design/villagers/ and the user approves it before code.
- Now and then a villager asks for something small that they say in a line: five turnips, a
  wattle fence by their garden, a basket of berries, a stool. The player sees open asks in a
  short list (in the character window, or a page of its own). No quest chain, no fail; an ask
  goes away after some days.
- Bringing it gives something useful (seeds, a recipe, a tool grade, candle makings (task 231),
  opinion up a little through the gossip judge's rules); the rewards and asks in data/.
- The first ask comes on day 1 and fits the start (wood or fibre), so the player meets the
  village early.
- Works without a language model (fixed lines), with one the villager says it in their own
  words.
- Tests: an ask offered, done, timed out, save/load; the handbook's villagers page.

## 227. Swing poses for the tools

- [ ] Done

The held art is done (task 119); the use (swing) poses are not.
- The player's arm and the held tool swing when the axe, pickaxe, scythe and shovel are used
  (a few frames in the four directions), in both arts, timed with the use; the hammer and hoe
  too if they lack one. Art crops (1x/4x) for the user's verdict before the code uses them.

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
  rather than stopping) are the first everyday pieces; task 170 plays them (tools/music/pieces/sketch_tide.txt and sketch_harbour.txt).
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

## 224. Music: a fuller version of each piece for the 32 px art

- [ ] Done

After task 171 (the user, 2026-11-13: its own task after 171).
- The user, 2026-11-10: the chiptune sound fits the classic 16 px graphics. Each piece gets two
  versions that switch with the graphics setting: the chiptune one with the classic art, a
  fuller one (more channels, softer instruments, still in the folk style) with the 32 px art,
  following the setting when it changes (a crossfade on the bar). The test piece's tempo was too
  fast for the game: calm tempos, around 100-110 BPM.
- The music-composer writes the fuller versions of "Tide" and "Harbour evening"; the director
  of 171 picks the version by the graphics setting and crossfades on the bar when it changes.
- Tests: the version follows the setting, the switch on the bar; listening files for the user.

## 230. Saves keep their older versions, and a dialog picks which one to load

- [ ] Done

The user, 2026-11-14: "saves need older versions. Not just one save file but maybe ten rising,
first in first out. We then need a dialog to select which one to load."
- Every save (autosave, quick save F9, sleep, save and quit) writes a new file next to the last
  ones instead of replacing world.json; the newest 10 are kept, the oldest goes first (the count in
  data/, e.g. a setting later). Written as today: a temporary file, flushed, renamed; a save that
  fails leaves the others as they are. The unusable-save backups (`.bak`) stay apart from these.
- Each save says when it was made (game day, season, year, time of day, and the real date and
  time) and how (autosave, quick save, sleep, quit), read without loading the whole world (a small
  header or a sidecar file).
- Quick load (F8) stays as it is: it always loads the newest save, with no dialog (the user,
  2026-11-14).
- A load dialog (from the title/pause menu "Load"): the saves newest first,
  each with those details, picked with the mouse or the keys; Load, Cancel; a question before
  throwing away unsaved play. A save that can't be read is shown as such and can't be picked.
- Starting the game continues from the newest usable save, as today.
- The old single world.json of existing players becomes the first of the list (no progress lost).
- Tests: the rotation (11th save drops the oldest), a failed write, the listing order, loading an
  older one, the old file taken over; docs in design/tech/saving.md and the handbook.

## Later (not part of the prototype)

- Ice on rivers and ponds in winter (an overlay on water when it is cold enough; frozen water
  can be walked on, see `Tile.frozen`). Split off task 185 by the user, 2026-11-11.

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
