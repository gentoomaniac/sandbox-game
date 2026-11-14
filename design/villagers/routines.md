# Homes, workplaces, routines and finding the way

Decided 2026-11-14 (the user): tasks 228, 237, 238, 239, 229 and 240 on the
[project board](https://github.com/users/gentoomaniac/projects/2). Built so far: homes and
workplaces (task 228) and own interiors (task 237). Today a villager keeps near an anchor (the yard of their home's door,
or of the nearest building or fireplace, [villagers.md](villagers.md)) and walks about it at
random.

- **Places of their own:** each villager has a home (a building) and a workplace (a building,
  or a named spot where there is none, such as a landing or a field). The hand-written sheets
  name them; the player can give a made-up villager a home and a workplace (task 228, built:
  see [villagers.md](villagers.md), `Npc.house`, `Npc.workplace`, `Households`).
- **Interiors:** a building type has one default interior. A building can carry its own
  interior instead, so a villager's house is their very own inside while the outside stays the
  type's standard look (task 237, built: `home_interior` of a sheet, `Building.furnish_from`, and
  [first-buildings.md](../building/first-buildings.md)).
- **Routines are generic:** a routine says what happens when, such as "work from 7 to 15, home
  at 15, sleep at 22", with a Sunday plan and changes for rain and the dark. The villager's own
  home and workplace fill in where that is, so many villagers share a few routines (task 239).
- **Finding the way:** villagers walk to their places by a path search that keeps to lanes and
  goes round fences and through gates and doors, within a set cost per frame so the game doesn't
  stutter. Far from the player: see #68 (task 238 plan).
- **Inside:** the routine says when they go in, and they are seen in the interior (task 229).
- **Next step, the shopkeeper:** a villager with the shopkeeper routine stands in their shop in
  the shop hours and offers a trading dialog (barter, no money yet); the shop sells seeds, so the
  farm can always start again (tasks 240 and 235).

Task 238's plan (the path search, its limits, chunks and doors) and task 239's plan (the
routine format and the routines themselves) are written here, for the user's approval before
code.

## Finding the way: the plan (task 238)

Written 2026-11-14, revised the same day after review and the user's answers; approved by the
user. Task 238 finds and walks ways in the loaded world. Off-screen travel is planned in #68.

**What is there.** A villager steps along a heading inside a circle about its anchor
(`Npcs._walk`), and asks the map only when its body moves onto new tiles (`_fits`, several
microseconds a tile). Nothing finds a way; `ReachableTiles` floods a small radius for the skip.
The player sees 7 x 7 chunks (`ChunkResidency.LOAD_RADIUS` 3, 224 tiles across); the rest is not
there to walk on. There is no lane terrain yet: the cheap tiles are the worn grass of
`World.wear_stage` (TRODDEN, PATH), which villagers' own feet make (`villager_step`).

### The search (`PathSearch`)

- **Own A\*, not `AStarGrid2D`.** The grid needs a fixed rectangle of cells with a solid flag set
  for each one: the world is 2048 x 2048 tiles, with chunks loading and unloading and edits (a
  chest, a fence) all the time. Keeping a grid in step costs more than most searches, and it
  cannot be paused and resumed. Our A\* reads the map as it goes and keeps only what it has
  visited, so nothing of the world is copied. Heap in packed arrays; keys are tile indexes
  (`y * width + x` of a window around start and goal) if hashing `Vector2i` shows in the bench.
- **It is given two Callables, not a map:** `is_free(tile)` and `cost_of(tile)`. `Npcs` builds them
  from a `GameMap` (the world or an `Interior`); 
  `cost_of` is where ground is weighted: today 1.0 on grass, 0.8 trodden (`World.wear_stage`, only
  on `World`), 0.6 on a path and +2.0 where a non-blocking object stands (crops, flowers: they walk
  round the field). Later ground changes it (mud to avoid, crafted roads to prefer, issues #61 and
  #62) by editing that one function, not the search.
- **Four directions** for now, from tile centre to tile centre. A body (0.6 wide, 0.3 high) on a
  centre stands on one tile, and between two centres on those two, so any path of free tiles can
  be walked and no corner is cut.
- **Which tiles:** exactly the villager's step rule, `Npcs.can_stand_at` (walkable, no building
  tile, door included). Fences, walls, water, flooded mud, objects that block walking and
  buildings stop it; a tile off the loaded chunks is a wall in 238. The start tile is not checked:
  a villager in a doorway or on mud must be able to leave it (as `_can_wade_out` does).
  `is_walkable` lets people through gates, shut or open (only animals are stopped,
  `stops_animals`), so villagers go through gates as the player does.
- **Heuristic:** Manhattan distance times the grass cost (1.0), knowingly inadmissible where
  lanes exist: a way up to about 1.67 times longer than the best may be taken, which is fine,
  since villagers take a lane when one is near. The admissible scale (the cheapest cost, 0.6)
  would expand the whole bounding box on plain grass (f = 0.4 a + 0.6 D never exceeds D), so it
  is only an option (`heuristic_weight`) for tests that compare optimal paths. Ties in the heap go
  to the larger g (the node nearer the goal). Step-1 test: an open 100-tile diagonal expands a few
  hundred nodes, not thousands.
- **Reading the map:** once per tile per search, remembered in the search's own dictionary.

### Long ways and the frame budget

- **A search can be paused:** `PathSearch.step(max_nodes)` goes on where it left off and says
  RUNNING, FOUND, LEG (see below) or FAILED. `Pathfinder` (one per `Npcs`) holds the queue and, in each frame, starts
  at most `searches_per_frame` (2) searches and spends at most `search_usec_per_frame` (1500 us)
  on all of them, oldest first. The clock is checked every 16 nodes and is a `Callable` that tests
  replace, so the tests of the limits count nodes and never time. A villager stands while its
  search runs. **The Pathfinder ticks inside `Npcs.update` only** (Main and
  `ActorsUpkeep.walked_minute` both call it), once per call, and not while the world is held (a
  skip over frames, a modal).
- **A search has a cap:** `max_nodes` (2500, from the measures below).
  One that reaches it takes the visited tile nearest the goal and the way to it as a **leg**; the
  villager walks it and searches again from its end. A leg end that is not strictly nearer the goal
  (in tiles, Manhattan) than the leg's start counts as no way, so within one chain of legs the
  distance to the goal only falls, a leg never repeats in a bay larger than the cap and no memory
  of leg ends is needed. A new chain (after STUCK or a blocked retry) starts again from none;
  `max_legs` (6) bounds each chain, for a way that gains a tile at a time. Test: a goal behind a
  wall longer than the cap is found to have no way within 2 legs.
- **Throughput:** measured in step 1 (`tools/bench/path_search.gd`, 100 searches over the real chunks
  of seed 7, on a busy machine): 26 us a node. At 1.5 ms a frame about 55 nodes are searched, so a
  1000-node search takes some 18 frames (0.3 s), one that uses the whole cap of 2500 about 45 frames
  (0.7 s; the cap was 4000 at first, see Performance), and 155 villagers
  who all leave at the same minute wait many seconds. A wait of some seconds is fine (they stand).
  Task 239 spreads the hours: each villager's routine is shifted by a fixed offset of a few minutes.
- **Paths are kept.** The path is an `Array[Vector2i]` on the trip; each next tile is checked when
  stepped on, and nothing is searched while the path holds.

### No way: the trip waits and looks again

There is no final failure. When no way is found (the search is exhausted, a leg makes no progress,
`max_legs` is used up, the goal is closed in or not loaded, or the walker is stuck at something
that is new) the trip is **blocked**: the villager stands, `trip_blocked(npc, reason)` is sent
once, and a new search is queued only when something could have changed: `World.change_count`, a
counter that rises on every edit (terrain, object, building) and every chunk load and unload, is
not what it was at the last search; at the most once in `blocked_min_seconds` (5), and anyway every
`blocked_fallback_seconds` (120), for what has no edit (the tide). In a static world a blocked
villager makes no second search before the fallback. A fence taken down, a chest taken away or a
chunk that has loaded can open a way; the villager then walks on and `trip_arrived` comes in the end. The trip goes on until the
routine changes it (`walk_to` again) or ends it (`cancel_trip`, which sends nothing). The
no-progress rule and `max_legs` stay: they stop a search from spending its cap again and again;
the retry spaces the next one. Reasons: NO_WAY, NOT_LOADED, STUCK.

### Doors and interiors

238 provides the search over any `GameMap`, and `walk_to_door(npc, building, map)`, which walks to the
yard in front of the door (`Building.yard`, where `Workplace.spot` already points) and reports
arrival there. It does not end on the door tile: `can_stand_at` and `_fits` refuse building tiles,
the door included. Task 229 adds going in as a step from the yard onto the door tile and into the
interior (as `GameState.pass_door` does for the player), the villager's own map (`Npc.inside`),
and the walk inside by the same search from `entry_tile` to a bed or a chair and back to
`exit_tile`. A `Trip` holds the map it is on, so 229 needs no new search, only the trip on the
other map.

### Following a path (`NpcTrip`, its own class and file)

`Npcs` is 342 lines already, so the trip state and the following live in `NpcTrip`; `Npcs.update`
hands a villager with a trip to it instead of the stroll. The trip has the map, goal, path, index,
`legs`, and a state SEARCHING, WALKING, WAITING (for the player) or BLOCKED.

- **Step:** heading for the centre of the next tile at `walk_speed`, `_fits` as before (so a thing
  placed in the way is noticed), the tile it leaves wears as now (lanes grow where they walk). No
  anchor circle on a trip. Villagers, the player and animals do not stop each other, as today; a
  villager stops short of the player (`personal_space`) as it does now.
- **Waiting is not stuck:** when `personal_space` holds it back from the player, or the player
  talks to it (`talk_to`), the trip is WAITING and the stuck timer does not run; talking pauses a
  trip, never ends it.
- **Stuck:** a step that does not fit, a tile that has gone under the rising tide, or no free way
  ahead for `blocked_give_up_seconds` (2, the animals' rule) searches again from where it stands,
  at most `retries` (2) times in a row; then the trip is BLOCKED as above. A path has no turning,
  so it cannot spin.
- **Arrival:** `trip_arrived` fires at once when the villager is on the goal already.
- **Day and night:** pathfinding knows nothing of them. `Npcs.update` no longer lets the villagers
  stand all at rest time: the stroll and the stand stop as now, but a trip goes on. Task 239's
  routines change the target when it gets dark.

### Far villagers

Off-screen travel is planned in #68. Until then a far villager (its own chunk is not loaded) or an
unloaded goal is BLOCKED with NOT_LOADED, no search is made while it is, and it looks again when
the world has changed (see above). Task 239 may put such a villager at its routine's spot with
`Npcs.place` (only for one whose own chunk is unloaded, to a tile in an unloaded chunk too; a
visible villager is never placed, and one that would pop into view is not either).

### The API for task 239

```
Npcs.walk_to(npc, tile: Vector2i, map: GameMap) -> void   # starts a trip, replacing any
Npcs.walk_to_door(npc, building: Building, map: GameMap) -> void   # to the yard
Npcs.cancel_trip(npc) -> void                             # sends no signal
Npcs.place(npc, tile, map) -> bool   # false (nothing done) unless villager and tile are both in
                                     # unloaded chunks; the anchor is the routine's to move
signal trip_arrived(npc)
signal trip_blocked(npc, reason)  # once, when no way is found; NO_WAY, NOT_LOADED or STUCK.
                                  # NOT_LOADED may come from `walk_to` itself, at once
```

`npc.is_travelling()` says whether a trip is on. A routine calls `walk_to` when its hour changes
and waits for `trip_arrived`; on `trip_blocked` it may leave the trip (it looks again by itself)
or send the villager elsewhere. It knows nothing of legs, searches or retries.

Console: `goto <villager> <x>,<y>|here` (the `place` argument kind learns `x,y`), answering "on its
way, 34 tiles" or "no way for now". F4 shows one line (an overlay of its own, `PathsHud`) for the nearest
villager on a trip: `path antje: (12,4) -> (30,9) 34 tiles, 12 done, leg 1, searched 410 nodes 2.1 ms`.

### What the numbers are for (`data/npcs.cfg`, a new `[travel]` section, read by `NpcRules`)

Nothing in them decides what a villager does; they say how much the game may spend and how the
walkers behave, so they can be tuned without code:

- **What a way costs:** `cost_trodden`, `cost_path`, `cost_object`: how much a villager prefers a
  worn lane to grass and avoids crops. `heuristic_weight`: how eagerly the search heads for the goal.
- **How much work:** `max_nodes` the tiles one search looks at before it
  settles for a leg; `max_legs`; `searches_per_frame` and `search_usec_per_frame` what all searches
  may spend in one frame, so the game never stutters.
- **How a walker behaves:** `blocked_give_up_seconds` and `retries` (when it counts as stuck and
  looks again), `blocked_min_seconds` and `blocked_fallback_seconds` (how soon a blocked trip looks
  again after the world changed, and how often when nothing seems to have: the tide).

### Performance

- **Budget:** path work at most 1.5 ms in any frame (`search_usec_per_frame`), and the bench's
  longest frame (about 26 ms today with 155 villagers) not longer than before.
- **Measure:** the time per node, in step 1 (`tools/bench/path_search.gd`): 26 us. The whole
  cost, in step 5 (`tools/bench/paths.gd`): the bench fixture with its 155 villagers and the 13 x 13
  chunks round the player loaded; three rounds of 150 s of frames at 60 per second, in each the first
  n villagers are sent 60 to 120 tiles to a tile they can stand on, trips still on at the end of a
  round are ended; one core, niced, a busy machine. Standing and strolling, the villagers' `update`
  costs 0.32 ms a frame (longest 5.7 ms). Results (`update` is the mean of the last round, over
  all frames; "blocked" is the trips told as blocked, all with no way; the wait is for the first
  leg; the whole trip is of those that arrived, 60 to 120 tiles at 1.5 tiles a second take 40 to 80 s):

  | sent | `max_nodes` | `update` | trips | arrived | blocked | whole trip, mean | first leg, mean, longest |
  |---|---|---|---|---|---|---|---|
  | 10 | 4000 | 0.49 ms | 30 | 70 % | 9 | 90 s | 4.0 s, 6.9 s |
  | 10 | 2500 | 0.41 ms | 30 | 73 % | 6 | 85 s | 2.2 s, 4.7 s |
  | 10 | 1500 | 0.41 ms | 30 | 67 % | 10 | 80 s | 1.8 s, 3.0 s |
  | 40 | 4000 | 0.71 ms | 120 | 78 % | 23 | 90 s | 10.2 s, 21.7 s |
  | 40 | 2500 | 0.64 ms | 120 | 86 % | 17 | 87 s | 7.2 s, 13.9 s |
  | 40 | 1500 | 0.58 ms | 120 | 79 % | 23 | 85 s | 5.6 s, 11.6 s |
  | 155 | 4000 | 1.93 ms | 465 | 79 % | 74 | 108 s | 34 s, 72 s |
  | 155 | 1500 | 1.55 ms | 465 | 78 % | 94 | 101 s | 24 s, 48 s |

  What this shows: the cap hardly changes whether a villager gets there (67 to 86 %, the rest are
  goals with no way, in or across water, or trips cut at the end of a round) or how long the whole
  trip takes (walking is most of it), but a smaller cap makes the first leg start sooner; 1500 is
  blocked as often as 4000 with 10 or 40 sent and more often (94 against 74) with 155, so 2500 is
  the cap: no more blocked than 4000 (fewer, 6 and 17 against 9 and 23, within the noise of one seed),
  a first leg that starts 30 to 45 % sooner. The time of a frame with trips is the 0.3 ms of walking and
  strolling, plus the 1.5 ms the searches may take when there are enough of them, plus a little for
  the steps; the longest `update` stays at 3.4 to 7.4 ms, as without trips (5.7 ms).
  `heuristic_weight` 1.0, 1.5 and 2.0 made no difference to the waits (the cost is in the long ways
  through ditches, not on the open grass), so it stays 1.0, and more time for the searches (3 ms) does
  not help a crowd either: 155 villagers who all start a long way in the same minute wait 24 to 34 s
  for their first leg. That is for task 239: spread the hours (each villager's routine shifted by a
  few minutes) so that a handful start in the same second.

### The steps of 238 (each a commit that passes on its own, with its tests and doc lines)

1. **`PathSearch`**, the `[travel]` data and a small time-per-node bench: A\* over `is_free` and
   `cost_of`, tie-breaking, the cap, legs with the no-progress rule, resuming. Tests: a way round
   a fence, through a gate; none into a closed-in place (no spinning); a path preferred over grass
   at equal length; an open 100-tile diagonal expands a few hundred nodes; a goal behind a wall
   longer than the cap is found to have no way within 2 legs; resuming in pieces finds the same
   path as in one go; an unloaded chunk blocks; a start on a building tile or mud still leaves; an
   `Interior`.
2. **`Pathfinder`** queue: searches per frame and the budget, by node counts and an injected clock.
   Tests: never more than the limits in a frame, all done in the end, oldest first, a dropped
   request is never run.
3. **(a) `NpcTrip` in `Npcs`, and `World.change_count`:** the counter (it rises on every edit
   of terrain, object and building, and on every chunk load and unload; a test for each), `walk_to`, following, `cancel_trip` (fires none), re-search, BLOCKED
   and the retry, the signals, ticking in `update`, trips going on at rest time. Tests: it arrives
   (at once if there already); a chest placed on the path is gone round; a path shut off blocks once
   (one `trip_blocked`), does not move, makes no second search in a static world before the
   fallback, and walks and arrives when the fence is taken down; the
   player's space and `talk_to` do not count as stuck; a trip goes on at night.
   **(b) `place`, `walk_to_door` and the unloaded:** a villager off the loaded chunks, or with a goal
   off them, is BLOCKED with NOT_LOADED and searches nothing; it walks when the chunks load; the
   Pathfinder queue is empty after a skip (the many `update` calls of `walked_minute` spend no
   tick); a visible villager is never placed.
4. **Console `goto` and the path overlay (F4).** Tests: the command's parsing and its answers.
5. **The bench** `tools/bench/paths.gd`, the numbers tuned from it and written here.

### Open questions

The user answered them on 2026-11-14: gates are passed as the player does, no diagonals, a trip
with no way waits and looks again, nobody collides with anyone, the costs as proposed (to be
changed with mud and roads later, issues #61 and #62), the numbers in `[travel]`, night is the
routines' and off-screen travel is #68.
