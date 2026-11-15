# Travel where the world isn't loaded (#68)

**How it works as built: [../tech/pathfinding.md](../tech/pathfinding.md).** This page is the plan
and the record of decisions and measurements. **2026-11-15, the user's decision: every search runs
on a worker thread** (near ones too), over the masks and a snapshot, never the live world; the
frame budget, the far queue and `far_every_frames` of the text below are gone (see "Searches on
worker threads").

Planned 2026-11-14, for the user's approval before code. It builds on task 238's plan in
[routines.md](routines.md) ("Finding the way"): `PathSearch`, `Pathfinder`, `NpcTrip`, `walk_to`,
`trip_arrived` and `trip_blocked`. That plan is approved and being built; until it is merged it is on
the branch of #6 (`worktree-agent-a9d7c5cfda1f25061`). #68's first step comes after 238 is merged.
OpenAI GPT 6.1 Sol gave a second opinion on this issue and reviewed the plan; where the plan follows
it and where it does not is at the end.

## The idea

A villager walks a real path over the real tiles, near or far, at the same speed. Where the
chunks are loaded it steps with its body, as in 238. Where they are not, it moves from tile centre to
tile centre along the same path, and the tiles are read from a small cache of the unloaded world.
It always has one position. Nobody is ever put at the edge of the loaded area: one who comes into it
walks in on its path, from the side of where it came from, at the time its walk takes.

The loaded area reaches 96 tiles from the player at the least (`LOAD_RADIUS` 3 chunks); the widest
view shows 40 x 22.5 tiles. So the switch from far to near happens at least 76 tiles out of sight.
Both ways follow the same path at the same speed, so there is nothing to see even if it were near.

**Simulated:** the path (the same A\* and the same step rule as near), walking time, the wait when no
way is found, fences, buildings, ditches, the tide and the seasonal plants. **Only plausible:** far,
no body is fitted (`_fits`), nothing is stuck, and the tide and the season are checked on each tile
as it is entered, not over the whole path in advance. No collisions, near or far (238).

## What the code has

- `World` keeps the edits of unloaded chunks (`_terrain_edits`, `_object_edits`), the buildings
  (`_building_by_tile`) and the wear (`_wear`), all by tile. `add_chunk` replays the edits on a
  freshly generated chunk (`World.replay_edits`, which works on any chunk, loaded or not; `Chunk.copy`
  makes the copy to replay them on). Night upkeep edits unloaded chunks too (crops, fallow soil grown over).
- Per tile, the generator is dear: `terrain_at` and `object_type_at` take 9.6 us a tile. A faithful
  far `object_at` has to look back over `MAX_FOOTPRINT` (7 x 2, 14 origins), as `_stored_object_at`
  does: 160 us a tile. `_type_standing_at` answers for the tile's own origin only. So there is no
  far view per tile; the cache is per chunk.
- Per chunk, `generate_chunk` takes 8.6 ms (median; 13 ms the most) and the chunk holds about 300 KB
  (240 objects). Stamping a mask of one byte a tile from a chunk and its neighbours takes 2.1 ms.
  On the loaded world, `Npcs.can_stand_at` costs 15.5 us a tile.
  (Measured 2026-11-14, three seeds, 81 chunks each, headless, `nice` on half the cores.)
- A villager's body (0.6 x 0.3) on a tile centre stands on that tile only, so "a villager can stand
  on the centre" is "the tile is walkable and no building", one bit a tile.
- Time: 1.5 game minutes a second and `walk_speed` 1.5 tiles a second, so a villager walks one tile a
  game minute. A game day is 960 seconds of play.
- `Npcs.update` runs from Main for all villagers, and from `ActorsUpkeep.walked_minute` for those in
  loaded chunks only. While the player is inside, Main runs it for the trips alone, on the masks
  (see "While the player is inside"). A skip makes up the rest of its
  time in `catch_up`, which walks the trips by the skip's minutes and puts the other loaded villagers
  somewhere around their anchors.

## Data and API, on top of 238

- **`TravelMask`** (one per chunk, `game/state/travel_mask.gd`): a `PackedByteArray` of 1024 flags,
  with `GameMap.is_walkable`'s order: DECK (free, whatever the ground and the tide), BLOCKED (ground
  or a blocking object), MUD (blocked while `Tide.floods`), OBJECT (the +2.0 cost of a non-blocking
  object that feet spoil, `NpcTravel.is_trampled`), SEASONAL (what the object does counts only while
  the plant is present: the flags are those of the ground alone and its `WorldObject` is kept in a
  small dictionary) and WEARS (grass or floodplain). Buildings are not in it: `World.building_at` is
  read live, and any building tile, the door included, is closed to villagers (238's step rule). It
  answers `is_free(local, tide_level, day)`, `is_trampled(local, day)` and `wears(local)`; tide and
  day are the caller's, never the clock.
- **`TravelMasks`** (one per `World`, held by `NpcTravel`, which makes it with its first search over
  that world and calls `update` once a frame; `game/state/travel_masks.gd`): an LRU of masks (1024,
  about 1.6 MB) and an LRU of raw chunks (32, about 10 MB). The two numbers are `far_masks_kept` and
  `far_chunks_kept` of `[travel]` in data/npcs.cfg (`TravelMasks.for_world(world, rules)`; the
  constructor takes the numbers). A raw chunk is what the generator makes and
  nothing else: no edit is ever applied to it, so it never goes stale (the seed does not change).
  A mask of chunk C is stamped from the raw chunks C, W, N and NW (big objects reach east and south,
  `MAX_FOOTPRINT` 7 x 2 within 32 tiles), with the edits of those four chunks replayed on copies of them
  (`World.replay_edits`, the code `add_chunk` uses: an edited position loses its generated object
  and gets the edit's, if any; an edited terrain replaces the generated one). `mask_of(coords)`
  returns the mask or null and asks for it; `update()` runs once a frame; `wait_for_mask(coords)`
  waits for the worker, for a time skip (step 4) and for tests.
- **Raw chunks are generated on worker threads** (several at once from #70, `far_mask_jobs`), each job by a `WorldGenerator` of its own.
  `generate_chunk` reads only the seed, its own noise objects and its own `FieldLayout.cover`, and
  the rules' statics (`LandscapeRules`, `StationRules`, `WorldObjectTypes.TYPES`). `TravelMasks`
  asks for each of them on the main thread before it starts the worker, so the worker only reads
  them. It writes nothing shared. A cold mask
  waits for up to four raw chunks, generated one after the other (about 35 ms in all, off the main
  thread). **The stamp is on the worker too** (the first plan, taken up again after the bench showed
  the stamp's 3 ms on the main thread added to slow frames): the worker builds the mask from copies
  of the raw chunks and a snapshot of the edits of those chunks (`World.edits_snapshot`: terrain by
  position, and the type of the object standing at each edited position, copied on the main thread
  when the job starts, 0.3 ms for four chunks of which one is tilled all over; the worker makes the
  objects new from the types, `World.replay_snapshot`). It touches nothing the main thread writes:
  the raw chunks are never changed and the snapshot is its own. The main thread takes the result in
  `update`, which is 0.08 ms at the median and 0.5 ms at most. Up to `far_mask_jobs` (3) jobs at a
  time (one before #70), the stamps before the generations. The raw chunks a pending request needs are never evicted, whatever the limit.
  (Pausing `generate_chunk` across frames would mean rewriting the generator; on the main thread
  one call is 9 to 13 ms, too much at 60 fps.) The destructor waits for the workers.
- **Invalidation:** `World` gets `signal edited(chunk_coords)`, raised by `_edit_terrain` and
  `_edit_object`, which every change of terrain and objects goes through, loaded or not. An edit of
  C drops the masks of C, E, S and SE (and no others); the raw chunks stay (they hold no edits).
  Each chunk has a version, bumped by its edits. A job notes the versions of the four chunks it
  copies the edits of; its mask is published only if they are all still the same, and else dropped
  and made again (the request stays). An edit made while a mask waits for its raw chunks is simply
  in the snapshot. So no stale mask is ever published.
- **`TravelView`** (the one view every World search gets, near and far; *superseded 2026-11-15: the
  view is over the masks of all chunks, with no live answer, see "Searches on worker threads"*): a tile is answered live
  (238's `can_stand_at`) only where its chunk and its W, N and NW neighbours are loaded; elsewhere by
  the mask. Today `World._stored_object_at` does not see a big object whose own chunk is not loaded,
  so on the west and north rim of the loaded square the live answer can be wrong; there the mask is
  the truth. With this rule a chunk loading or unloading changes no answer, and 238's
  `World.change_count` counts edits only. `cost_of(tile)` the same, with the wear from `World`.
  `is_known(tile)` is false where a needed mask is not stamped yet. Tide and season are those of a
  time given to the view (`at_minutes`), never the clock, on both sides: the masks', and the live
  one's, as `World.is_flooded` reads `clock.total_minutes()` and `World.is_dormant` `clock.day`.
  `World` gets `is_flooded_at(pos, minutes)` and `is_dormant_on(object, day)`, which the old two
  call with the clock, and the live answer of the view is `can_stand_at`'s rule over those two
  (`World.is_walkable_at(pos, minutes)`, with `is_walkable` calling it with the clock; `object_on(pos,
  day)` is `object_at` for a day). A search uses the time it starts at, whole: the view has one
  time, so no tile is asked "at the minute the search expects to enter it". That is step 3's: the
  walker checks each tile in the view as it enters it, with the time of entry, and searches again
  if the tide or the season has closed it. (A search is spread over a few frames and a path is some
  minutes long, so the time of the start is a fair guess, and the walk is the check.) **Done** *(superseded: see Searches on worker threads)*:
  `TravelView` (`is_live`, `is_known`, `is_free`, `cost_of`) is the one view of `NpcTravel`'s searches
  and holds the one cost rule (1.0, worn grass 0.8 and 0.6, +2.0 for an object that feet spoil); the
  trip holds the view, as a search keeps only its methods. The view settles once, for each chunk it
  is asked about, whether the world or a mask answers (`_sources`, cleared when the world's
  `change_count` moves), as a search asks a chunk thousands of times; a mask in it is the one of the
  first question. A tile is live when the chunks of
  `TravelMasks.SOURCE_STEPS` (its own, W, N, NW) are loaded, the very ones its mask is stamped from.
- **`PathSearch`** (*the Pathfinder part of this item is superseded by "Searches on worker
  threads"*) learns one answer: WAITING, when a neighbour of the node it expands is not known.
  The node goes back into the heap unclosed and is expanded again from the start once the mask is
  there (expanding twice changes nothing: a neighbour already reached is only improved), so no
  neighbour is lost. The `Pathfinder` passes the search over meanwhile (it takes no slot and no time).
  The search asks `is_known` for the neighbours it has not seen, all four at once, before it
  expands a node, so a far search needs nothing rolled back. **`Pathfinder`** has a queue for far
  requests (`queue(search, is_far)`): the oldest of them takes one of the frame's searches and at
  most half of its time, so far trips are not starved by near ones, and near ones are not held up
  by far ones (one near search always gets its turn). The far queue is worked in one tick of `far_every_frames`
  (`[travel]`, 4), since far searches are many and in no hurry; see the cost under Cost. *(superseded: see Searches on worker threads)*
- **`NpcTrip`** follows the path in one of two ways, decided each update: the tile it is on and the
  next are both answered live (above), so it steps with its body as in 238; or not, so it moves to
  the next centre at `walk_speed` and checks the tile in the view as it enters it (tide and season
  at that time). Loading can change between two centres; the switch keeps the position, the next
  centre and the distance left to it, and a body step after a far one checks its body afresh
  (`free_body_tiles` is cleared). It happens on the rim of the loaded square, out of sight. Main
  runs `Npcs.update` before `ChunkResidency.update`, so a chunk loaded in a frame counts from the
  next. A far tile that has closed makes the trip search again from where it stands, as a near stuck
  one does, then BLOCKED with the 238 retry. Far feet wear the tiles too
  (`World.wear_unloaded(tile, steps)`, trusting the mask's WEARS bit), so lanes grow where people
  walk, seen or not. 238's NOT_LOADED goes: a far trip searches; an unknown tile waits. (**Step 2 done**: `Block.NOT_LOADED`
  and its checks are gone and a far trip searches; until step 3 walks it, a villager on ground that is
  not loaded finds its way and then stands, stuck, for the retries, as the body does not fit there.)
  **Step 3 (2026-11-15)**, with these departures from the text above: the choice of way is
  made at each update, not once: a step is live when the tile it moves to and every tile the body
  touches there have their own chunk and W, N and NW loaded (the body reaches a little over the edge
  of its tile, so a villager on the last loaded tile can touch ground that is not), else on the
  masks. This is the rim rule, **mask-aware, not a handover**: a loaded tile whose W, N or NW chunk
  is not loaded is answered by the mask, which has the big object that the world does not see. On
  the masks only the tile it enters is asked, with the building (live) and the mask at the
  clock's minute (a dropped mask is waited for, which is not being stuck). Far feet wear by the mask's
  WEARS bit. `NpcViews.show_npcs` takes the world: a view is made only for a villager on a loaded
  chunk, and lost when its chunk unloads. The code is in `NpcTravel._walk`, not
  `NpcTrip`, which only holds the state.
- **`Npcs.update`** moves every trip, near and far; `only_loaded` only keeps the strolls to the loaded
  chunks. `Npcs.catch_up(map, seed, minutes)` takes the minutes of the skip (below); built in step 4.
- **`NpcViews`** makes a view only for a villager whose chunk is loaded, so after a jump (a loaded
  save, the console's `tp`) nobody stands on ground that isn't drawn yet. The ground near the player
  loads first; one coming from further out is on loaded ground long before the view.

The routines' API stays 238's: `walk_to`, `walk_to_door`, `cancel_trip`, `trip_arrived`,
`trip_blocked`, `place`. `place` may be used for any villager during a skip (below) and for one whose
chunk is not loaded; never on a visible one.

## Cost

- **Memory:** masks 0.4 MB (a kilobyte each, and the few seasonal plants of the chunk), raw chunks
  5 MB, paths about 5 KB for a 600-tile path (0.75 MB for 155 such). Search state only while a search runs (two at a time).
- **Measured, step 1** (`tools/bench/travel_masks.gd`, three seeds, 81 chunks each, headless, `nice`
  on 11 cores, 2026-11-14): generating a chunk on the main thread 8.4 to 8.7 ms median, 10.6 at most; a
  stamp (copies, replay, mask) 2.6 ms median, 4.0 at most; asking for 81 masks at once and calling
  `update` once a frame (the worker generating meanwhile), 101 frames for 81 masks, an `update` 3.0 ms
  median and 4.5 ms at most on the main thread; a question to a warm mask (`is_free`) 0.45 us, against
  15.5 us for `Npcs.can_stand_at`.
- **CPU per frame:** a far walker is one addition and one compare a frame, a mask read per tile:
  under 0.3 ms for 155. Searches stay in 238's 1.5 ms *(superseded: see Searches on worker threads)*. On the main thread a mask costs the copy
  of its edits (0.3 ms at most) and the publishing (0.08 ms at the median in `update`); generating
  (9 to 13 ms a chunk) and stamping (3 ms) are on the worker.
- **A search:** a far node costs a mask read instead of 15.5 us of `can_stand_at`, so it costs less
  than a near one (measured, step 2, below). A 300-tile way searches some 1200 to 2600 nodes (4000 at
  the most): 16 to 33 ms of search, 10 to 20 frames. Cold, it touches 20 to 40 chunks: 0.2 to 0.4 s
  of generating on the worker first (the village's chunks are warm after the first trips).
- **Measured, step 2** (*on the main-thread scheduler that the worker threads replaced; kept as the
  record*; `tools/bench/far_search.gd` and `frames.gd --far-trips=<n>`, 2026-11-14,
  headless, `nice` on 11 cores). Searches of ways of 300 tiles (210 + 90) between random free tiles in
  a square of 15 x 15 warm chunks (three seeds, 60 ways each; 28 to 37 of the 60 are not there, the
  sea and the dyke are in the way, and those are searched all over): a far tile costs 10.5 to 10.9 us
  (all searches together), a live one (the same chunks loaded) 40.6 to 41.1 us. Of the ways that are
  found: 1204, 2589 and 2548 nodes at the median, which took 15.8, 31.4 and 30.3 ms (47.6, 39.7 and
  35.7 at the most, for 4071, 3436 and 3068 nodes). The floor is `PathSearch` itself: with callbacks
  that answer at once it takes 6.5 us a tile (9.5 before its heap stopped swapping through a function
  call), so a far tile is that plus 4 us for the view (three calls a tile: `is_known`, `is_free`,
  `cost_of`, each a chunk's source from a dictionary and a mask read).
  The frames of the game (`make bench`'s fixture, 154 villagers; `frames.gd`, the baseline is three
  runs, then 30 and 154 villagers sent over and over to tiles 150 to 300 away in chunks that are
  not loaded, their masks cold and the worker busy). With the stamp on the main thread: standing 300
  frames, 99th percentile 18.4 to 21.0 ms (baseline) against 24.7 (30 trips) and 25.8 (154); walking
  70 tiles, 99th percentile 13.6 to 14.0 against 15.9 and 17.7. With the stamp on the worker and
  the far queue worked every frame: standing 14.5 to 20.0 (baseline; three runs) against 25.1 and
  29.4; walking 13.8 to 15.2 against 16.8 and 15.2; longest frames 26.5 to 31.2 (standing) and 28.0
  to 29.0 (walking) against 36.1 and 38.5, and 29.9 and 31.5. With the far queue worked in one
  frame of four (`far_every_frames=4`, the value in data/npcs.cfg): standing 23.2 and 27.2, longest
  31.7 and 35.2; walking 14.7 and 14.4, longest 31.6 and 28.7, which is the baseline's. The standing
  scenario stays above the baseline: with the far searches taken out altogether, the 30 villagers
  that have a trip and stand waiting for it still give 21.8 to 23.4 there (the scenario is 300
  frames and its end has a hitch of its own, 2 to 4 frames over 16.7 ms in the baseline), so
  what is left of it is not the far work. A pause of the far work after a slow frame was tried and
  did nothing measurable, so it is not in. Before the masks' requests were a set,
  `TravelMasks.update` took 3 to 4 ms on top of the stamp in busy frames (a linear `has` and a
  lambda `filter` over all requests).
  **What `far_every_frames=4` costs *(superseded: see Searches on worker threads)*:** a far search takes four times as many frames: a way of 1200
  to 2600 nodes (16 to 33 ms of search at 0.75 ms of a frame) is done in 22 to 44 frames at one in
  every frame, in 88 to 176 (1.5 to 3 s) at one in four, one search at a time. So a far trip leaves
  1.5 to 3 s late, and 30 far trips that start in the same minute leave 45 to 90 s apart from first
  to last, against 11 to 22 s at one in every frame (the user's answer 5 is 10 s for 30 villagers:
  that holds for near trips, not for this worst case). The far searches a day are far fewer than
  that case (a village's commuting is near, loaded ground, with the far trips the exception), and
  the value is data: 1 gives the speed back for the frames' price.
- **The day *(superseded: see Searches on worker threads)*:** a game day gives 1.5 ms x 60 frames x 960 s = 86 s of search. A village of 30 with four
  trips a day needs about 120 x 25 ms = 3 s; the bench of 155 about 620 x 25 ms = 16 s. If all 30 leave
  in the same minute, the last starts about 8 s later; if all 155 do, about 45 s (task 239 spreads
  the hours).
- **The limits, step 2** (as first planned, and what was measured, not a verdict): on warm masks a
  far node at most 10 us, a 300-tile far way found in at most 40 ms of search, and with cold far
  trips under way the longest frame and the 99th percentile no longer than without. Measured: the
  node 10.5 to 10.9 us and the way 16 to 33 ms at the median, 36 to 48 at the most (the per-frame
  budget bounds the effect of both); the frames as above: with the stamp on the worker and `far_every_frames=4` the
  walking scenario is the baseline's, the standing one is 3 to 9 ms above it at the 99th percentile,
  of which the far work is little. Reused commuting paths and a chunk graph are left for the bench
  of step 6 to ask for.

## Searches on worker threads (2026-11-15)

The user's rules: a search gets the latest world when it starts and works on that (away from the
player a stale answer is invisible); where the player is, the walker checks each tile it enters, and
if a step is blocked it finds a way round: at worst it stands and "thinks" (a search from where it
stands) and walks on. As built:

- `PathSearch` is unchanged; `TravelView` is now over the masks of **all** chunks, loaded or not
  (parity with the live world is tested), plus a `TravelSnapshot` of the building tiles and the wear
  (copied on the main thread, made again after a change or `snapshot_seconds`). No live `World` read
  off the main thread; the live view (41 us a tile) is no longer used by searches.
- `Pathfinder` is a dispatcher: one `WorkerThreadPool` task a search, at most `search_tasks` at once
  (1; see the measurements), results collected on the main thread, cancelled results dropped, every
  task reaped. A search that needs a mask it lacks returns WAITING with the chunk, is parked, and
  runs again when `TravelView.provide` has the mask: no pool thread ever waits. The scheduler of
  near and far queues, the frame budget (`searches_per_frame`, `search_usec_per_frame`),
  `far_every_frames` and the half-budget rule are gone.
- A stuck villager on loaded ground gets its new search before the others (`Pathfinder.queue`'s
  `is_urgent`; the player may be looking at it), the oldest first among those.
- The stuck delay is `blocked_give_up_seconds` 0.5 (it was 2.0): a blocked step stands and searches
  again soon. A new search sees every edit, as an edit drops the masks it touches and the search
  waits for the new ones.
- `Tide` and `Vegetation` keep answers in caches that the search would write from the worker: both
  are behind a mutex.
- **Measured** (`tools/bench/far_search.gd`, `frames.gd`, 2026-11-15; 11 cores): a tile on this
  thread over warm masks 9.2 to 9.4 us. 30 villagers leaving at once, masks warm: with
  `search_tasks=1` the first way after 0.02 s and the last after 0.8 to 1.0 s; with 2 the last after
  0.5 s. Masks cold (made as asked, one worker job a frame): the last after 4.4 to 4.7 s (2 tasks) and
  6.9 to 7.1 s (1 task). The main thread's share is 0.04 ms a frame at the median, 0.1 ms at most
  warm, 0.6 ms at most cold.
  Frames (`frames.gd --far-trips=<n>`; each far walker is sent to a new goal every 10 s, one search
  each, which is 3 searches a second for 30 and 15 for 154, where a village makes about 0.65; the
  first version of the bench let trips get stuck and search every 0.5 s, which was no real load).
  Baseline, three runs: standing p99 15.1 to 18.4 ms, walking p99 13.5 to 15.2, longest 27.4 to 29.1.
  30 trips: walking p99 13.8 (1 task) and 13.8 (2), longest 27.9 and 28.3: the baseline's. Standing
  p99 29.6 and 23.2 (the scenario is 300 frames, starts with all 30 sent at once and has a hitch of
  its own at its end). 154 trips: walking p99 17.7 (1 task) and 21.6 (2), longest 52.0 and 57.6;
  standing 27.2 and 26.2. So the default is 1 task, and a stress of 15 searches a second does cost
  the main thread frames. **The mutexes are not the cause:** with the locks of `Tide` and
  `Vegetation` taken out for a run, 154 trips and 2 tasks gave walking p99 19.3 and longest 52.0, the
  same within the noise (21.6 and 57.6 with them), so the worker's lookups are not what slows the
  main thread. Not found yet: the workers' share of memory and cache with the main thread is
  suspected; to look at once villagers really walk (step 3).
- **Measured with villagers walking** (step 3, 2026-11-15; `frames.gd --far-trips=<n>`, now trips
  that walk to reachable goals one after the other, `walk_speed` x 20 so that trips end within the
  run; 11 cores; 2 runs each, walking scenario p99 / longest frame): none 13.2 / 28.9 and 12.6 / 26.5;
  30 walkers 13.8 / 29.9 (and 13.8 / 38.8 in the first run); 154 walkers 16.5 / 32.4 and 15.9 / 38.6.
  The 154 walkers make 13 to 15 searches a second, complete 36 to 41 trips in 21 s and are blocked
  35 to 49 times (all `NO_WAY`: the clock moves in the scenarios, and the tide closes some of the
  ways); standing p99 25 to 29 against 23 (and 19.5) for none. So the cost under a heavy search load
  of step 2 (#70) stays about what it was (p99 +3 ms at 154), and the walking itself, at 20 times the
  tiles a second, adds nothing that shows at 30; per-frame far work is a few float operations and
  about eight chunk lookups (a dictionary `has` each), and a mask lookup when it enters a tile.

## Measured, step 6 (2026-11-15)

`tools/bench/paths.gd`, headless, pinned to 11 cores (`taskset -c 0-10 nice -n 19`; other work ran
on the machine now and then), the fixture save (155 villagers, 13 x 13 chunks loaded round the
player), frames paced to 60 a second of real time, each configuration run twice (the two runs agree
to a few percent unless it says otherwise). Goals are tiles a way leads to, 100 to 300 tiles away.
**Once**: all leave in one frame, 90 s. **Day**: each leaves at a random moment of the first half of
240 s, then goes to and fro with rests of up to 20 s. **Skip**: all leave, walk 45 s, then `catch_up`
of 240 minutes (the main thread waits for the worker). Cold: masks made as the searches ask; warm: the
same trips again over what the first run left. The main thread in `Npcs.update`'s parts, ms a frame;
with no trip at all the 155 villagers strolling cost 0.6 to 0.7 ms (mean; p99 1.1 to 1.2) and 30
cost 0.55 to 0.58.

As built before the tuning (`far_masks_kept=256`):

| Villagers | Run | Frame mean / p99 / longest (ms) | First leg wait mean / last (s) | Skip (s) |
|---|---|---|---|---|
| 10 | once, cold | 0.74-0.81 / 1.2-1.4 / 2.1-2.3 | 3.1 / 4.0 | |
| 10 | once, warm | 0.76-0.79 / 1.2 / 1.5 | 0.16 / 0.28 | |
| 10 | day, cold; warm | 0.63-0.73 / 1.1-1.3 / 2.2-13.8 | 0.5 / 1.4; 0.05 / 0.22 | 0.20 |
| 30 | once, cold | 0.93-0.94 / 1.5-1.6 / 2.4-6.5 | 8.0 / 10.1 | |
| 30 | once, warm | 0.85-0.91 / 1.3 / 2.4-2.6 | 0.46 / 0.93 | |
| 30 | day, cold; warm | 0.79-0.88 / 1.3-1.7 / 2.4-12 | 0.38 / 1.4; 0.03 / 0.15 | 0.21-0.23 |
| 155 | once, cold | 1.63-1.65 / 2.7-2.8 / 5.2 | 25.8 / 32.7 | |
| 155 | once, warm | 1.75-1.96 / 2.5-4.1 / 8.4-32 | 6.7 / 10.4-10.5 | |
| 155 | day, cold; warm | 1.6-1.9 / 3.7-4.9 / 10-21 | 0.33 / 1.4; 0.31 / 1.1-1.3 | 5.8-6.6 |

- **The wait is the masks, not the searches.** 155 searches are 270,000 tiles, 2.5 s of one worker (a
  worker is 3 % busy over 90 s). The first leg of the last of 155 villagers leaving cold takes 33 s,
  of 30 villagers 10 s (the user's answer 5, 10 s for 30, holds; it is the masks of a cold trip, not
  the search); warm with enough masks, 4 s (below). Spread through a day, nobody waits more than 1.4 s
  cold. The cold wait is one worker job a frame (`TravelMasks.update` starts one and takes its result
  the next frame, 60 a second): the 380 masks of 155 such trips are some 760 jobs (a stamp each and
  about as many generated chunks), 13 s at the least, and the LRU of raw chunks (32) makes some of
  them twice. More raw chunks (128) changed nothing (25.6 s again). Several jobs in flight shorten it some (#70, below).
- **The main thread is cheap.** All the Npcs do is 0.7 ms (10 villagers), 0.9 (30) and 1.6 to 1.9
  (155) in a frame at the mean, 1.2, 1.5 and 2.5 to 4.9 ms at the 99th percentile, no frame over
  16.7 ms; 0.6 ms of the 155's is the strolling of those who are not on a trip. The longest frames
  (5 to 20 ms) are the first send after the masks are made (7 to 22 ms in cold runs, not looked into)
  and the snapshot copy.
- **Snapshots** (`TravelSnapshot.of`, counted in sending): 0.4 ms with 6000 worn tiles, 2.5 to 3 ms
  with 33,000, 6 to 9 ms with 55,000 to 62,000 (after 90 s of the stress), one every
  `snapshot_seconds` while villagers search. The cost grows with the wear all villagers have made
  (it regrows, see `World`, so it is bounded), so it is the one that grows with the length of a day.
- **Memory** (static memory, MB; the goals are chosen with masks of their own that are let go of
  first): 136 with the save, 153 with 10 villagers walking cold, 160 with 30, 172 with 155 sent once,
  178 after a day. In the stress (below) 200 to 236: the wear of 60,000 tiles and what the paths and
  views hold; not taken apart.
- **No interference from the workers.** The probe (4000 lookups in a table of tiles, 0.23 to 0.26
  ms, p99 0.3 to 0.4) takes the same with 155 villagers searching and a worker making masks as with
  none, in every run (apart from single frames of 3 to 22 ms that the runs without trips have too).
  Cache or memory contention that slows the main thread (Sol's first suspect, #70) is not seen at this
  load.

**Tuned** (each change measured on 155 villagers, once and skip, twice):

| Setting | Was | Now | Result |
|---|---|---|---|
| `far_masks_kept` | 256 | 1024 | 155 once, warm: first leg 6.7 / 10.4 s -> 2.1 / 4.1 s; skip 6.0 s -> 0.3 s; the stress below. The trips touched 376 masks, so 256 dropped what the skip and the next search needed. 4096 (with 128 raw chunks) gave the same and 20 MB more. |
| `far_chunks_kept` | 32 | 32 | 128: no gain, 20 MB more. |
| `skip_masks_ahead` | 8 | 8 | 2, 8 and 32: the same skip (0.25 to 0.33 s). |
| `search_tasks` | 1 | 1 | 2 in the stress: waits no shorter (they are mask-bound), main thread no better (p99 7.1 to 10.6 ms, against 5.2 to 6.0 with one task and 1024 masks). |
| `snapshot_seconds` | 2 | 2 | 10: p99 10.5 and 5.9 ms in two runs against 10.4 and 11.7: the noise is larger than the effect. |
| `blocked_give_up_seconds`, `retries`, `max_legs`, `max_nodes` | | unchanged | The bench has no fence: nothing was blocked by a step (only `NO_WAY` in the game's frames bench). Left as the user chose them. |

**The stress of #70** (`speed=20`: walkers at 20 times the pace, sent again every few seconds; 155
villagers, 90 s; 7.6 searches a second with 256 masks, 10 with 1024, 15 to 17 in `frames.gd
--far-trips=155`, where a village makes about 0.65). Frame mean / p99 / longest (ms) of the parts of
`Npcs.update`, two runs, cold and warm:

| | 256 masks | 1024 masks |
|---|---|---|
| all parts | 3.0-3.7 / 9.3-11.7 / 17-40 | 2.35-2.47 / 5.2-6.0 / 8.6-12 |
| walking | 2.6-3.1 / 8.2-10.8 | 2.2-2.3 / 3.7-5.2 |
| `Pathfinder.tick` | 0.08-0.11 / 0.7-1.2 / up to 8 | 0.006-0.011 / 0.03-0.04 / up to 0.9 |
| `TravelMasks.update` | 0.25-0.31 / 0.8-3.1 / up to 7.5 | 0.002-0.05 / 0.005-0.5 / 0.7 |
| sending (`walk_to`) | 0.12-0.15 / 0.3-0.4 / 11-17 | 0.08-0.10 / 0.27 / 5-6 (the snapshot) |
| first leg wait mean / last | 3.4-3.8 / 26-31 s | 0.03-0.24 / 0.08-8 s |
| trips completed in 90 s | 430-447 | 582-594 |

The masks of 155 trips being dropped and made again (an LRU of 256 against 380 in use), not the
searches, were most of the tail of the heavy search load and of the waits: with 1024, p99 about
halves (9 to 12 ms down to 5 to 6), the longest frames drop a lot, and the mean drops by about a
third (3.0 to 3.7 ms down to 2.4), with more trips done in the same time. What is left at 155
walkers is the walking itself.

**What #70 starts from.** A frame of the game (`frames.gd`, headless, walking scenario, ms; none, 30
and 155 far walkers at 20 times the pace, two runs each, `far_masks_kept=1024`): mean 7.1 / 7.1-7.2 /
7.2-7.3; p99 11.8 / 12.5-13.3 / 15.5-17.1; longest 24.4-24.5 / 26.7-27.4 / 27.5-49.6. The parts of
`Npcs.update` (`paths.gd`, mean ms a frame):

| Part | 155 walkers, real pace | 30 walkers, real pace | 155, 20 times the pace, 1024 masks |
|---|---|---|---|
| walking (`Npcs.update` without its `tick`: the trips, and a search a stuck walker begins) | 1.5-1.9 | 0.8-0.9 | 2.2-2.3 |
| `Pathfinder.tick` (reap, parked searches, start tasks) | 0.02-0.04 | 0.003-0.008 | 0.006-0.011 |
| `TravelMasks.update` | 0.03-0.07 | 0.003-0.024 | 0.002-0.05 |
| sending (`walk_to`: snapshot, prefetch, queueing) | 0.04-0.05 | 0.01 | 0.08-0.10 |
| with no trip at all (the others strolling) | 0.6-0.7 | 0.55-0.58 | 1.4-1.5 |

The rest of the frame (about 7 ms: drawing and the world) does not change with the walkers. What is
left is the walking of those on trips: about 6 us a walker a frame at the real pace, and the p99
follows the tiles entered a second (at 20 times the pace 4000 a second at 155, each a mask lookup and
a wear step). Dispatch and reaping are a few percent of it; masks and snapshot are spikes (a snapshot
of 55,000 worn tiles is 6 to 9 ms in one frame). So #70 starts with the walking (tile entry), the
copy of the wear for a snapshot, and the first send of a cold run (7 to 22 ms); the workers' share
of memory and cache is not seen by the probe.

## Measured, #70

`paths.gd` as above (the runs are deterministic in the waits: two runs gave the same to 0.1 s; the
frames differ by a few percent). Main thread in ms a frame (mean / p99 / longest), 155 villagers
sent once, cold masks, `walking` as in the table above.

**Several mask jobs** (`far_mask_jobs`, `TravelMasks`): the cold wait was not only the one job a
frame: the searches stop at each mask they lack and one search runs at a time, so the two together
set the pace.

| Villagers, config | First leg wait mean / last (s) | Walking mean / p99 / longest (ms) |
|---|---|---|
| 155, 1 job, 1 search task (before) | 26.1 / 31.8 | 1.23 / 2.26 / 4.1 |
| 155, 3 jobs, 1 search task | 22.2 / 27.5 | 1.39 / 2.33 / 3.5 |
| 155, 6 jobs, 1 search task | 22.3 / 27.5 | |
| 155, 1 job, 3 search tasks | 14.6 / 19.7 | 1.53 / 2.65 / 6.2 |
| 155, 3 jobs, 2 search tasks | 11.9 / 14.7 | 1.65 / 3.18 / 9.2 |
| 155, 3 jobs, 3 search tasks | 8.9-9.1 / 10.8-11.2 | 1.83 / 5.0-8.5 / 11-15 |
| 155, 4 jobs, 6 search tasks | 6.3 / 8.7 | 2.76 / 19.9 / 28 |
| 30, 1 job, 1 search task (before) | 7.6 / 10.2 | 0.82 / 1.29 / 1.6 |
| 30, 3 jobs, 1 search task | 4.1 / 5.3 | 0.89 / 1.77 / 3.4 |
| 30, 3 jobs, 2 search tasks | 2.8 / 3.7 | 0.86 / 1.42 / 3.3 |

Warm waits (the masks are there): 2.15 / 4.25 s for 155 with one search task, 1.1 / 2.2 with two,
0.8 / 1.6 with three. `far_mask_jobs=3` is the default: the wait for 30 villagers is nearly halved at
no cost to the main thread, and 155 wait 4 s less. More search tasks wait less still and cost the
main thread: with the walkers' frames slowing as more workers run at once on the 11 cores of the
bench (walking p99 2.3 ms with one search task, 3.2 with two, 5 to 8.5 with three, 20 with six
tasks and four jobs), so `search_tasks` stays 1, as the user asked for the per-frame work to stay
small. The user's answer (30 villagers on their way within 10 s, 155 within 60 s) holds.

**The snapshot's copy of the wear** (`WorldWear.days_copy`): the days of wear change only at the end
of the day (and in the debug views and a load), yet every snapshot, one every `snapshot_seconds`
while villagers search, copied all worn tiles. The copy is now kept until the days change and
shared by the snapshots of the day. `paths.gd day=100 wear=60000`, 155 villagers to and fro, two
runs each, before and after (sending is `walk_to`, ms a frame, mean / p99 / longest; the four
slowest sending frames of a run were all one trip sent, with a snapshot made, 5.3 to 5.6 ms
before and 0.3 ms after):

| | Sending mean / p99 / longest | A snapshot made now | Walking mean / p99 |
|---|---|---|---|
| before | 0.066-0.070 / 0.18-0.22 / 5.5 (cold, 4.0 warm) | 3.1-3.2 ms | 1.6 / 2.4 |
| after | 0.050-0.053 / 0.17-0.22 / 0.3 | 0.01 ms | 1.6 / 2.4-2.5 |

"The first send after the masks are made costs 7 to 22 ms" (step 6) were two things, neither a cost
of sending. In the runs that wore many tiles it was the frame of a send that made a snapshot (above).
In a cold run of the bench it is the first send of the run: `paths.gd` makes the masks anew by
setting the rules again, and the old `TravelMasks` with the last run's 380 masks and 32 raw chunks
is freed in that frame (5.3 ms for 32 raw chunks and 48 masks in a test; 23.8 ms in the day run that follows a run
with 380 masks, which was not taken apart). The game drops a raw chunk at a time, a fraction of
that, and a whole cache only when it loads another world. The frame that sends all 155 trips
at once in `once` (4.3 to 7.3 ms, 28 to 47 us a trip) is the bench's, not a game's. Nothing of
this was changed, as nothing in the game's frames is slow. Making the masks object on the first
send is 0.4 ms (a generator is made on a worker). The one copy a day (the first snapshot after midnight) remains, 3 ms at 60,000 worn
tiles; midnight's own `end_day` walks all of them anyway.

**Walking** (`NpcTravel._walk`, `Npcs._update`): 155 villagers on trips cost 10.1 to 10.5 us a
walker a frame (a throwaway loop of 1200 unpaced frames of `Npcs.update` over 154 walkers, from
the start of their trips, two runs, five rounds; most walkers are on loaded ground in the first
minutes, where every frame checks the step against the live world). Three repeated lookups left
out: `walk_speed` and `personal_space` are read from the rules once (`NpcTravel` holds them), not
as two dictionary reads and a conversion each frame; `Npcs.wear_step` asks for the wear rules only
when the walker has entered a new tile; the Callable `_fits` is made once a frame, not once a
villager. Result 9.0 to 9.4 us a walker in both runs (about 10 % less, 1.57 to 1.45 ms a frame).
Not done, as it measured nothing: asking `_is_step_whole` per chunk of the body instead of per tile
(9.1 to 9.4 us again). What is left is the interpreter's cost of the many small steps of a frame
(the walk, the crowding check, the body's tiles against the loaded chunks, the fit check), spread
too thin for one change to pay; fewer of them would mean a walker that skips frames, which is not
done here.

**All of #70 together** (`paths.gd send=155`, default scenarios, once, 11 cores; before is the
table of step 6 as tuned, `far_masks_kept=1024`):

| Run | Before | After |
|---|---|---|
| once, cold: first leg wait mean / last | 25.8 / 32.7 s | 22.5 / 27.8 s |
| once, cold: frame mean / p99 / longest | 1.63-1.65 / 2.7-2.8 / 5.2 ms | 1.61 / 3.06 / 8.1 ms (a mask or search task finishing at once) |
| once, warm: first leg wait | 2.1 / 4.1 s | 2.15 / 4.3 s |
| once, warm: walking mean / p99 | 1.75-1.96 / 2.5-4.1 ms | 1.65 / 2.38 ms |
| day, cold: first leg wait mean / last | 0.33 / 1.4 s | 0.12 / 1.23 s |
| day: frame mean / p99 | 1.6-1.9 / 3.7-4.9 ms | 1.44-1.46 / 3.1-3.6 ms |
| skip of 240 minutes, cold; warm | 0.3 s | 0.43 s; 0.36 s |

(The runs have no worn tiles, so the snapshot's part of #70 is not in them; see above.) The
frame's mean falls some 10 % with the walking; the wait for the first leg of the cold masks is the
rest of what a village's first morning costs, set by the one search at a time (above).

## Time skips and sleep

A skip moves every trip along its path by its minutes (one tile a minute). The skip's three walked
minutes go through `Npcs.update`, the rest through `catch_up`, which comes after `Simulation` has
moved the clock to the skip's end (no trip is left out, and none counts twice).

- **Tide and season at the time of entry:** each tile is checked in the view at the minute the trip
  enters it (`at_minutes`, counted back from the skip's end), not by the clock, which stays where it
  is.
- **The world as it is at the skip's end:** edits made during the skip are not replayed in time;
  the trip sees them all at once. That is a simplification, and it does reach walking: night upkeep
  grows a sapling into a tree (open, then closed), and takes a rotted stump off or turns it into a
  sapling (closed, then open). A trip in the skip meets such a tile as it is at the skip's end:
  a tree that grew at 3 o'clock stops one that passed at 1. Nobody sees it.
- **Missing masks:** the chunks a path crosses are known. The catch-up asks for them in the order the
  trips walk through them, a few ahead (`skip_masks_ahead`, 8), and pins those it is using, so a
  long skip of many trips never needs more masks at once than the LRU holds. `catch_up` waits on the
  worker for each one; `catch_up_over_frames` lets the frames go by until it is there. Both stamp
  the same masks from the same seed and edits, so both end the same, and the same game skipped the
  same way ends the same.
- **Searches:** none inside a skip. A trip with no path yet, or one that meets a closed tile, stops
  there and searches after the skip, as in play, and so leaves late. It arrives, and sends
  `trip_arrived`, at the end of the skip when its path ends in it.
- **As far as play:** a skip takes a trip as far as the same minutes of play when its path stays open,
  no edit in the skip opens or closes a tile of its path (the trees above), it needs no new search,
  the player does not hold it up, and the frames of play were shorter than `MAX_STEP_SECONDS` (a
  longer frame of play loses time). Then the two agree to the tile.

**What 239 does:** an 8-hour sleep crosses several routine hours. A skip is not watched (the player
sleeps indoors, or the screen fades), so after it task 239 puts each villager where its routine is at
the skip's end: at the place of its current step, or on its way when the step began less long ago
than the walk takes (`place`, then `walk_to`). #68 only keeps the trips going and allows `place`
in a skip. The routine hours inside a skip are 239's, not replayed one by one.

## Saving

Nothing new is saved and the save version stays: the position of every villager is saved already,
far ones included, and the masks are made again. A trip is not saved: on load, task 239 sends each
villager where its routine says at that hour, from where it stands, which costs one search each (a
moment's stand for a visible one). Until 239, a console `goto` is lost over a save.

## The village (#9, task 234)

Whatever the village puts into the world must come from `generate_chunk` or be an edit or a building
of `World`, never set on loaded chunks only, so the far view sees it. Its lanes (worn or a lane
terrain, #61 and #62) then cost what they cost near. The parity test gets a village case.

## The steps (each a commit that passes on its own, with its tests and doc lines)

1. **`TravelMask`, `TravelMasks`, `World.replay_edits` and `edited`**, and the build bench. Parity
   test: for several seeds and whole regions, the mask against `Npcs.can_stand_at` on every tile
   centre of the same chunk loaded with `add_chunk`. Cases: an object taken off, one put down, a
   big object whose origin is in the west or north neighbour (generated and placed), a building and
   its door tile, a gate, the player's fence, tilled soil and a path, mud at high and low tide, a
   seasonal plant dormant and present (a dormant one costs nothing), a deck over mud at high tide, a
   ditch, the dyke, an ewer, a hedge, the chunk and world borders, the wear. The raw cache warmed,
   then an object taken off and a fence put down, then the masks again: they follow the edits. An
   edit drops exactly the four masks; an edit made while a mask waits for its raw chunks is in the
   mask (no stale stamp can be published, see Invalidation). The world's generator is untouched;
   the worker's chunk equals the main thread's. **Done** (tests/test_travel_mask_*.gd,
   tests/test_travel_masks.gd).
2. **`TravelView`, WAITING in `PathSearch`, the far slot of `Pathfinder`**, and the far search bench
   with the pass-or-fail numbers. Tests: a far way equals the way found with the same chunks loaded;
   the rim: a loaded goal tile covered by a big object whose own chunk is not loaded is closed, and
   stays closed when that chunk loads; a search waits for a mask, goes on, and loses no neighbour;
   a far request runs while near ones are queued; NOT_LOADED is gone. **Done** (tests/test_travel_view.gd,
   tests/test_path_search_waiting.gd, tests/test_npc_trips_far.gd); the far search bench is below.
3. **Far walking in `NpcTrip`, `Npcs.update`, far wear, `NpcViews`.** **Done** (tests/test_npc_far_walk.gd,
   tests/test_npc_views.gd, `frames.gd`; numbers under Measured with villagers walking). Tests: a villager from far
   comes into the loaded area on its path and arrives at the goal; one leaves it and walks on; its
   position never moves more than `walk_speed x delta` in an update, also when its chunks load one
   an update or unload, and when that happens between two centres; the tide rising over a far path
   makes it search again, then wait; a crop edit at night drops the mask; far feet wear; no view for
   a villager on an unloaded chunk.
4. **Skips:** `catch_up` with minutes. **Done** (tests/test_npc_skip.gd, tests/test_npc_skip_world.gd,
   `NpcTravel.advance_skip`, `NpcSkip`, `TravelMasks.pin`; as built: tests/test_travel_masks.gd). Tests: a skip moves a trip as far as the same minutes of play
   (to the tile); one that ends in the skip arrives once; a trip without a path searches after it;
   the tide at the time of entry stops one, not the tide at the skip's end, on a far path and on one
   inside the loaded area, and likewise a seasonal plant; a sapling that grows into a tree on the path
   in the skip stops it there (the skip-end rule); a path over masks not yet stamped, longer than the
   LRU; synchronous and over frames end the same; `place` in a skip.
5. **While the player is inside:** `Npcs.update` and the trips go on, everyone on the masks.
   Tests: a villager sent off before the player goes in is at the tile the same minutes of play
   would take it when the player comes out; two whose trips cross while the player is inside meet
   (a rumour passes); none jumps more than `walk_speed x delta` on the way out. **Done**
   (tests/test_npc_inside.gd; `Npcs.update_unseen`, `NpcTravel.update`).
6. **The bench** (`tools/bench/paths.gd` of 238): 10, 30 and 155 villagers sent 100 to 300 tiles
   at once and through the day, cold and warm: longest frame, search time, the last departure's
   delay, memory. The numbers tuned and written here. **Done** (`tools/bench/paths.gd`; numbers and
   the tuning under "Measured, step 6"; `far_masks_kept` 256 -> 1024).

## Sol's second opinion

Followed: real paths over a view built from the generator and the edits, one position, never put at
the edge, one scheduler with a share for far work, tide and season checked at the time of use, a
coarse graph only if the bench asks for it, far feet wear. Not followed: a hand-over margin round
the camera rectangle (the loaded area is far enough, and the switch is invisible anyway); saving
trips and a save version bump (239 can send them again from the clock); splitting skips at
departures and routine hours (a skip is not watched, and 239 puts the villagers where their
routine is). The review's day budget of 130 s is 86 s: a game day is 960 seconds of play.

Sol then reviewed this plan and found the architecture and those departures sound. Its must-fixes are
in: raw chunks that hold no edits and stamps that are not published when stale, generating on a
worker and a whole-frame gate, the rim of the loaded square answered by the mask, and the skip's
times and missing masks. Its optional points are in too (WAITING loses no neighbour, the switch
between centres, the mask's order of deck, tide and dormancy). Its second check added: the time of
entry for the live answers too, the night's trees and stumps in a skip, masks pinned a few ahead
in a catch-up, the rules warmed before the worker, and a frame gate that counts all the work.

## The user's answers (2026-11-14)

1. Far feet wear lanes as near ones do: yes.
2. Trips are not saved, and 239 sends them again on load (no save version bump): yes.
3. After a skip, 239 puts villagers where their routine is, and the hours inside a skip are not
   replayed: yes.
4. **While the player is inside, villagers outside keep moving**, so that when the player comes
   out they are where one would expect them, not where they were when the door closed. This also
   matters for rumours ([gossip.md](gossip.md)): villagers who meet on their way while the player is inside
   pass on what they know as they would outside. See "While the player is inside" below.
5. How late may a departure be: 30 villagers leaving in the same minute are all on their way within
   10 s; 155 within 60 s.

## While the player is inside

The world's chunks are held while the player is inside (`_residency.is_held`), and the outside goes
on (built, step 5; before it stood still):

- `Npcs.update` and the trips run while the player is inside, with the clock, as in play. The
  chunks around the house stay as they are (held, not drawn); every villager walks as if far, on the
  masks, so nothing outside needs a view, an animation or a loaded chunk to move. The masks of the
  held chunks follow their edits as any other.
- When the player steps out, each villager is where its trip has taken it. One on a loaded chunk
  gets its view there; the rule that a position never jumps more than `walk_speed x delta` in an
  update holds, because nobody watched the minutes in between.
- Meetings count: two villagers whose trips bring them within the meeting distance while the player
  is inside meet as they would outside (gossip, greetings that change something). Whatever is only
  shown (a speech bubble, a wave) is not.
- Sleep and other skips stay as in "Time skips and sleep": the player sleeps inside, and 239 places
  villagers at the skip's end.
- As built: `Main._process` calls `Npcs.update_unseen`, with the player's feet
  infinitely far. An unseen update walks the trips with every step a far one (the mask, at the
  minute of entry), loaded chunks too, and leaves the strolling villagers standing. Meetings
  need nothing more: `GossipSpread` runs with the clock and looks at positions, views or not.
  No villager is inside a house (interiors hold none), so there is nothing to keep there.
- Cost: the same budget as outside (`Pathfinder`'s per-frame budget), and less drawing, since the
  outside view is hidden.
