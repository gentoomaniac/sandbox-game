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
- **Activities and a planned day:** an activity is a verb with a target place relative to the
  villager ("goes to work", "picks flowers near home", "waters the fields"). Each villager has
  a set of them. A language model plans each villager's day from their set before the day starts;
  when it is late or fails, a default day is worked out from the activities' default times
  (task 239, [the plan below](#activities-and-the-planned-day-the-plan-task-239-issue-7)).
- **Finding the way:** villagers walk to their places by a path search that keeps to lanes and
  goes round fences and through gates and doors; the search runs on a worker thread so the game
  doesn't stutter (see [../tech/pathfinding.md](../tech/pathfinding.md)). Far from the player,
  where the world isn't loaded, they walk too: see [travel.md](travel.md) (#68, being built).
- **Inside:** the day's plan says when they go in, and they are seen in the interior (task 229).
- **Next step, the shopkeeper:** a villager with the shop's work activity stands in their shop in
  the shop hours and offers a trading dialog (barter, no money yet); the shop sells seeds, so the
  farm can always start again (tasks 240 and 235).

Task 238's plan (the path search, its limits, chunks and doors) is written here and built; task
239's plan (the activities and the planned day) is at the end, for the user's approval before
code.

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
  round the field). Later ground changes it (crafted roads to prefer, issue #62; mud was left out of it, #61:
  design/world/desire-paths.md) by editing that one function, not the search.
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

## Activities and the planned day: the plan (task 239, issue #7)

Written 2026-11-15 after the user's clarification on #7, rewritten the same day with the answers of
[#87](https://github.com/gentoomaniac/sandbox-game/issues/87),
[#88](https://github.com/gentoomaniac/sandbox-game/issues/88) and
[#89](https://github.com/gentoomaniac/sandbox-game/issues/89). **Plan: steps 1 to 12 of "The steps" are built** (issue #7; each says **Done** there), saving (13) and the bench (14) are not. It
says what will be built and in which steps. It replaces the first plan (fixed timetables for five
kinds of work), whose parts that still fit are kept: leaving in time, skip and sleep, loading, the
console, the place lookup. It builds on homes and workplaces (#69), the path search and trips (#6,
#68: `walk_to`, `place`, `trip_arrived`, `trip_blocked`, `Npcs.update_unseen`, `NpcTravel`, the
catch-up of a skip: [travel.md](travel.md)), the language model's chat
([dialogue.md](dialogue.md)), the calendar of #85 (seasons of 35 days, a week of 7, day 1 a
Monday; `GameClock.weekday()`, `day_of_year()` and their `_of(day)` forms exist) and the village
(#9, `design/world/wehlsbuell.md` on the branch `plan/9-village-v2`).

### The decisions

| Question | Decision | From |
|---|---|---|
| Day 1 a Monday, a Saturday plan, the church yard as meeting place until the village names one, Momme at church only at Easter and Christmas | as proposed | #77 |
| The week and the feasts: Easter is day 14 of the year, Christmas day 140 | as proposed | #87 |
| The planning hour: 18:00 for tomorrow | as proposed | #87 |
| Who the model plans for | **the villagers nearest the player**, always, up to a cap, and while the player moves the ones who come near are planned for the current day in the background; the hand-written eight have no priority | #87 (changed) |
| What an activity may change in the world | nothing in the first version | #87 |
| The sleep screen | **ends with a "press to continue"**; it will show more later, and the wait gives the model time for the next day's plans | #87 (changed) |
| Fields have no owner; a villager works the nearest | as proposed | #87 |
| The model: the profile in use in Settings | as proposed | #87 |
| A late plan takes over from the minute it comes | as proposed | #87 |
| Default times are fixed clock hours; the tide is the default work hours; rain counts at an hour's mean of 0.25 (storm yes, snow no); the departure estimate (x plus y, 1.3, 3 minutes, up to 10 of spread); console only shows and `replan`s; the prompt is English | as proposed | #88, #89 |

The user's answers on #87 changed two things, so they have their own sections: "Who is planned and
when" and "The sleep screen".

### The idea

- An **activity** is a verb with a target: "go to work" (target: their workplace), "pick flowers"
  (a wild spot near home), "water the fields" (the field nearest their home), "go to church".
  The subject is the villager who has it; the target is a kind of place, resolved *for that
  villager*, never a tile in the data. An activity may have a default time.
- A villager has a **set** of activities, from their sheet and their work.
- A **day** is a list of (activity, start time) for one villager and one calendar day. It is
  planned by the language model, in the evening before for the villagers near the player and
  during the day for those who come near. When there is no plan (late, failed, not set, not asked
  yet) a **default day** is made from the activities' default times. The default day is a pure
  function of the villager, the day and the world's seed.
- The villager *executes* the day: leaves in time, walks there (task 238), does the activity. The
  plan decides where they are; the model never moves anyone, and what it says is checked first.
- The stroll code stays. At a place a villager strolls or stands as the activity says. The anchor
  rule of villagers.md stays for a villager with no house and for the gaps in a day.

### The activity format (`data/activities.cfg`, read by `ActivityRules`)

Same syntax as the other data files, a comment for every key. One section for each activity, and
`[sets]` for the sets.

```
[rules]
; A way is this much longer than the straight line (tiles along x plus tiles along y).
detour_factor=1.3
; Minutes to spare on top of the estimated walk.
arrive_margin_minutes=3
; Each villager leaves and starts up to this many minutes off the default time, a number from its
; name and the day, so that they do not all start in the same minute.
spread_minutes=10
; It rains for an activity when the mean rain of the hour is at least this (0 to 1).
rain_hour_limit=0.25
; How far from their home a field, the church, a friend's house and a wild spot are looked for.
search_tiles={"field": 40, "church": 200, "meeting": 200, "friend": 200, "wild": 30}
; A day has at most this many entries; two start at least this many minutes apart.
max_entries=12
min_gap_minutes=20
; Easter and Christmas as days of the year (a Sunday each), for "feast".
feasts={"easter": 14, "christmas": 140}

[tend_field]
; The words of the console and the prompt: "go to <verb>", "is <verb>-ing".
verb="tend the field"
; Where, relative to the villager: home, workplace, field, church, meeting, friend, wild.
target="field"
; What they do there: "stand" (still), "walk_about" (stroll within `radius`), "work" (stand at
; the spot, now and then a step, facing the work).
doing="work"
radius=2.0
; Default starts and lengths, [time, minutes]. A length is how long they stay at most: after it
; they have nothing planned and keep to their home yard as the anchor rule has it. Optional;
; without `at` the activity has no default time and is only in a day the model plans.
at=[["06:30", 330], ["13:00", 300]]
; When it can be planned. All optional. days: weekday (Monday to Friday), saturday, sunday,
; feast (Easter and Christmas). seasons: spring summer autumn winter.
days=["weekday", "saturday"]
seasons=["spring", "summer", "autumn", "winter"]
; In the open: it needs light and no rain, else the villager goes home (see "Executing a day").
needs_daylight=true
needs_dry=true
; Of two default entries that fall within `min_gap_minutes`, the higher priority stays.
priority=5
```

- **Targets** are `home` (the yard of their house), `workplace` (`Workplace.spot()`; with none:
  `home`), `field` (below), `church`, `meeting` (the village's, else the church yard), `friend`
  (the yard of the house of a villager of their `people`, picked from the day and the name) and
  `wild` (a walkable meadow tile 8 to `wild` tiles from home, picked from the day and the name,
  so it is the same spot all day and tomorrow's is another; only the tiles of loaded chunks are
  known, so a villager far from the player has none and the entry is skipped, as for a target that
  is gone: built in `ActivityPlaces`).
- **`field`** is the nearest cluster of tilled tiles within `search_tiles.field` of their home; with
  none, the workplace if it is a field spot (the sheet's `workplace_spot`), else the activity is
  not offered to the villager. Fields have no owner; a villager works the one nearest to them,
  which is the player's field too when it is nearest (the user's answer, #87). In Wehlsbüll the
  fields are enclosures that are not tilled (`design/world/wehlsbuell.md` on `plan/9-village-v2`,
  #9), so a field is also the nearest one of the village's fields, as the village keeps them.
- **The first activities,** written once, tuned in play: `sleep` (home, still, 21:30),
  `breakfast`, `dinner`, `supper` (home, still, 05:30, 12:00, 18:00), `rest` (home, walk_about,
  20:00), `work` (workplace, 06:30 and 13:00), `tend_field`, `water_field` (field, spring and
  summer, dry, 17:00 for an hour), `milk` (workplace or home yard, 05:00 and 17:30),
  `tend_animals`, `mend_nets` (home, 14:00), `pick_flowers` (wild, walk_about, spring and summer,
  dry, daylight, 15:00), `go_to_church` (church, Sunday 09:30 for 90 minutes),
  `meet_at_the_krug` (meeting, walk_about, Saturday 18:30 for three and a half hours, on weekdays
  19:00 for an hour for some), `visit_friend` (friend, Sunday 14:00), `walk_the_village`
  (meeting).
- **Sets** (`[sets]`) name a list each: `base` (sleep, the three meals, rest; everybody), `farmer`
  (work, tend_field, water_field, meet_at_the_krug), `fisher` (work, mend_nets, ...), `miller`,
  `keeper_of_the_house` (milk, tend_animals, ...), `shopkeeper` (work, for #240). A villager's
  activities are `base` plus the set of their work plus their sheet's own extras, minus `skips`.
- **What an activity may change in the world: nothing, in the first version.** An activity says
  where the villager is and how they stand there, with the footprints their feet make anyway.
  They do not till, water, harvest, pick or carry. Flowers are decorations and cannot be picked;
  fields stay as the player left them, because what happens to a farm unseen would be an unfair
  surprise. Later an activity may get an `effect` out of a short list, each its own issue, capped
  and visible: `water` (the moisture of tilled tiles near the spot rises a little, never above
  what rain gives), `feed` (chickens). The user's answer (#87): nothing in the first version.
- `ActivityRules.problems` checks the file: keys known, targets and doings known, times as
  "HH:MM" and in the day, lengths positive, sets naming known activities, every sheet and trade
  naming a known set, every activity in some set. A test runs it on the real file.

### Who has which activities

- **A sheet** may name `activities=["visit_friend"]` (extras to its work's set, a new key of
  `VillagerRules`, checked against the file) and `skips=["go_to_church"]` (never planned for them).
  `church_feasts_only=true` (Momme) makes `go_to_church` fit only on a `feast` day, a day of the
  year in `[rules].feasts`.
- **The work's set** comes from the sheet's `work_set` (a key of its own) or, for a made-up
  villager, from their trade: a third entry in the trade tables of `data/npcs.cfg`, next to the
  trade's `day` text (`["a farmhand", "Works on a farm ...", "farmer"]`). The trade is saved
  (`Npc.trade`), so the set is found again by the sheet's id or the trade and nothing of it is
  saved. A trade the tables no longer have (an old save) gets `base` only. A test: every trade has
  a known set.
- **The eight sheets:** `antje` keeper_of_the_house; `hinrich` and `boy` farmer; `momme` and
  `inken` fisher (Momme with `church_feasts_only`); `ocke` and `gesche` miller; `kerrin`
  keeper_of_the_house with `activities=["visit_friend"]` (her visits).
- **The `day` text** of a sheet stays as it is, told to the language model for chat and for the
  plan alike. The activities are written *from* it, by hand, once, and what no activity can say
  (the Husum market, the dyke walk) stays in the text only, where the model may use it for a
  `why`. The text is never generated from the activities (it would lose the flavour).
- **No home:** a villager with no house (or whose house is taken down) has no entries in the
  default day: nothing sends them anywhere and the anchor rule has them stroll by day and rest at
  night, as they do now. No model query is made for them. (The first plan gave them
  `walk_the_village` and `sleep`; that is what the anchor rule does already.)

### Who is planned and when (`DayPlanner`)

- **Nearest first, always.** The model plans the villagers **nearest the player**, within
  `plan_radius_tiles` (a new `[plan]` section in `data/npc_talk.cfg`; 120, tuned in play), nearest
  first. The hand-written eight have no priority: far from the player they have the default day
  like anyone else. Villagers with no house, and everyone when no model is set
  (`NpcDialogue.has_model`), have the default day and no query is made, with no notice: the
  default day is the game without a model.
- **In the evening.** At `plan_hour` (18:00) the planner queues one query for each villager in
  the radius with no plan for tomorrow yet, nearest first, at most `max_per_night` (12). It has six
  game hours (four real minutes) before midnight.
- **While the player moves.** Once a game minute the planner looks at where the player is. A
  villager who has come into the radius and has no plan for the day (and has not been asked for it)
  is queued for **the current day**, behind what is queued, at most `max_per_day` (12) such queries
  a game day. The query says what time it is, and the plan is for the rest of the day (see "The
  answer"). The point is that the villager has a plan when they come into view, as far as the model
  is quick enough. The check is a distance for each villager without a plan: a few hundred
  comparisons a minute.
- **A villager seen before the plan is ready starts on the default day** and switches to the
  model's plan when it arrives. The plan takes over from the minute it arrives, and the villager is
  sent to whatever is on then (`walk_to`): nobody jumps, and a visible one simply walks from where
  they stand. A plan for the rest of today replaces the default entries from its first entry on; the
  default entries before it stay.
- **A day with no plan at its start** (a new game, a spawned villager, an old save, a long skip,
  the villagers the evening did not reach) is the same case: the default day, and a query for the
  current day when the villager is in the radius.
- **One at a time, in the background.** The queue is a list in a node (`DayPlanner`, next to
  `NpcDialogue`) that awaits `NpcDialogue.ask(request, true)` for the first in the queue, then the
  next, like the judge of the stories ([gossip.md](gossip.md)). `ask` is an HTTP request the
  engine runs off the main thread, so the game goes on while it is awaited. The queue pauses
  while a chat reply is awaited, so the player's talk is never behind a villager's plan. Entries of
  the evening come before those of the day; within each, the nearest to the player *now* first (the
  order is looked at again when the next one is taken from the queue). One that has left the radius
  before its turn is dropped from the queue (the planner has no view; being near is all it knows):
  it is queued again when it comes back (for the evening's, tomorrow's current-day query).
- **Quiet.** Each query is quiet (`is_quiet`): no notice per villager when it fails, and no line in
  the log: the console tells it for the villager. Where the asking stands is `Npc.asked_plans`
  (`{day: DayPlan.WAITING or FAILED}`, not saved), which is also how a villager is not asked twice
  for a day; `routine` says "the model is asked" or "gave no plan in time, or none the game could
  use" (it can't tell a late answer from an error: `ModelChat.answer` gives "" for both).
- **Timeout.** `timeout_seconds` in `[plan]` (20; the chat's is 30) for each query, through
  `ModelChat.answer`. An answer that does not come in time, comes as an error, or cannot be read is
  "no plan": the default day stays, and the villager is not asked again for that day. No query for
  tomorrow starts after 23:50; one that is out may still come in. A plan whose day is over is
  dropped.
- **The profile and the cost.** The profile in use (Settings). `max_tokens` (400) and the
  temperature (0.6) of `[plan]` are the game's own; the profile's Settings win, as for the chat
  (`ModelChat.max_tokens_of`). A query is about 700 tokens in and 200 out: 24 a game day at the
  most, one game day being 16 real minutes. A local model gets the cut-down sheets
  (`has_full_sheets`).
- **What the prompt tells** (`NpcPrompt.plan_request`, system text in `[plan]`):
  1. who they are: the sheet's age, trade, personality, likes, wants, habits, people (kin and
     friends by name and kind) and the `day` text, full or cut down as for the chat;
  2. the day to plan: "Saturday, day 23, early summer", sunrise and sunset, and the weather of
     that day, which the game knows exactly (weather is a function of the seed): "8 to 17 °C,
     rain from 14 to 17, wind 6 m/s", worded as a villager would see the sky (`WeatherDay`); for a
     plan of the current day also the time now, "plan from 14:20";
  3. their activities, each with its words, the walk from home to its place resolved for them ("11
     minutes' walk"), its default time and conditions; those whose place can't be
     resolved or whose days and seasons fail that day are left out, and `sleep`, the meals and
     `work` are always there;
  4. what they know that matters: yesterday's plan in one line (so a day follows another), up to
     `stories_told` of their latest stories and memories (as the bubbles have them);
  5. the format and the rules (below), and "keep to your usual day; vary it by the weather, the day
     and what you know; no new activities and no places that are not listed".
- **The answer** is JSON only:

  ```
  {"day": [{"activity": "breakfast", "at": "05:30", "why": "before the milking"},
           {"activity": "work", "at": "06:30", "why": "the barn needs mucking out"}, ...]}
  ```

  `why` is optional and cut to 60 characters; it is for the console. `DayPlanAnswer.parse` takes
  the text from the first `{` to the last `}` (a model wraps JSON in words or fences), then:
  - the `activity` must be in *this villager's* set with its place resolved, and its `days` and
    `seasons` must hold for the day; a `needs_daylight` one must start between sunrise and sunset;
  - `at` must be "HH:MM" from 04:00 to 23:30, and for a plan of the current day not before the time
    it was asked;
  - entries are put in time order; one that starts less than `min_gap_minutes` after the one
    before is dropped; at most `max_entries` stay;
  - **anything invalid is dropped** and the rest stands; for a whole day a `sleep` entry is added at
    its default time when none is left; an answer with fewer than 3 valid entries (1 for the rest
    of a day), or that does not parse, is no answer: the default day.

  The checks are pure and tested without a model.
- **What the player sees when it runs late:** nothing. They are not told. The villagers follow the
  default day until the plan comes, and then the plan from that minute on. The only sign is the
  console's `routine` ("default day: the model was late").

### The sleep screen

A night's sleep ends with a message on the black that waits for a key or a click, "press to
continue", as passing out does already (`FadeScreen.show_message`, the hint says "Press any key to
go on"); the sleep now shows a note for a moment (`show_note`) and goes on by itself. The user will
put more on that screen later.

- The world is made up for first (the skip, as now), then the screen waits. The planner goes on
  meanwhile, as it runs from frames, not from the player's input: the wait is time for the queue.
  The wait is as long as the player takes, with no timer and no sign that a model works.
- When the key comes, the day starts. Villagers with a plan have it; those without have the
  default day and switch when theirs arrives (above).
- The pass-out message stays as it is (it waits already).

### The default day (`DefaultDay`)

A pure function of the villager, the day number and the seed (no model, no saved state; tested
without a world):

1. Take the villager's activities that have `at` and whose `days` and `seasons` fit the day
   (Monday to Friday, Saturday, Sunday, feast days; the sheet's `skips` and `church_feasts_only`).
2. Each `at` pair becomes an entry, moved by an offset of 0 to `spread_minutes` made from the
   villager's name and the day (stable, not saved).
3. Where two entries are less than `min_gap_minutes` apart, the one with the higher `priority`
   stays (then the earlier). An entry that starts while an earlier one of the same or a higher
   priority is still on (within its length) is left out: the farmer's `work` of the afternoon
   keeps the flowers of 15:00 away, and the evening's `rest` the Krug's.
4. A `sleep` entry is always in it. A villager with no house has no entries at all (see "Who has
   which activities"): the anchor rule gives them their stroll by day and their rest at night.

Rain and the dark are not in the default day; they act while it is executed (next section), so a
day made a week ahead is as good as one made now.

### Executing a day (`ActivityUpkeep`)

`ActivityUpkeep` is a `SimulationSystem` of GameState, in front of `ActorsUpkeep`. It runs from the
clock, not from a frame, so it goes on while the player is inside ([travel.md](travel.md), "While
the player is inside") and the same code serves a skip.

- **The entry that is on** is the last entry of today's day whose leaving time has come; before
  the first one of the day it is the last of yesterday's (sleep runs over midnight). With none on
  (the length of the last one ran out) the villager keeps to the yard of their home as the anchor
  rule has it.
- **Each game minute:** for each villager, find the entry that is on, apply the rain and dark rule
  (below), and when its place or activity differs from the one sent last (`Npc.current_step`, not
  saved), `Npcs.walk_to` sends them (no trip if they are within the radius already). Nothing is
  sent again while it is the same, so a blocked trip looks again by itself (#68) and nothing
  searches twice a minute. A lookup of a few comparisons for each villager.
- **Leaving in time.** The entry's time is the time to be there. They leave at

      start time - walk - arrive_margin_minutes

  where the start time already holds the offset (`DefaultDay` moves each entry by it, so the villager
  leaves and starts a few minutes off the default time) and *walk* is an estimate: the tiles in x plus the tiles in y from the place of the entry
  before to the new place, times `detour_factor`, over the pace (a villager walks about one tile
  a game minute). The real path may be shorter or longer; the aim is "there within a few minutes
  of the hour". A late villager is late, nothing is made up. The walk is cut to the length of the
  entry before: a way of two hours takes all of the entry before and no more.
- **Arriving** (`trip_arrived`): the anchor becomes the place and the stroll radius the
  activity's (`Npc.keep_radius`, not saved, instead of the global `anchor_radius`). `stand` is
  still, `walk_about` strolls as `Npcs._walk` does, `work` stands near its spot and now and then
  takes a step. Going in (sleep and meals in the house) is task 229; until then they stand in the
  yard.
- **Rain and the dark** change what is on while it is on, not the plan. An activity with
  `needs_daylight` is not on from sunset to sunrise (`Sun`: the winter day is short), and one with
  `needs_dry` not while `Weather.rain_in_hour` (the hour's mean, one region, so no flicker) is at
  least `rain_hour_limit`. Instead the villager goes `home` and stands in the yard, and goes back
  to the entry when it holds again. Work in a building (the barn, the mill, the shop) has neither
  flag and goes on; the fisher's `work` has `needs_dry=false` (it is the sea). Nobody knows it
  will rain: they leave when it does, and come late if far.
- **The target is not reachable.** `trip_blocked` (no way, not loaded, stuck) leaves the trip,
  which looks again by itself. After `blocked_give_up_minutes` (30) without a way the entry is
  given up for the rest of its length: the villager goes home, and if home is blocked too, stays
  where they are within its circle. The console says "no way to the field since 06:12". A target
  that no longer exists when its time comes (the field is gone, the church taken down) is
  resolved again; with none, the entry is skipped and the one before goes on.
- **A change of place** (`Households.changed`, new: a house given, taken or taken down, a
  workplace given or lost) makes the villager look again at once.
- **While the player is inside** the day goes on, because the system runs from the clock and trips
  run unseen (#68).

### Skip and sleep

A skip is not watched, so each villager is where the day says at the skip's end, as
[travel.md](travel.md) has it ("What 239 does"); the entries inside the skip are not replayed one
by one. `ActivityUpkeep` ignores the `advance` of a skip's rest (it is set by `skip_begins`), and
`ActorsUpkeep.skipped` gives `Npcs.catch_up` the entry that is on as a Callable, which
`_catch_up_one` asks before it puts a villager on a circle (`place` is allowed in a skip). A
villager on a trip is first walked by the skip's minutes (#68), and then left to the next minute's
tick, which sends them where the day has them be (built so: the others get the following).
For the entry that is on at the end, or the next one if the time to leave for it has passed, which
starts at `T`:

- one who should have left by `T - walk - offset - margin` and has had the walk's time since is
  **at the place** (`place`, the anchor set);
- one who left less long ago is **on its way**: `place` at the place of the entry before, then
  `walk_to` the new one; they come late by the time that has gone, and the search is after the
  skip;
- one who has not left yet stays where they are, within the circle of their place.

Dice only for the stroll's spot: the same game skipped the same way ends the same. The first three
minutes of a skip are play. After a night's sleep the village is as it should be at 6 o'clock.

**The plan and a skip.** The skip does not wait for the planner: a night's sleep begins after
18:00, so tomorrow's plans are made or on their way, and the queue goes on over the skip and the
"press to continue" of [the sleep screen](#the-sleep-screen). At the end the villagers without a
model plan have the default day and are queued for the current day if they are in the radius. A skip
over several days gives default days to those, then one query each for the day it ends on.

### Loading a save, saving

The positions of the villagers are saved already. New: the **model plans** for today and tomorrow,
per villager: `{"day": 23, "whole_day": true, "made_at": 33180, "entries": [[activity, minute, why],
...]}` (a `DayPlan`, kept in `Npc.day_plans` by day, a few hundred bytes each; `made_at` is the game
minute it came, for the console, and `whole_day` is false for a plan of the rest of a day). Why: a load must not ask the model again (it costs, and the day would
change), and the console and the late rule need to know the day came from the model. A default
day is never saved: it is made again, the same. A trip and the current entry are not saved.

- **Save version:** the next free one at build time (44 on main, 45 once the map rework #60 and the
  village #9 have taken theirs), with an upgrade from the version before (it has no plans, so every
  villager has the default day until the planner asks), and the oldest upgrade dropped as the save
  file's header says. A commit of its own. Saves rotate (#16): each file carries its plans, nothing
  to do.
- **After a load** `ActivityUpkeep.resume` runs once: each villager gets the entry that is on and
  is sent from where they stand (`walk_to`): one search each, no trip for one that is there. A
  visible one stands a moment while its search runs; nobody jumps. A villager who comes into the
  world (`spawn npc`, after `Households.settle`) is sent the same way, and the planner queues
  the current day for them when they are in the radius.
- Plans of days gone by are dropped at each new day (`GameClock.new_day`).

### Console

`routine <villager>` says where they are going and why:

    Antje Boysen: today, Sunday, planned by the model at 19:40 yesterday
    now: go to church (the church yard) since 09:30, standing; there. Why: "the Sunday service"
    next: dinner at home, 12:00; leaves 11:41 (about 17 tiles, 19 min)
    rain: no, dark: no; leaves 4 min early
    trip: none

`routine <villager> day` lists every entry of the day with its time, activity and why, and the
default day beside it. A villager with no house: "no house: keeps near its anchor (12.5, 8.5),
default day". A blocked trip: "blocked since 06:12: no way for now". A late or failed plan:
"default day: the model was late" or "... answered with an error". `replan <villager>` queues a
query for the rest of today at once and says "asking the model" or "no model set: default day".
`COMMANDS` gets both with the `villager` argument, as `goto`, and their help texts.

### Cost

No per-frame work beyond walking (`Npcs.update`, as now). A minute's tick reads the entry of each
villager (a few comparisons; expected well under 0.1 ms for 155 villagers, measured in the last
step). A search only when an entry changes, at the hours villagers go, spread by the offset. The
model is asked 24 times a game day at the most (12 in the evening, 12 in the background), one at a
time, off the main thread; with none set nothing is asked. The radius check is a distance for each
villager without a plan, once a game minute. The prompt is built once a query (the weather of a day is cached,
`Weather.day_summary`).

### Tests

One file for each part, each short:

- **The file** (`test_activity_rules.gd`): it parses; keys, targets and doings known; times valid;
  every sheet, trade and set has known activities; a bad file is reported, not a crash.
- **The default day** (`test_default_day.gd`): a table for each set over a week, (weekday, time)
  to entries; Saturday, Sunday and the feast days; `skips` and `church_feasts_only`; the season
  filter; the same inputs give the same day; the offset is stable and within `spread_minutes`;
  overlaps resolved by `priority`; `sleep` always there; day 1 a Monday and the week running on
  across the year's end (140 days).
- **Validation of model answers** (`test_day_plan_answer.gd`), with no model: good JSON; JSON in
  words or fences; an unknown activity; one not in the villager's set; a wrong day or season;
  times out of range, out of order, too close, not "HH:MM"; too many entries; fewer than 3 valid
  (default); `sleep` added; a daylight activity at night dropped; `why` cut.
- **The planner** (`test_day_planner.gd`), with a fake `ModelChat`, as the dialogue tests have:
  one query at a time in the right order (the nearest first, the evening before the day, the order
  looked at again as the player moves); the radius and the caps; a villager who comes into the
  radius gets a query for the current day, once, and a plan for the rest of the day replaces the
  default entries from its first entry on; one who leaves the radius before its turn is dropped;
  no query with no model; a good answer sets the plan; a bad one leaves the default; the timeout path (a fake that
  never answers): no plan, the next villager is asked, the villager is not asked again that
  day; a late plan takes over from its minute; one whose day is over is dropped; the queue
  pauses during a chat; the prompt holds the sheet, the resolved places, the weather words, the
  weekday and season, yesterday's line.
- **Places** (`test_activity_places.gd`): home, workplace (building, spot, none), field (none, the
  workplace spot), church (none: not offered), meeting, friend, wild (stable all day, another
  tomorrow, walkable).
- **Executing** (`test_activity_upkeep.gd`): on a flat world (`NpcRoadCase`) each villager arrives
  within the margin and its detour; leaves not before `start - walk - margin`; the walk cut to
  the entry before; a changed entry replaces the trip; the same entry is sent once; rain sends a
  `needs_dry` activity home and brings it back; the fisher's work stays in rain; January's sunset
  sends the farmer home; a blocked trip gives up after the limit; a gone target; no house keeps
  the anchor rule and rests at night as today; `Households.changed`.
- **The skip** (`test_activity_skip.gd`): at the place, on the way, not yet left; over frames and
  in one go end the same; the same seed ends the same; a villager on a trip is walked first.
- **Saving** (`test_day_plan_save.gd`): model plans round-trip; a default day is not saved; a save
  during a walk and a load send each villager where the clock says, one search each, nobody at
  two places; the plan is not asked for again after a load; a save of version 43 loads.
- **The sleep screen** (an addition to the blackout tests): a sleep ends on the waiting message,
  goes on by a key or a click and not before; the planner's queue goes on during the wait.
- **Console** (`test_routine_console.gd`): the answer with a plan, with the default, blocked, no
  house, an unknown villager, `day`, `replan` with and without a model, the help text.

### The steps (each a commit that passes on its own, with its tests and doc lines)

The week (`GameClock.weekday()`, `day_of_year()`) is on main already (#85). Steps 1 to 9 need no
village: they run on the camp's villagers and on the test worlds of the road tests.

1. **The file and `ActivityRules`:** **Done.** `data/activities.cfg` with the activities and sets,
   `problems`. No game behaviour. Doc: the format in the file's header.
2. **Who has which:** **Done.** the sheet keys (`work_set`, `activities`, `skips`, `church_feasts_only`) in
   `VillagerRules` and the header of `data/villagers.cfg`, the third entry of the trades in
   `data/npcs.cfg`, the eight sheets. Tests: every sheet and trade has a set.
3. **`ActivityPlaces`:** **Done.** a target kind to a tile for one villager, with the fallbacks (`meeting`:
   the church yard, `field`: tilled tiles or the workplace's field spot). Tests.
4. **`DefaultDay` and the entry that is on:** **Done.** pure (clock, sun and weather given), with the leaving
   time and the offset. Tests: the tables above.
5. **`ActivityUpkeep` and `Households.changed`:** **Done.** sending, `Npc.keep_radius`, arrival, rain and
   dark, blocked trips, GameState wiring. The anchor text of [villagers.md](villagers.md)
   ("Where") changes here. Villagers follow the default day from this step on. Tests: executing.
6. **The skip:** **Done.** `Npcs.catch_up`'s entry Callable, the `skip_begins` flag. Tests. Doc line in
   travel.md: "What 239 does" is done.
7. **Console `routine`.** **Done.** Tests. (Before the planner, so the default day can be watched.)
8. **The sleep screen:** **Done.** a sleep ends on `FadeScreen.show_message` instead of the note. Tests. It
   is independent of the rest and may go in at any point; it is here so that it is in before the
   planner needs its wait.
9. **`DayPlanAnswer` and the plan on the villager:** **Done.** the parse and checks, whole day and rest of
   day, pure; `Npc.day_plans` (not saved yet) and the entry that is on reading a plan, with the
   default entries before a mid-day plan. Tests.
10. **`NpcPrompt.plan_request` and `WeatherDay`:** **Done.** the prompt and the weather in words, pure.
    `[plan]` in `data/npc_talk.cfg`. `WeatherDay` was there already (the farming's summary of a
    day), so the words are its method `words`; what the prompt is made of is a `DayToPlan`
    (day, time, sun, weather words, the activities on offer with their walks, yesterday). The cut-down
    sheet has no `day` text, so the prompt adds it (`usual_day`). Tests: the prompt.
11. **`DayPlanner`, the evening:** **Done.** the queue (`game/scenes/day_planner.gd`, a node like
    `StoryJudging`), 18:00, the nearest within the radius, the cap, the timeout
    (`NpcDialogue.ask` takes one), the late takeover, the pause during a chat, console `replan`
    (`Console.replanner`, set by the game scene). Tests: planner with a fake model. Doc:
    [dialogue.md](dialogue.md) gets a line, villagers.md ("Later: schedules") is changed, the
    handbook's console page has `replan`. The queue's entries are for a reason (console, evening, day
    in step 12) which is how soon they are asked; `DayToPlan.of` makes what the prompt tells and
    `ActivityUpkeep.offers_of` the activities on offer.
12. **`DayPlanner`, while the player moves:** **Done.** the radius check each game minute
    (`queue_newcomers`, once for each minute), the queries for the current day, `max_per_day` (it
    counts what is queued, so a villager dropped for leaving the radius and queued again counts
    twice), the order looked at again. None is queued with no model, or after 23:30 (no entry
    could be planned). Tests.
13. **Saving the plans** and `resume` for loading and spawning. The save version is the next free
    one, a commit of its own with its upgrade step. Tests: saving. Doc line in travel.md
    ("Saving").
14. **The bench** for the minute's tick and the radius check over 155 villagers (`tools/bench/`),
    the numbers written here; this plan marked as built.

**What depends on the village (#9, built after the map rework #60):** only the targets that point
at it, and the play test.

- `meeting` reads the village's `meeting_spot` and `field` its fields, in `ActivityPlaces`; one
  line each and their tests, a commit after both are in. Until then `meeting` is the church yard
  and `field` the tilled tiles, so everything above works and a villager with no such place just
  has fewer activities.
- The church is the village's church; Momme's feasts, the Krug and the landing's walks (about 65
  tiles, an hour) are then looked at in play, with `search_tiles`, `spread_minutes` and the radius
  tuned.
- `VillageBuilder` spawns the eight villagers with their homes and workplaces
  (`Households.settle`); nothing of the planner changes, they get their sets from their sheets.
- The save version: whichever of #7, #60 and #9 is built next takes the next free one.
