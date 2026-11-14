# Travel where the world isn't loaded (#68)

Planned 2026-11-14, for the user's approval before code. It builds on task 238's plan in
[routines.md](routines.md) ("Finding the way"): `PathSearch`, `Pathfinder`, `NpcTrip`, `walk_to`,
`trip_arrived` and `trip_blocked`. Its first step comes after 238 is merged. OpenAI GPT 6.1 Sol gave a
second opinion on this issue; where the plan follows it and where it does not is at the end.

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
  freshly generated chunk. Night upkeep edits unloaded chunks too (crops, fallow soil grown over).
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

- **`TravelMask`** (one per chunk): a `PackedByteArray` of 1024 flags, BLOCKED (ground or object, as
  `is_walkable`, decks included), MUD (blocked while `Tide.floods`), SEASONAL (blocked unless the
  plant is dormant; its `WorldObject` is kept in a small dictionary for `World.is_dormant`), OBJECT
  (the +2.0 cost of a non-blocking object) and WEARS (grass or floodplain). Buildings are not in it:
  `World.building_at` is read live, so placing or taking down a building changes nothing here.
- **`TravelMasks`** (one per `World`, held by `Npcs`): an LRU of masks (`far_chunks_kept`, 256, about
  0.4 MB) and of the raw chunks a mask is stamped from (9, about 2.7 MB: a mask needs the chunk and
  its west, north and north-west neighbours, whose big objects reach in). It has its own
  `WorldGenerator`, so the world's generator and its `FieldLayout.cover` stay untouched. The edits
  are replayed by the same code as `add_chunk` (moved into `World.replay_edits(chunk)`), so the
  mask agrees with the loaded chunk by construction, and a test holds it to that.
  `mask_of(coords)` returns the mask or null and asks for it; `build_next()` builds one.
- **Building happens on the main thread, one chunk a frame** (about 11 ms), and not in a frame in
  which `ChunkResidency` loaded a chunk (also 9 ms). This is the cost of a chunk load, which the game
  pays already as the player walks. A worker thread is the fallback if the bench shows a longer
  frame (step 5), not the start: it needs its own copies of the edits and the static rules warm.
- **Invalidation:** `World` gets `signal edited(chunk_coords)`, sent by `_edit_terrain` and
  `_edit_object`, which every change of terrain and objects goes through, loaded or not. The masks
  of that chunk and of its east, south and south-east neighbours (where its objects reach) are
  dropped. 238's `World.change_count` no longer counts chunk loads and unloads: with the masks, a
  load changes no answer.
- **`TravelView`** (the combined view the search gets): `is_free(tile)` is 238's `can_stand_at` where
  the chunk is loaded and the mask elsewhere; `cost_of(tile)` the same, with the wear from `World`;
  `is_known(tile)` is false where a needed mask is not built yet. The tide is that of the time the
  search starts.
- **`PathSearch`** learns one answer: WAITING, when it reaches a tile that is not known. The node
  goes back into the heap, the mask is asked for, and the `Pathfinder` passes the search over until
  the mask is there. **`Pathfinder`** keeps one of its two searches a frame for the oldest far
  request, so far trips are not starved by near ones, and near ones are not held up by far ones.
- **`NpcTrip`** follows the path in one of two ways, decided per step: the tile it is on and the
  next are both in loaded chunks, so it steps with its body as in 238 (its body spans both); or not,
  so it moves to the next centre at `walk_speed` and checks the tile in the view as it enters it
  (tide and season at that time). The switch is at a chunk edge, out of sight. A
  far tile that has closed makes the trip search again from where it stands, as a near stuck one
  does, then BLOCKED with the 238 retry. Far feet wear the tiles too
  (`World.wear_unloaded(tile, steps)`, trusting the mask's WEARS bit), so lanes grow where people
  walk, seen or not. 238's NOT_LOADED goes: a far trip searches; an unknown tile waits.
- **`Npcs.update`** moves every trip, near and far; `only_loaded` only keeps the strolls to the loaded
  chunks. `Npcs.catch_up(map, seed, minutes)` learns the minutes of the skip (below).
- **`NpcViews`** makes a view only for a villager whose chunk is loaded, so after a jump (a loaded
  save, the console's `tp`) nobody stands on ground that isn't drawn yet. The ground near the player
  loads first; one coming from further out is on loaded ground long before the view.

The routines' API stays 238's: `walk_to`, `walk_to_door`, `cancel_trip`, `trip_arrived`,
`trip_blocked`, `place`. `place` may be used for any villager during a skip (below) and for one whose
chunk is not loaded; never on a visible one.

## Cost

- **Memory:** masks 0.4 MB, raw chunks 2.7 MB, paths about 5 KB for a 600-tile path (0.75 MB for
  155 such). Search state only while a search runs (two at a time).
- **CPU per frame:** a far walker is one addition and one compare a frame, a mask read per tile:
  under 0.3 ms for 155. Searches stay in 238's 1.5 ms. Mask building is at most one chunk a frame.
- **A search:** a far node costs a mask read instead of 15.5 us of `can_stand_at`, so it should cost
  less than a near one (to measure, step 2). A 300-tile way searches some 1000 to 3000 nodes: 10 to
  30 ms of search, 7 to 20 frames. Cold, it touches 20 to 40 chunks: 20 to 40 frames of building
  first (the village's chunks are warm after the first trips).
- **The day:** a game day gives 1.5 ms x 60 frames x 960 s = 86 s of search. A village of 30 with four
  trips a day needs about 120 x 25 ms = 3 s; the bench of 155 about 620 x 25 ms = 16 s. If all 30 leave
  in the same minute, the last starts about 8 s later; if all 155 do, about 45 s (task 239 spreads
  the hours).
- **Pass or fail, step 2:** on warm masks a far node costs at most 10 us, and a 300-tile far way is
  found in at most 40 ms of search; a cold mask costs at most 15 ms to build. If not, the plan comes
  back with reused commuting paths (the same home and workplace, the same path) before the next step.
  A coarse chunk graph only if even that does not do (step 5).

## Time skips and sleep

A skip moves every trip along its path by its minutes (one tile a minute), checking each tile with
the tide of the time it is entered; one whose path ends arrives and sends `trip_arrived` at the end of
the skip. A trip that has no path yet, or needs a new one, searches after the skip, as in play, and
so leaves late. Nothing is searched inside a skip: the skip's spans run in one go. The skip's three
walked minutes go through `Npcs.update`, the rest through `catch_up` (no trips are left out, and none
counts twice). The same game skipped the same way ends the same.

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
   seasonal plant dormant and present, a ditch, the dyke, an ewer, a hedge, the chunk and world
   borders, the wear. The world's generator is untouched. An edit drops exactly the four masks.
2. **`TravelView`, WAITING in `PathSearch`, the far slot of `Pathfinder`**, and the far search bench
   with the pass-or-fail numbers. Tests: a far way equals the way found with the same chunks loaded;
   a search waits for a mask and goes on; a far request runs while near ones are queued; NOT_LOADED is
   gone.
3. **Far walking in `NpcTrip`, `Npcs.update`, far wear, `NpcViews`.** Tests: a villager from far
   comes into the loaded area on its path and arrives at the goal; one leaves it and walks on; its
   position never moves more than `walk_speed x delta` in an update, also when its chunks load one
   an update or unload; the tide rising over a far path makes it search again, then wait; a crop
   edit at night drops the mask; far feet wear; no view for a villager on an unloaded chunk.
4. **Skips:** `catch_up` with minutes. Tests: a skip moves a trip as far as the same minutes of play
   (to the tile); one that ends in the skip arrives once; a trip without a path searches after it;
   synchronous and over frames end the same; `place` in a skip.
5. **The bench** (`tools/bench/paths.gd` of 238): 10, 30 and 155 villagers sent 100 to 300 tiles
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

## Open questions, with the default

1. Far feet wear lanes as near ones do? Default: yes.
2. Trips are not saved, and 239 sends them again on load (no save version bump)? Default: yes.
3. After a skip, 239 puts villagers where their routine is, and the hours inside a skip are not
   replayed? Default: yes.
4. The world stands still while the player is inside (today's rule), far travel too? Default: yes,
   until the villagers go inside (task 229) asks again.
5. How late may a departure be? Default: 30 villagers leaving in the same minute are all on their
   way within 10 s; 155 within 60 s.
