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
  A building someone lives in is a workplace only for the people who live there; others work in
  a building nobody lives in (later a workshop) or at a spot such as a field (the user's answer
  of 2026-11-14, #69).
- **Interiors:** a building type has one default interior. A building can carry its own
  interior instead, so a villager's house is their very own inside while the outside stays the
  type's standard look (task 237, built: `home_interior` of a sheet, `Building.furnish_from`, and
  [first-buildings.md](../building/first-buildings.md)).
- **Routines are generic:** a routine says what happens when, such as "work from 7 to 15, home
  at 15, sleep at 22", with a Sunday plan and changes for rain and the dark. The villager's own
  home and workplace fill in where that is, so many villagers share a few routines (task 239).
- **Finding the way:** villagers walk to their places by a path search that keeps to lanes and
  goes round fences and through gates and doors; the search runs on a worker thread so the game
  doesn't stutter (see [../tech/pathfinding.md](../tech/pathfinding.md)). Far from the player,
  where the world isn't loaded, they walk too: see [travel.md](travel.md) (#68, being built).
- **Inside:** the routine says when they go in, and they are seen in the interior (task 229).
- **Next step, the shopkeeper:** a villager with the shopkeeper routine stands in their shop in
  the shop hours and offers a trading dialog (barter, no money yet); the shop sells seeds, so the
  farm can always start again (tasks 240 and 235).

Task 238's plan (the path search, its limits, chunks and doors) is written here, and task 239's
plan (the routine format and the routines themselves, "Routines: the plan" at the end), for the
user's approval before code.

## Finding the way: the plan (task 238)

**2026-11-15, as built in #68:** a search now runs on a worker thread, one task each, over the
travel masks and a snapshot of the buildings and wear, not over the live world; the frame budget
(`searches_per_frame`, `search_usec_per_frame`) below is gone, replaced by `search_tasks`, and the
walker's give-up time is 0.5 s. How it works now is in [../tech/pathfinding.md](../tech/pathfinding.md);
this section is the plan as approved, with those parts marked.

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
- **Reading the map:** once per tile per search, remembered in the search's own dictionary. (#68:
  through a `TravelView` over the masks, not the map; the Callables are the view's.)

### Long ways and the frame budget

*(Superseded in #68: no budget; each search is a task on a worker, `Pathfinder` only dispatches and
collects. The text below is the approved plan.)*

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

## Routines: the plan (task 239, issue #7)

Written 2026-11-15, for the user's approval before code. It builds on the homes and workplaces
(task 228, #69), the path search and trips (#6, #68) and their API (`walk_to`, `place`,
`trip_arrived`, `trip_blocked`, [travel.md](travel.md)). It needs no change to a trip itself.

### The idea

A routine is a list of steps for a kind of day: **from this time, be at this place, doing this**.
The place is a kind (`home`, `work`, `church`, `meeting`), never a tile: the villager's own home
and workplace say where it is. So a handful of routines serve every villager. The routine moves
the villager's anchor: at each step the anchor is the place, and the villager strolls about it as
today (`Npcs._walk`), so the stroll code stays. A routine is only a plan: where the villager *is*
is where its walks have taken it.

### The format (`data/routines.cfg`, read by `RoutineRules`)

Same syntax as the other data files, with a comment for every key.

```
[rules]
; Each villager leaves up to this many minutes early, a fixed number from its name, so that
; they do not all start in the same minute (the searches of a crowd take seconds).
spread_minutes=10
; A way is this much longer than the straight line (tiles along x plus tiles along y).
detour_factor=1.3
; Minutes to spare on top of the estimated walk.
arrive_margin_minutes=3
; It rains for the routine when the mean rain of the hour is at least this (0 to 1).
rain_hour_limit=0.25
; Steps in the open end this many minutes after sunset and may start this many after sunrise.
dark_from_sunset_minutes=0
light_from_sunrise_minutes=0
; How far from their home the church (and the meeting place) is looked for, in tiles.
place_search=200.0

[places]
; The tiles about the place a villager keeps to, and how often it strolls instead of standing.
home={"radius": 3.0, "walk_chance": 0.5}
work={"radius": 1.5, "walk_chance": 0.3}
church={"radius": 2.0, "walk_chance": 0.2}
meeting={"radius": 4.0, "walk_chance": 0.7}

[doings]
; A doing is a word for the console and the prompt. These stand still (no stroll):
still=["sleep", "eat", "pray"]

[farmer]
works_in_rain=false
; [time, place, doing]. The time is "HH:MM" on the game clock. The steps of a plan go up in time;
; a day begins with the last step of the day before, so sleep runs over midnight.
weekday=[
	["05:30", "home", "eat"],
	["06:15", "work", "work"],
	["12:00", "home", "eat"],
	["13:00", "work", "work"],
	["18:00", "home", "eat"],
	["19:00", "meeting", "talk"],
	["20:00", "home", "rest"],
	["21:30", "home", "sleep"],
]
saturday=[...]   ; optional: the weekday's plan if left out
sunday=[...]
```

- **A step's place** is one of `home`, `work`, `church`, `meeting`. `doing` is free text (shown by
  the console, told to the language model); only the `still` ones change what the villager does.
- **Plans:** `weekday`, `saturday` (optional, so the Krug evenings of the sheets need no copy) and
  `sunday`, by `GameClock.weekday` (question 1).
- **Rain and the dark** are rules in the routine's code, not steps in the plan (below); the only
  key is `works_in_rain` (default false).
- Times are fixed clock times. Only the dark follows the sun (question 6).
- `RoutineRules.problems` checks the file: places and doings known, times going up, each plan
  ending in `sleep`, and the routines that a sheet or a trade names exist. A test runs it on the
  real file.

### The routines

Each is written once, by hand, from the `day` texts of the villagers who use it, and fits them as
far as places and hours can. The numbers are the first ones, to tune by watching (question 6).

| Routine | Weekday | Saturday | Sunday |
|---|---|---|---|
| **farmer** (farmhand, shepherd, dyke worker, peat cutter, day labourer, thatcher, carter) | eat 5:30; work 6:15 (field, barn); home 12:00 eat; work 13:00; home 18:00 eat; meeting 19:00; rest 20:00; sleep 21:30 | work to 16:00; home; meeting 18:30 (the Krug) to 22:00 | church 9:30; home 12:00 eat; meeting 14:00; home 17:00; sleep 21:30 |
| **fisher** (fisherman, fisherman's wife) | eat 5:00; work 5:45 (the landing); home 13:00 eat; mend nets at home 14:00; meeting 18:30; sleep 21:30 | meeting 18:00 to 22:30 | church 9:30; home 12:00 eat; meeting 14:00; sleep 21:30 |
| **miller** | eat 5:30; work 6:30 (the mill); home 12:00 eat; work 13:00; home 18:00; sleep 21:30 | meeting 18:30 to 22:00 | church 9:30; home; sleep |
| **keeper of the house** (farmer's wife, dairymaid, spinner, weaver, seamstress, washerwoman, cooper, tailor) | work 5:00 (milking); eat 6:30; work 7:30; eat 12:00; work 13:00; work 17:30 (milking); eat 18:30; rest 20:00; sleep 21:30 | the same | church 9:30; home 12:00 eat; sleep |
| **shopkeeper** (for #240) | eat 6:30; work 7:30 (the shop); home 12:00 eat; work 13:00; home 18:00 eat; meeting 19:00; sleep 22:00 | work to 16:00; meeting 18:30 | church 9:30; home; meeting 14:00; sleep 22:00 |

The keeper's `work` is mostly her own house (the dairy): the yard of her home, so no walk, only a
different doing.

### Which places are where

Each villager's places are resolved when a step starts (`RoutinePlaces`):

- **home:** the yard of their house (`house.yard()`). A villager without a house has no routine
  (below).
- **work:** their workplace (`Workplace.spot()`: the yard of a building, or the tile of a spot).
  With no workplace: `home`.
- **church:** the yard of the church nearest their home within `place_search`. Where none
  stands, the step is dropped (the step before goes on).
- **meeting:** the place the village names for it (task 234: the green, the Krug); until there
  is one, the yard of the church; with no church the step is dropped (question 3).
- **In the open** is a step at the meeting place, or at a work spot that is no building (a field,
  the landing). Work in a building (the barn, the mill, the shop, their own house) is under a roof.

### Rain and the dark

Worked out for the step that is on, never written into the plan:

- **Dark:** from `dark_from_sunset_minutes` after sunset to `light_from_sunrise_minutes` after
  sunrise (`Sun`: the winter day is short), a step in the open becomes `home`, doing `rest`. A
  farmer in January is home by sunset, not at 18:00, and the Saturday at the Krug is not in
  winter.
- **Rain:** while `Weather.rain_in_hour` (the mean of the hour, so it does not flicker from minute
  to minute; one region, so one value for everybody) is at least `rain_hour_limit`, a step in the
  open becomes `home` too, unless the routine has `works_in_rain=true` (the fisher: it is the sea).
- Nobody knows it will rain, so they leave when it does and come late if far. Inside sooner is
  automatic: the step stays, only its place is home.

### Leaving in time

The step's time is the time to be there. A villager leaves at

    time of the step - walk - spread offset - arrive_margin_minutes

- **walk** is an estimate: the tiles in x plus the tiles in y between the place of the step
  before and the new place, times `detour_factor`, over the pace. A villager walks one tile a
  game minute (`walk_speed` 1.5 tiles a second, 1.5 game minutes a second: computed from the two
  numbers, not written down). The real path is longer or shorter; the aim is "there within a few
  minutes of the hour", not to the minute. A late villager is late; nothing is made up.
- **The offset** is a number from 0 to `spread_minutes` made from the name (stable, not saved):
  each villager is early by its own few minutes, so 155 do not search in the same second.
- **The walk is cut to the length of the step before:** a way of two hours takes the whole step
  before (they are on their way all the time) and no more.
- A step with no walk (home to home) sends nobody.

### At a place

On arrival (`trip_arrived`) the anchor becomes the place and the radius that of the place kind
(`[places]`; a new `Npc.keep_radius`, not saved, instead of the global `anchor_radius`, for a
villager with a routine). The villager then stands and strolls about it as today (`walk_chance`), or
stands still if its doing is in `still`. A `work` step stands near its spot and now and then takes
a step: a farmer about the field spot, a shopkeeper within a tile or two of the counter. Anything
better than that (an animation at the work spot, going in to sleep) is not new here: going in is task
229 (`sleep` and `eat` at `home` then mean inside). Until then they stand in the yard.

### Who has which routine

- **A sheet** may name `routine="farmer"` (a new key of `VillagerRules`; the test of the sheets
  checks the name is in `data/routines.cfg`) and `skips=["church"]` (steps at those places are
  dropped: Momme goes to church only at Easter and Christmas, question 4).
- **A made-up villager** gets the routine of their trade: a third entry for each trade in the tables
  of `data/npcs.cfg`, next to the trade's `day` text, so both are written side by side:
  `["a farmhand", "Works on a farm ...", "farmer"]`. The trade text is saved (`Npc.trade`), so no
  routine is saved: `RoutineRules.routine_of(npc)` finds it again by the sheet's id or the trade.
  A trade the tables no longer have (an old save) gets `keeper_of_the_house`. A test: every
  trade of the tables has a known routine.
- **The eight sheets:** `antje` keeper of the house, `hinrich` and `boy` farmer, `momme` and `inken`
  fisher, `ocke` and `gesche` miller (Gesche works the mill with him), `kerrin` keeper of the
  house (her dawn walk on the dyke and her visits are only in her `day` text).
- **No routine:** a villager with no house keeps the anchor rule as today (the yard of the nearest
  building or fireplace, a stroll within `anchor_radius`, still at night). So does one whose house
  is taken down (`building_gone`), until given another. A villager with a house but no workplace
  has the routine, and their `work` is `home`.

`Npcs.update`'s night rest (`is_rest_time`) applies only to villagers without a routine: the
routine's sleep is theirs.

### The `day` text and the routine

**Proposed: the routine is written from the text, by hand, once; the text stays.** The `day` text
is the user's own, written for the language model, with the flavour (the Husum market on Thursdays,
the dyke walk). A routine can only say where and when; it could not make that text, and making the
text from the routine would lose it. So the table above is written from the eight `day` texts, the
trade tables carry text and routine side by side, and what the routine can't say stays in the text
only. So that the model never says other than what the villager is doing, the prompt gets one line
from the routine: "Right now you are at the landing, mending nets" (place and doing, in the console's
words), and the text becomes "your usual day". That is the last step (question 5).

### How it runs (`RoutineUpkeep`)

`RoutineUpkeep` is a `SimulationSystem` of GameState, in front of `ActorsUpkeep`. It runs from the
clock, not from a frame, so it goes on while the player is inside ([travel.md](travel.md), "While the
player is inside") and the same code serves a skip.

- **Each game minute** (`advance`): for each villager with a routine, the step that is on (the last
  whose departure has come: `RoutinePlan.step_now` takes the plan of the day by `GameClock.weekday`,
  the previous day's last step before the first, then the rain and dark rule). If its place or
  doing differs from `npc.routine_step` (not saved), `Npcs.walk_to` sends them (no trip if they are
  within the radius of the place already) and the step is kept. Nothing is sent again while the step
  is the same, so a blocked trip looks again by itself (#68) and nothing searches twice a minute.
  `trip_blocked` is left alone; the console tells it.
- **Rain** is looked up once an hour, for all.
- **A change of place** (`Households.changed`, new: a house given or taken or taken down, a workplace
  given or lost) makes the villager look again at once.
- **Cost:** a lookup of a few comparisons for each of 155 villagers a game minute (every 0.67 s of
  play), expected well under 0.1 ms, measured in step 10. A search only when a step changes, at
  the hours the villagers go, spread by the offset.

### Skip and sleep

A skip is not watched, so each villager is where the routine says at the skip's end, as
[travel.md](travel.md) has it ("What 239 does"); the hours inside the skip are not replayed one by
one. `RoutineUpkeep` ignores the `advance` of a skip's rest (it is set by `skip_begins`) and
`ActorsUpkeep.skipped` gives `Npcs.catch_up` the routine as a Callable (`routine_place`), which
`_catch_up_one` asks before it puts a villager on a circle, so `place` is allowed (`is_skipping`).
First a villager on a trip is walked by the skip's minutes, as #68 has it. Then, for the step that
is on at the end (the same rule as in play), which has its time `T`:

- one who should have left by `T - walk - offset - margin` and has had the walk's time since is
  **at the place** (`place`, the anchor set);
- one who left less long ago is **on its way**: `place` at the place of the step before, then
  `walk_to` the new one; it comes late by the time that has gone, and its search is after the skip
  (none in a skip, #68);
- one who has not left yet stays where it is, within the circle of its place;
- dice only for the stroll's spot: the same game skipped the same way ends the same.

The first three walked minutes of a skip are play, as before (`walked_minute` is the same
`advance`). After a night's sleep the village is as it should be at 6 o'clock: the farmers have
eaten and are on the way out. `place` and `is_skipping` are used as they are; the changes of the
other worker in `npc_travel.gd` are not touched.

### Loading a save

The positions are saved (far villagers too); a trip and the step are not. After a load
`RoutineUpkeep.resume` runs once: each villager with a routine gets the step that is on and is sent
to its place from where it stands (`walk_to`): one search each, no trip for one that is there. A
visible one stands a moment while its search runs; nobody jumps. A villager who comes into the
world (`spawn npc`, after `Households.settle`) is sent the same way.

### Console

`routine <villager>` says where they are going and why:

    Antje Boysen: keeper of the house, Sunday
    now: church (the church yard) since 09:30, praying; there
    next: 12:00 home, eating; leaves 11:41 (about 17 tiles, 19 min)
    rain: no, dark: no; leaves 4 min early
    trip: none

For a villager with no routine: "no house: keeps near its anchor (12.5, 8.5)". A blocked trip: "blocked:
no way for now". `COMMANDS` gets the entry (the `villager` argument, as `goto`) and the help
text.

### Save version

No bump: no field is new in the save. A save from before this loads, and every villager is sent where
its routine says (above).

### Tests

One file for each part, each short (`tests/test_routine_rules.gd`, `test_routine_places.gd`,
`test_routine_plan.gd`, `test_routine_upkeep.gd`, `test_routine_skip.gd`, `test_routine_console.gd`):

- **The file:** it parses; places and doings known; times going up; each plan ends in `sleep`;
  every sheet and every trade has a routine; a bad file is reported, not a crash.
- **The place for each hour:** a table for each routine, (day kind, time) to (place, doing), through
  a whole day, over midnight and on a Sunday. Day 1 is a Monday, day 7 a Sunday, and the week runs
  on across the year's end.
- **Sunday and Saturday:** the church step for those who have one; `saturday` falls back to the weekday.
- **Rain and dark:** in the open the step is home; under a roof it stays; the fisher stays in the
  rain; January's sunset sends the farmer home at 16:00; rain by the hour, not by the minute.
- **Places:** home, work (building, spot, none), church (none: dropped), meeting (church, none),
  a sheet with `skips`.
- **Arriving on time:** on a flat world (`NpcRoadCase`), each villager arrives within the margin and
  its detour of the hour, and leaves not before `step - walk - spread`; the walk is cut to the step
  before; a step with no walk sends nobody; a changed step replaces the trip; the same step is sent
  once.
- **No routine:** a villager with no house strolls about its anchor and rests at night as today.
- **Households:** `changed` after `move_in`, `move_out`, `give_work` and `building_gone`.
- **The skip rule:** at the place, on the way, not yet left; over frames and in one go end the same;
  the same seed ends the same; a villager on a trip is walked first.
- **Saving mid-way:** save during a walk and load: each villager is sent where the clock says,
  one search each, nobody at two places; a save of the version before still loads.
- **Console:** the answer with a routine (now, next, leaves), without, blocked, an unknown villager,
  the help text.

### The steps (each a commit that passes on its own, with its tests and doc lines)

1. **The file and `RoutineRules`:** `data/routines.cfg` with the five routines, `GameClock.weekday` and
   `is_sunday`, `problems`, the steps of a day in order. No game behaviour yet. Doc line: the format
   in the file's header.
2. **Who has which:** the sheet keys `routine` and `skips` (`VillagerRules`, the header of
   `data/villagers.cfg`), the third entry of the trades in `data/npcs.cfg` (`NpcRules`),
   `RoutineRules.routine_of`, the eight sheets. Tests: every sheet and trade has one.
3. **`RoutinePlaces`:** a place kind to a tile for one villager, with the fallbacks. Tests.
4. **`RoutinePlan`:** the step that is on, with rain and dark, the departure and the offset, all
   pure (clock, sun and rain are given). Tests: the tables above and the leaving in time.
5. **`RoutineUpkeep` and `Households.changed`:** sending, `Npc.keep_radius`, arrival, the night rest
   only for villagers without a routine, GameState wiring. The anchor text of
   [villagers.md](villagers.md) ("Where") changes in this commit. Tests: arriving on time, a change
   of step, no routine, the households.
6. **The skip:** `Npcs.catch_up`'s `routine_place`, the `skip_begins` flag. Tests. Doc line in
   travel.md: "What 239 does" is done.
7. **Loading and spawning:** `resume`. Test of saving mid-way. Doc line in travel.md ("Saving").
8. **Console `routine`.** Tests.
9. **The prompt line** ("Right now you are ...") and the doc: villagers.md ("Later: schedules"),
   and this page (the plan marked as built). Test of the prompt text. Last, because the user may
   drop it (question 5).
10. **The bench** for the minute's tick over 155 villagers (`tools/bench/`), the numbers written here.

### Open questions

1. **The week.** Day 1 is a Monday, so every 7th day is a Sunday and the week runs on across the
   year's 360 days (the calendar has no week now): `GameClock.weekday(day) = (day - 1) % 7`.
   Proposed: yes.
2. **A Saturday plan** besides weekday and Sunday (optional, the weekday's if left out), because the
   sheets have the Krug on Saturday evenings. Proposed: yes.
3. **The meeting place** until the village (task 234) names one: the yard of the church; with no
   church the step is dropped. Proposed: yes.
4. **Momme at church only at Easter and Christmas:** a sheet key `skips=["church"]` drops a
   place's steps for that villager. Proposed: yes, for Momme; Kerrin, Gesche, Ocke and the Boysens go
   every Sunday.
5. **The `day` text:** the routine is written from it by hand and the text stays; the prompt says
   what they are doing now (step 9). Proposed: yes. Making the text from the routine is not
   proposed: it would lose the flavour.
6. **Fixed clock hours,** only the dark following the sun (a sun-relative plan is more work, and the
   order of its steps changes over the year). Proposed: fixed; look at winter and summer in play and
   change the hours, or allow `sunrise+0:30` as a time, if it looks wrong.
7. **The fisher and the tide:** Momme goes out "with the tide, early or late as it falls". Proposed:
   fixed hours first; tide-keyed hours are an issue of their own.
8. **Rain:** the hour's mean rain of at least 0.25 sends a worker in the open home; the fisher and
   anyone under a roof stay. Do storms and snow count too? Proposed: yes for storm, no for snow.
9. **A villager with a house but no workplace** has the routine and works at `home`; one with no
   house keeps the anchor rule (the issue says the anchor stays for "no home or routine").
   Proposed: yes.
10. **The departure estimate:** straight line (x plus y) times 1.3, plus 3 minutes, plus up to 10
    minutes of spread by name; a learned time per trip (the last real walk) is later. Proposed: the
    estimate, and look at how late they come in play.
11. **Console `routine <villager> <name>`** to give a villager another routine: not now (it would
    need a saved field and a save version bump). Proposed: show only.
12. **Gesche is a `miller` and Kerrin a `keeper_of_the_house`;** their `day` texts mention the dyke
    walk and visits that a routine can't show. Proposed: as written here.
