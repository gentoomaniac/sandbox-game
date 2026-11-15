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
  loaded chunks only. It does not run while the player is inside. A skip makes up the rest of its
  time in `catch_up`, which today only puts loaded villagers somewhere around their anchors.

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
  that world and calls `update` once a frame; `game/state/travel_masks.gd`): an LRU of masks (256,
  about 0.4 MB) and an LRU of raw chunks (16, about 5 MB). The two numbers are `far_masks_kept` and
  `far_chunks_kept` of `[travel]` in data/npcs.cfg (`TravelMasks.for_world(world, rules)`; the
  constructor takes the numbers). A raw chunk is what the generator makes and
  nothing else: no edit is ever applied to it, so it never goes stale (the seed does not change).
  A mask of chunk C is stamped from the raw chunks C, W, N and NW (big objects reach east and south,
  `MAX_FOOTPRINT` 7 x 2 within 32 tiles), with the edits of those four chunks replayed on copies of them
  (`World.replay_edits`, the code `add_chunk` uses: an edited position loses its generated object
  and gets the edit's, if any; an edited terrain replaces the generated one). `mask_of(coords)`
  returns the mask or null and asks for it; `update()` runs once a frame; `wait_for_mask(coords)`
  waits for the worker, for a time skip (step 4) and for tests.
- **Raw chunks are generated on a worker thread**, one at a time, by a `WorldGenerator` of its own.
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
  `update`, which is 0.08 ms at the median and 0.5 ms at most. One job at a time, a stamp before a
  generation. The raw chunks a pending request needs are never evicted, whatever the limit.
  (Pausing `generate_chunk` across frames would mean rewriting the generator; on the main thread
  one call is 9 to 13 ms, too much at 60 fps.) The destructor waits for the worker.
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
  chunks. `Npcs.catch_up(map, seed, minutes)` learns the minutes of the skip (below).
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
3. **Far walking in `NpcTrip`, `Npcs.update`, far wear, `NpcViews`.** Tests: a villager from far
   comes into the loaded area on its path and arrives at the goal; one leaves it and walks on; its
   position never moves more than `walk_speed x delta` in an update, also when its chunks load one
   an update or unload, and when that happens between two centres; the tide rising over a far path
   makes it search again, then wait; a crop edit at night drops the mask; far feet wear; no view for
   a villager on an unloaded chunk.
4. **Skips:** `catch_up` with minutes. Tests: a skip moves a trip as far as the same minutes of play
   (to the tile); one that ends in the skip arrives once; a trip without a path searches after it;
   the tide at the time of entry stops one, not the tide at the skip's end, on a far path and on one
   inside the loaded area, and likewise a seasonal plant; a sapling that grows into a tree on the path
   in the skip stops it there (the skip-end rule); a path over masks not yet stamped, longer than the
   LRU; synchronous and over frames end the same; `place` in a skip.
5. **While the player is inside:** `Npcs.update` and the trips go on, everyone on the masks.
   Tests: a villager sent off before the player goes in is at the tile the same minutes of play
   would take it when the player comes out; two whose trips cross while the player is inside meet
   (a rumour passes); none jumps more than `walk_speed x delta` on the way out.
6. **The bench** (`tools/bench/paths.gd` of 238): 10, 30 and 155 villagers sent 100 to 300 tiles
   at once and through the day, cold and warm: longest frame, search time, the last departure's
   delay, memory. The numbers tuned and written here.

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

Today the outside stands still while the player is inside (`Npcs.update` does not run, and the
world's chunks are held: `_residency.is_held`). With the answer to question 4 the outside goes on:

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
- Cost: the same budget as outside (`Pathfinder`'s per-frame budget), and less drawing, since the
  outside view is hidden.
