# Wehlsbüll in the world

[#9](https://github.com/gentoomaniac/sandbox-game/issues/9) (task 234). **Status: steps 1 to 6
and 8 to 10 of section 14 are built** (step 7, the worn track, waits for the user's answer in
[#95](https://github.com/gentoomaniac/sandbox-game/issues/95)); each step's note says what changed
from this plan. This page says what is built and what will be: where the village stands, its buildings, fields and
people, how it gets into the world, and in which steps. The user's answers
([#73](https://github.com/gentoomaniac/sandbox-game/issues/73),
[#75](https://github.com/gentoomaniac/sandbox-game/issues/75),
[#76](https://github.com/gentoomaniac/sandbox-game/issues/76)) are folded in. It builds on the
new map of [#60](map-generation-review.md) (bare open land, woods, creeks with fords, a winding
river) and fits the routines plan (#7, [../villagers/routines.md](../villagers/routines.md)).

## 1. What will be built

- **Where:** at the coast, west of the camp, on the first row north or south of it where the land
  fits. The church is a few hundred tiles from the camp: a walk of about a minute (the player walks
  5 tiles a second). **Any site is accepted**: there is no limit on the distance.
- **How:** the village is **not part of the generator**. A `VillageBuilder` writes it into the world
  once, when a new game starts: terrain edits, object edits and placed buildings, saved like
  anything else the player does. The site is found from the seed, the same every time.
- **What:** three farms on Warften in the Koog, each with fields beside it, the church with its
  churchyard and bell frame, the parsonage, the Krug, six cottages by the dyke and the sluice, the
  landing, a free spot for the post mill, a **town square kept free for a future market**, lanes,
  walls and fences. 19 buildings, all of types that exist; where none fits, a stand-in.
- **A worn track** from the camp to the village is laid at the start (section 7).
- **Who:** the eight villagers of `data/villagers.cfg` are spawned once, at their doors, with their
  homes and workplaces (built, step 8). The other houses stay empty.
- **The village is not the player's:** its land is a record in the world. Building there costs
  goodwill, its houses can't be taken down, and build mode shows the land's edge.
- **Finding it:** the handbook and a console command `village` say where it is.
- **Old saves** keep their world as it is, with no village.

### The decisions

| Question | Decision | From |
|---|---|---|
| Placed or generated | placed once at the start of a new game | #75 |
| Size | about 60 tiles wide, as drawn | #75 |
| The site | any site is accepted | #75 |
| Finding it | handbook and console `village`, and a worn track from the camp | #75 |
| Farms and fields | none in the open land; fields only around the generated villages | #73 |
| Lanes | in and around villages, linking houses and fields; between villages once there is more than one; none across the open land | #73 |
| Ditches | the player digs them (#86); the village has its own around its fields | #73 |
| Empty houses | stay empty | #76 |
| Reputation | building in the village costs goodwill; build mode shows its edge | #76 |
| Taking down its houses | refused | #76 |
| Stand-in buildings | as listed in section 4 | #76 |
| Town square | a free square for a future market | #76 |

Defaults not asked about (no objection was raised): old saves keep their world as it is; the
village's lane tiles do not regrow (section 8); the save version is taken at build time (section 12).

![The layout, one block a tile](wehlsbuell-layout.png)

The picture is drawn by [wehlsbuell-layout.py](wehlsbuell-layout.py), which also checks the layout:
no two buildings overlap, every door has its free tile in front and a walk to the main lane, no
field is shut in (every one has a gap to a lane), and the town square is free. Brown on the left is
the sea dyke, green-grey the salt marsh, tan the mud. White is wall and fence, tan lanes, blue water
(a ditch in the marsh), orange a Knick (on the Geest), the cream square the town square, the red dot
the meeting place. The script is the mock the plan was drawn from; from step 1 the layout lives in
`data/village_plan.cfg`, which `VillagePlan.problems` checks (the same rules), and the script is not kept in step
with it.

## 2. Where

### How far from the camp

The player walks 5 tiles a second (`PlayerState.SPEED`), so a minute is 300 tiles. The coast line runs
about 260 tiles west of the centre (`line_x=-260`, wandering 40 either way) and the camp is at the
centre. The Koog is behind the sea dyke and the Geest edge is 36 tiles from it, so the whole village is
within 60 tiles of the dyke.

### Finding the site (`VillageSite`, a pure function of the seed)

Starting at the camp's row and going north and south in steps of 4 rows, the first row `y0` where the
layout fits. The village's frame has `u` 0 at the first land tile of row `y0` (`WorldGenerator.first_land_x`,
where the sea dyke stands) and `v` 0 at `y0`:

1. **The coast is straight enough:** the first land tile of every row of the village's land (`v` -28 to
   34) is within 8 tiles of that of `y0`. The inland part is laid out 9 or more tiles behind the dyke of
   `y0`, so the wandering coast never reaches it.
2. **The inland land is dry and clear of water:** every tile of the land from `u` 9 on is grass or
   wetland (the village drains the wetland). No river, floodplain, creek, ford, mud or sea. Trees and
   stones are no reason to refuse: the builder fells them (woods stand on the Geest only, so they touch
   the village's eastern part).
3. **The landing has salt marsh:** every tile of the plan's landing Warft (the one with
   `is_on_salt_marsh`) is salt marsh, not one of the generated Warften.
4. **The camp can walk there:** a path search (A*, `PathSearch`) over the generated land finds a way from
   the camp to the east end of the main lane, the Sielweg. The village's own land counts as cleared, as
   the builder will clear it. It is the only rule that needs a search, so it runs last. The river has no
   ford and runs from the coast to the east edge of the world, so only a village on the camp's side of
   it can be walked to: that is asked first, from the river's centre line (`RiverLine.line_y`), because
   a search on the wrong side would look at every tile it can reach. The creeks have fords and do not
   stop the way.

The first draft's rule about the generated ditch grid is gone with the grid (#60 made the open land
bare). No rule needs the world's edits, so the same function answers for a new game of any seed. The
search stops at the first fit, or gives up after 900 rows from the camp (`find` then returns `null`; none
of seeds 1 to 20 comes near it).

**Measured (step 2, seeds 1 to 20, on the new map):** the search takes 160 to 380 ms for a seed (the
camp's own search included). The site is 36 to 464 rows (north mostly) from the camp, and the
village's east end is **205 to 643 tiles of way** from the camp (median about 300; the player walks 5
tiles a second: 41 to 129 seconds, median a minute). Seed by seed (origin, tiles to the Sielweg's end
as rows plus columns): 1 (-251, -192) 355; 2 (-272, -160) 358; 3 (-250, -356) 518; 4 (-268, 44) 264;
5 (-263, -332) 507; 6 (-266, -181) 376; 7 (-266, -52) 230; 8 (-258, -16) 205; 9 (-249, -114) 292;
10 (-264, -170) 364; 11 (-263, -63) 240; 12 (-253, -211) 378; 13 (-272, -105) 307; 14 (-272, -155) 356;
15 (-255, -113) 286; 16 (-247, -121) 286; 17 (-274, -107) 295; 18 (-274, 52) 264; 19 (-256, -229) 415;
20 (-259, -472) 643. Any site is accepted (#75), but seeds 3, 5 and 20 are about two minutes of
walking: the worn track and the handbook have to be good for those.

## 3. Generated or placed: placed, at new-game time

- **Buildings can't be generated.** A building is an entity of the world with an interior, residents
  and a save entry, not a tile; the generator makes terrain and objects only.
- **It sits on top of the generator.** The generator is changing (#60 now, more later). A village of
  edits stays as it is while the layers under it change.
- **Edits are saved already.** Terrain edits, object edits (`null` for removed) and buildings are in
  `World.to_dict`; the far view (#68) sees them, as [../villagers/travel.md](../villagers/travel.md)
  asks.
- **It is deterministic.** `VillageSite` and `VillageBuilder` read only the seed and the generator's
  public functions. Every random choice is a hash of the seed and a tile, never the global random
  generator. A test builds twice and compares the edits.
- **The cost:** the edits and buildings make the save bigger and the new game builds a dozen chunks
  more than today. Measured for the ground (step 3, seeds 1, 4, 7, 13, 20): about 115 ms, 1 060 to 1 130
  terrain edits (the Warften, the ditches and the Sielzug) and 610 to 970 object edits (270 to 630 of
  them removals of what was felled), together about 55 to 70 KB of JSON in the save. The buildings come
  in step 5.
- **Later changes of the generator** change the land inside the village's rectangle that the village
  did not edit, as they change every other unedited tile of a save. #71 decided against a freeze, so
  the village takes no special care.

## 4. The buildings

All on the layout above. `u` is tiles east of the dyke's nominal line, `v` rows south of `y0`. The
plan lives in `data/village_plan.cfg` (step 1), one section per thing, so the layout is data and not
code.

### Farms on their Warften (the Koog, behind the dyke)

| Building | Type | Where | Lives there |
|---|---|---|---|
| Boysen farm | `hall_house` (7x5) | Warft (30, -17), 22x12 tiles, with a pond | Antje, Hinrich, Boy |
| Boysen barn | `barn` | same Warft | works: Hinrich, Boy |
| coop | `chicken_coop` | same Warft, in the yard | nobody |
| Farm 2 | `hall_house`, `barn` | Warft (50, -15) | nobody |
| Farm 3 | `hall_house`, `barn` | Warft (31, 23), south of the main lane | nobody |

Each farm yard has a wattle fence with a gap at its gate, trees (alder, willow, oak) and a draw well
on the Boysen yard. The Warften are `WARFT` terrain edits in an oval, the same terrain as the
generated Warften of the salt marsh. A pond (Fething) is a `WATER` edit, 2x2.

### The fields

#73: fields only around generated villages. Wehlsbüll has four, beside its farms: two north of the
Boysen and Farm 2 yards, one south of Farm 3, and one Koppel by the mill road.

- A field is a ring of boundary with one 2-tile gap, as the old generator made them. **Where the
  ground is marsh the boundary is a ditch** (one tile of water), **on the Geest a Knick** (`knick`
  object). That rule is the one the generator had before #60; it now lives in the builder.
- **No field is shut in:** every gap is reached from a lane (a test; the picture script checks it too).
- The ditches stand as a ring and are not joined to the Sielzug: they are water for the cattle.
  Draining and watering are the player's work (#86).
- Nothing is planted in the fields and they are not tilled soil.

### The church, the churchyard and what is by it

| Building | Type | Notes |
|---|---|---|
| Church | `church` (6x4) | on the highest Warft, 24x16 tiles, middle of the village |
| Churchyard | stone wall, 19x13 tiles | one gate on the south side, graves (`grave`) inside |
| Bell frame | `bell_frame` | inside the yard, east of the church (task 102) |
| Parsonage | `kate`, style `brick` | **stand-in:** the pastor has no house type; nobody lives there |
| Krug | `longhouse` | **stand-in:** an inn is not a type; nobody lives there. By the square |

The sexton's house with the school is left out (no villager, no type).

### By the dyke and the sluice

| Building | Type | Lives there |
|---|---|---|
| Kerrin's house | `kate`, style `brick` | Kerrin (task 120 made the style for her) |
| Five cottages along the Deichweg | `shack` x3, `kate` (style `geest`), `kate` | nobody; empty |
| Landing: Ketels hut | `fisher_hut` on a small Warft **outside** the dyke, on the salt marsh | Momme, Inken |
| Landing: jetty, rowing boat, net frame, eel traps | the objects of task 103 | the jetty runs over the mud |
| Sluice (Siel) | **stand-in:** a two-tile gap in the dyke with the Sielzug (a 2-tile ditch behind it, 28 tiles long) running through, water ending two tiles beyond | |

### The mill

- The post mill does not exist as a type. Its spot is a free 7x7 square at the Geest edge, in the
  record (`mill_spot`), kept clear. The village builds nothing on it; the player may.
- The mill house at its foot is a **stand-in**: `kate`, style `geest`, with room for two. Ocke and
  Gesche live in it. When the mill house is a type of its own, the plan changes the type and
  nothing else.

### Lanes, fences and walls

- **Lanes**, one tile wide, laid as worn path (section 8): the **Sielweg** from the landing through
  the dyke gap across the whole village to the Geest, the **Deichweg** along the dyke, a lane from each
  farm gate and the churchyard gate, a lane along the north fields and one to each of the other
  fields. A lane over the Sielzug is a culvert: the lane tile stays land. #73: lanes stay in and
  around the village. None leaves it across the open land (the worn track of section 7 is a desire
  path, not a lane). Lanes between villages wait until the world has a second village.
- **Walls and fences:** the churchyard is a `stone_wall` ring, the farm yards `wattle_fence`. Each has
  a gap at its gate and the door of every house has its free tile in front. Nothing shuts anyone in.
- **Clean ground:** the builder fells the trees and removes the bushes, stones and tall grass inside
  the rectangle (object edits `null`) and drains wetland (terrain edits), so the village stands on
  clean ground. The open land is bare now, so there are no generated boundaries or ditches to clear,
  and far fewer edits than the first draft expected (it said 1 500): 1 700 to 2 100 edits for the
  ground (see section 3).

## 5. The town square

A free open square of 13 by 6 tiles between the Krug, the churchyard and the Sielweg (the picture's
cream area), kept free for a future market (#76).

- **Free:** the village puts nothing on it but a draw well beside it (the benches of the first draft are
  gone: a bench is furniture that only stands indoors), and the record keeps it as `square`. A later market task puts its stalls there; until then it is empty ground.
  The player is not stopped from building on it (it is the village's land, with the goodwill cost of
  section 9).
- **Ground:** trodden earth like the lanes, kept (section 8).
- **It is the meeting place.** Its middle is `meeting_spot` in the record, which #7's routines read
  (section 6). It is open air, so it is "in the open" for the rain rule of the routines.

## 6. The meeting place and the routines

The issue wants a place where villagers come together now and then, so gossip has meetings.

- **When:** the routines of #7 say it: the `meeting` step (weekday 19:00, Saturday evening at the
  Krug, Sunday afternoon) goes to the square, the `church` step (Sunday 9:30) to the churchyard.
  "Which places are where" in the routines plan takes `meeting` from "the place the village names for
  it": that is this spot. Until #9 lands, #7's fallback (the church yard) stays.
- **Order of the two plans:** both orders work. If #9 comes first, the record has `meeting_spot` and
  nothing reads it (the villagers still stroll about their yards). If #7 comes first, one line of
  `RoutinePlaces` and its test change to read the record.
- **Distances:** a tile is a game minute. The longest daily walk is the landing to the Krug (about 65
  tiles, an hour of game time, 43 seconds of play); the mill house to the church is about 32. The
  routine's "leave early" estimate covers both.
- **`church`, `home`, `work`:** the church nearest to the home, and the homes and workplaces of
  section 10 (`Households`, `Workplace.spot()`). A spot as workplace (the landing, the post mill) is a
  tile (`Workplace.of_spot`). Nothing else in #7 changes.

## 7. The worn track from the camp (#75)

The player finds the village by a trodden way from the camp to it, as well as by the handbook and the
`village` command. It is a **desire path** ([desire-paths.md](desire-paths.md), #61), laid at the start.

- **Laid:** after the village stands, the builder asks the path search for a way from the camp to the
  east end of the Sielweg (the search of site rule 4) and gives each tile of it that can wear (grass and
  floodplain; fords are floodplain, so they keep it, though a ford is never drawn worn) the wear of a path: `WorldWear.set_days` with
  `most_days` (12). Tiles that cannot wear (a Warft, wetland) stay as they are. It is plain wear, saved
  in `world.wear` already: no new save field, no record. About 300 to 500 tiles.
- **It keeps itself worn by use, like any desire path:** the rules are not changed. A tile needs 10
  steps in a day to count as busy, so one walk a day over it is not enough: **a track no one walks
  fades to grass in about ten days** (12 days of wear, one lost each quiet day), and a track walked once
  a day fades too. It stays only where the player (or later a villager on an errand) crosses it
  often. The mud rule applies: the track is muddy in the rain, so a player who walks it often has a
  reason to lay a way (#62). See "Check with the user" at the end.
- **Not a lane:** it is not in the record and is not kept. The village's own lanes are (section 8).

## 8. Lanes that stay

A lane is a path on the ground only while it is walked: desire paths grow back in two weeks
([../../data/paths.cfg](../../data/paths.cfg)). The village sets its lane tiles and the town square to
full wear at build time (the wear map is saved), and every night wears them to the full again
(`World.end_wear_day`, `WorldWear.keep_worn`), whether their chunk is loaded or not. So they stay
without walking. The tiles are the record's `kept_worn_tiles`: the tiles of the lanes and the square
that can wear (grass), made at build time, so a lane over a Warft or the salt marsh is a lane in
the plan but not worn ground. A tile that the player tilled or built on, or that a way lies on,
is left alone. The player's ways (a plank walk or a stone path, #62) may be laid over a lane: a way
never wears, and laying one clears the wear beneath it (as it does anywhere), so taking it up leaves
the lane unworn **until the next night**, which wears it again. Lanes are muddy in the rain like
other worn ground.

## 9. Reputation and showing the village's land

[reputation.md](../villagers/reputation.md) says "building inside a settlement's territory costs
reputation with its NPCs". Reputation itself is not in the code yet
([../villagers/relationships.md](../villagers/relationships.md)). What is there: the deed log and the
villagers' opinions of the player (`data/gossip.cfg`: `[built]` is +1 now).

- **The land is a record.** `World.village` holds the name, `area` (a rectangle, here from `u` -18 to
  60 and `v` -28 to 34, about 79 x 63 tiles, clipped to the land), the meeting spot, the square, the mill
  spot, the lanes and the buildings the village put there. `World.is_village_land(tile)` answers.
- **Deeds in the land weigh otherwise.** A new section `[village_land]` in `data/gossip.cfg` has a
  `change` for `built` (-2), `fenced` (-1) and `felled` (-1) done inside the land, used instead of the
  section's own. The witnesses are as ever. The deed's place is "on the village's own land" (instead
  of the house or the ground), which is what the model reads and what picks the change. The one-hop
  spread through friends and enemies is the reputation task's.
- **Its houses are not the player's.** The hammer's take-down refuses a building of the record ("That
  is the village's."). Walls and fences are not protected (no deed kind for them yet).
- **Shown before building.** With the hammer in hand the land's edge is drawn as a line over the terrain
  (like the build ghost), and while the ghost is inside the land the hint line says "Wehlsbüll's land:
  the villagers will not like it".
- **`village` console command** says where it is ("about 232 tiles west, 120 south") and what it holds,
  as does the handbook (#75).

## 10. The eight villagers

Spawned once, in `GameState.new_game`, after the village is built, each at its door with
`Npcs.spawn_villager` (`VillagePeople.move_in`). `Households.settle` then finds the house of their
sheet's type nearest to where they stand, so Boy and Antje join Hinrich's hall house and each
workplace is the nearest of its type. The plan says who lives where: each building of
`data/village_plan.cfg` has `residents`, the ids of the villagers spawned at its door.

| Villager | Home (building type) | Workplace | Interior |
|---|---|---|---|
| Antje Boysen | `hall_house`, Boysen farm | the hall house itself (the dairy) | `boysen.tmx` (her sheet) |
| Hinrich Boysen | the same | `barn`, Boysen barn | the same |
| Boy Boysen | the same | `barn` | the same |
| Momme Ketels | `fisher_hut` at the landing | spot "the landing at the sluice" (the jetty's root) | the type's room |
| Inken Ketels | the same | none | the type's room |
| Kerrin Paulsen | `kate`, style `brick` | none | the type's room |
| Ocke Hansen | `kate`, style `geest` (**stand-in mill house**) | spot "the post mill" (at the free spot) | the type's room |
| Gesche Hansen | the same | the same spot | the type's room |

- **Sheet changes:** Ocke and Gesche get `workplace_spot="the post mill"`. The plan gives each spot
  its tile (`workplace_spots` of `[village]`, which replaced the landing's `landing_spot`): the jetty's
  root and the middle of the mill's free spot. Their `home_building` stays empty: `spawn npc ocke`
  must not put them into Kerrin's kate. The plan names their house instead (`residents` of the mill
  house), and `VillagePeople` moves them in.
- **Interiors (task 237):** only the Boysens have their own map; the others use the room of their house
  type. More maps are Tiled work, not this task.
- **Once:** the spawn is in `new_game` only. A save holds the villagers, so a load never spawns them
  again. The record's flag `is_populated` guards against a second spawn.
- **Home search:** `home_search` is 40 tiles. The villagers spawn at their own doors.
- **The empty houses** (six cottages, two farms) stay empty (#76). The made-up villagers and `spawn npc N`
  are not part of this task.

## 11. What depends on what

### #60, the map generation (about to merge)

- **Built there, used here:** `make world-map` (it gets a `--village` option in step 3 here, to draw a
  seed's village on the generated land); the bare open land (the village lays its own fields, section 4);
  the creeks, the river and the floodplain, which site rules 2 and 4 read and which the path search and the
  track cross by fords; the woods, which the builder fells inside the rectangle.
- **The village is built after #60 has merged** (#75: it waits in the queue). Step 1 (the plan as data)
  and the checks of the picture script need nothing from #60; the site and the rest do, because the site
  rules are about its land and its numbers are measured on it.
- **No freeze.** #60 did not build its save freeze (#71): old saves load with the new land. The village
  asks nothing of it.
- **No generated farms.** #60 built none (#73): the first draft's question about generated farms becoming
  the village's is gone. The village's farms are its own.

### Other changes since the first draft

- **The calendar** has 35-day seasons (#85): nothing here counts days; the track's fading is in days of
  wear (section 7).
- **Ways connect** (#84): lanes are worn ground, not ways; the player's ways lie over them (section 8).
- **Saves rotate** (#16): the record is part of the world, so every rotated file holds it. Nothing to do.
- **The save version** is 44 on main and 45 once #60 merges. The village takes the next free one when
  its step 4 is built, not a number written here.

## 12. Old saves and the save version

**An old save keeps its world as it is.** Its record `village` is empty and the world works as before.
The village would change ground the player has perhaps worked on and that the old save's own villagers
may stand on.

- **Save version:** one bump, to the next free version at build time (`World.village`: the record or
  `null`; the upgrade sets `null`). The commit that drops the oldest upgrade is its own, as the save
  rules say. The validator checks the record: the area, that the buildings it names stand, that the
  meeting spot and the square are inside the area.
- A console command to add the village to an old save where the rectangle is untouched is possible later
  and is not planned.

## 13. Tests

One file for each part, short, in `tests/`:

- `test_village_plan.gd`: `data/village_plan.cfg` parses; every building type exists; no overlaps; every
  door has its free tile; lanes join; no fence or wall shuts a door in; no field is shut in; the square is
  free; a bad file is reported, not a crash.
- `test_village_site.gd`: a site is found for 20 seeds; the same seed gives the same site (a different seed
  a different one); the site clears the river and the creeks; the camp reaches it by the path search.
- `test_village_builder.gd`: same for a seed (build twice, compare the edits and buildings); every tile of
  a building, lane, wall, Warft, the square and the meeting spot is dry land; the pond, the Sielzug and the
  field ditches are the only water that was not there; a world with a player's shack in the rectangle is
  refused with a reason; the dyke has only the Siel's gap; every door has its free tile; the churchyard
  has its gate; each field has a ditch in the marsh and a Knick on the Geest, with a gap.
- `test_village_track.gd`: the track runs from the camp to the Sielweg's end over wearable tiles at the
  laid days; it crosses a creek by a ford; it is grass again after the days of section 7 when not walked.
- `test_village_people.gd`: each of the eight has a home and the workplace of the table; the Boysens share
  one house; spawned once (a save and a load spawns none); a villager's door reaches the church gate by a
  real path search for 5 seeds.
- `test_village_record.gd`: the record's save round trip; a save of the version before loads with none;
  the validator names a bad area; `is_village_land` on the edge; the lanes and the square skip the
  regrowth; the take-down is refused for the village's buildings and allowed for the player's.
- `test_village_deeds.gd`: a `built` deed inside the land has the village's change, one outside the usual.
- The far-view parity case of travel.md: the masks over the village equal the loaded chunks'.
- A bench (`tools/bench/`): the new game's build time and the save's size, numbers written here.

## 14. The steps

Each is a commit that passes `make test` and `make lint` on its own, with its tests and doc lines.
The village is built after #60 has merged.

1. **The plan as data.** `data/village_plan.cfg` and `VillagePlan`: the buildings, Warften, fields, lanes,
   fences, the square and the spots, in the `u`/`v` frame, with the checks of the picture script
   (`problems`). No world change. Tests: `test_village_plan.gd`.
2. **The site.** `VillageSite.find(seed)`: the row search of section 2, with the path search as its last
   rule. Tests: `test_village_site.gd`. The search cost and the distances for 20 seeds are written here.
3. **The ground.** `VillageBuilder.build_land`: fells and clears the rectangle, drains, writes the Warften, the
   pond, the Sielzug, the dyke gap, the fields' ditches and Knicks, walls, fences, trees, graves, the well and
   the landing objects. The map tool gets `--village`. Tests: the land part of `test_village_builder.gd`.
   Edit count and time written here.
4. **The record and the save.** `World.village` with its save, the upgrade, the validator, the next free save
   version, and the drop of the oldest upgrade in a commit of its own. No builder yet: the record is `null`.
   Tests: `test_village_record.gd` (round trip, old save, validator). Doc: [../tech/saving.md](../tech/saving.md).
5. **The buildings.** `VillageBuilder.build` places the buildings and fills the record; `GameState.new_game` builds
   the village. Tests: the rest of `test_village_builder.gd`. Save size and time written here.
6. **Lanes and the square that stay.** The lane tiles and the square worn to a path and kept. Tests: the
   regrowth skip.
7. **The worn track.** `VillageBuilder.lay_track`: the path search from the camp, the wear laid, in `new_game`
   after the village. Tests: `test_village_track.gd`. Doc: desire-paths.md (a track laid at the start).
8. **The people.** The eight spawned in `new_game`, the sheets' spots (`workplace_spot` for Ocke and Gesche),
   `populated`. Tests: `test_village_people.gd`. Doc: villagers.md, `data/villagers.cfg`'s comment.
9. **The land and the reputation rule.** `is_village_land`, the edge in build mode, the hint, the refused
   take-down, `[village_land]` in `data/gossip.cfg`, console `village`. Tests: `test_village_deeds.gd` and
   the record test. Doc: reputation.md, console.md.
10. **The meeting place and the handbook.** The routines read `meeting_spot` (if #7 is merged, else only the
    accessor and its test), the screenshots in both arts (section 15), the handbook pages and design pages
    of section 16, this page marked as built, the bench numbers.

The user can stop after step 5 and have the village standing, empty.

### What was built, and what changed from the plan

- **Step 1.** `data/village_plan.cfg` and `VillagePlan` (`game/world/village_plan.gd`), checked by
  `tests/test_village_plan.gd`. The data is the layout above, with these changes: the land's rectangle
  starts at `u` -18 (the jetty reaches `u` -18); the benches of the square are gone (a bench is indoor
  furniture only) and its draw well stands beside it; the graves are the type `grave`; the well of the
  Boysen yard moved to `(31, -18)`, as the old place shut the barn's door in (found by the check).
- **Step 2.** `VillageSite.find(seed)` (`game/world/village_site.gd`), with `WorldGenerator.first_land_x`
  (the first land tile of a row). Changes from the plan, all in section 2: rule 1 checks every row of the
  land, not every second row of a fixed range; rule 2 asks for grass or wetland (no Warft inland) over the
  plan's inland land; rule 3 checks the landing Warft's own tiles for salt marsh instead of "11 by 9
  tiles"; a village across the river is refused before the search. The distances (205 to 643 tiles) are
  longer than the "about a minute" of section 1 for some seeds; the figures are in section 2.
- **Step 3.** `VillageBuilder.build_land(world, site, plan)` (`game/world/village_builder.gd`), tests in
  `tests/test_village_builder.gd`; `make world-map` takes `VILLAGE=1` (the tool's `--village`: the map shows the
  seed's village, centred on it, 128 tiles at scale 8). It returns why it refused, or "": a building, a
  changed object or tilled soil of the player on the land. It loads the land's chunks itself and
  unloads those it loaded, so a new game's streaming is not disturbed. Changes from the plan: the
  Sielzug starts at the row's own first land tile (the dyke wanders up to 8 tiles from `u` 0 and the
  gap has to be where the dyke is), and everything inland of `u` 9 but the sea dyke is cleared, reeds
  and wetland included. A lane is not laid in this step (step 6).
- **Step 4.** `Village` (`game/state/village.gd`), the record, is `World.village` (null without a village),
  saved as `"village"` of the world; save version 46, whose upgrade from 45 sets it to `null`; the
  validator checks it (`SaveValidator._check_village`); the upgrade from version 35 was dropped in a
  commit of its own before. Tests: `tests/test_village_record.gd`. The record holds the name, the land (`area`),
  `meeting_spot`, `square`, `mill_spot`, `lane_tiles` (step 6), `building_origins` (step 5) and
  `is_populated` (step 8), all in world tiles. The flag is in already so that step 8 needs no save version of
  its own. (Step 8 added `field_spots`, see there.)
- **Step 5.** `VillageBuilder.build` (the land, then the 19 buildings, then the record in `world.village`;
  `build_land` stays for the map tool and the land tests); `GameState.new_game(seed, with_village)` builds the
  village when `with_village` is true, which the game's two new games in `main.gd` say. **Changed from the plan:**
  `new_game` builds no village by default. 141 places in the tests start a game, and the village
  makes each take about 0.3 s longer (the whole test run 38 % longer: 255 s to 352 s) and puts 19
  buildings into worlds that count their own; the tests that want the village ask for it. A seed
  with no site has no village. The cost of a new game: the site 130 to 300 ms and the build 115 ms plus
  the buildings, together 290 to 450 ms for seeds 7, 1 and 20 (a game without the village: about 60 ms).
  The save is 56 to 73 KB bigger than a bare world's (the record itself is 0.4 KB). Tests:
  `tests/test_village_buildings.gd` (the land tests of step 3 share `tests/village_case.gd`).
- **Step 6.** The build wears the lane tiles and the square (`VillageBuilder._wear_lanes_and_square`), and
  the world wears them again each night. **Changed from the plan:** not "the regrowth skips them" in
  `WorldWear.end_day`, but "worn again every night": it also heals a lane after a way was laid on it and taken
  up, which the plan promised and the rule "laying a way clears the wear" would otherwise break. The record's
  `lane_tiles` became `kept_worn_tiles` (the lanes' and the square's tiles that wear: 351 to 360 for the
  seeds measured; the plan's 300 to 500 was for the track), the field of step 4, in the same save
  version. `world.gd` reached the 1 000 lines the lint allows, so the making of its save data moved to
  `WorldSave` (step 9). The map tool draws the buildings and the worn ground. Tests:
  `tests/test_village_lanes.gd`.
- **Step 8.** `VillagePeople.move_in` (`game/state/village_people.gd`), called by `GameState.new_game` after
  the build: each resident of the plan is spawned at the door of their building, `Households.settle`
  does the rest by their sheets, and what the sheets cannot say the plan does (the mill house, the
  tile of a spot). It loads the chunks round each door and unloads them again
  (`VillageBuilder.load_chunks` is public for it). **Changed from the plan:** the plan did not say how
  the `field` target finds the village's fields, and `ActivityPlaces` has no site or plan to ask. The
  record got `field_spots` (the middle of each field's ring), in the same save version 46 (not
  released), and the nearest of the tilled tiles and the village's fields is the field of the villager
  (the plan had "with none"; routines.md has the new words). `meeting` is the record's `meeting_spot`,
  within `search_tiles.meeting` of home, and the church yard only in a world with no village. Tests:
  `tests/test_village_people.gd`, `tests/test_activity_places.gd`.
- **Step 9.** `World.is_village_land(tile)` and `is_village_building(building)` (on `Village.is_land` and
  `has_building`); the hammer's take-down says "That is the village's." (`GameState.why_not_take_down`);
  build mode draws the land's edge while the hammer is held and says "Wehlsbüll's land: the villagers
  will not like it." while the ghost stands on it; `GossipRules.opinion_change(kind, place)`;
  console `village`. **Changed from the plan:** the place of a deed on the land is its own words
  instead of a flag on the deed. A flag would be a new field of every saved deed and story (a save
  version and an upgrade, and many test fixtures), while the place is already part of each, merges
  deeds by it and goes to the model. A story whose place a whisper has moved to a neighbour's house
  has the usual change: the rumour got it wrong. `World.dict_of` moved to `WorldSave` first (a commit of
  its own: world.gd was at 1 000 lines). Tests: `tests/test_village_deeds.gd`, `tests/test_village_land.gd`,
  `tests/test_village_record.gd`, `tests/test_gossip_rules.gd`.

- **Step 10.** The handbook ([world-and-seasons.md](../../handbook/world-and-seasons.md) "Wehlsbüll",
  [villagers.md](../../handbook/villagers.md), [building-and-crafting.md](../../handbook/building-and-crafting.md),
  [saving.md](../../handbook/saving.md), [console.md](../../handbook/console.md)), the screenshots of
  section 15 and the bench `tools/bench/new_game.gd`. The routines read the meeting spot since step 8.
  **The bench** (seeds 1, 7 and 20, best of 3, one core, niced): a new game takes 37 ms bare and 420 to 570 ms
  with the village and its villagers (457, 420 and 569 ms; the site's search, the build and the eight
  spawns); the save is 203 to 236 KB with it against 3 KB bare (220, 203 and 236 KB; the edits, 19 buildings
  and 8 villagers with their sheets, memories and stories).

## 15. Screenshots

Both arts, taken with `make screenshot` (the classic 16 px art with `ARGS=--classic-art`, seed 1, at the
widest view, `--day=45` and a time of day), saved to `docs/screenshots/` as `wehlsbuell-<what>.png` and
`wehlsbuell-<what>-classic.png`: `church` (the church, the churchyard and the cottages by the dyke), `square`
(the town square by the Krug, in the morning), `boysen` (the Boysen yard on its Warft with a field's ditch
above it), `landing` (Ketels' hut, jetty, boat and net frame) and `build` (build mode at the land's east edge,
with the edge and the hint). Checked by eye in both arts: the Warft, the wall, the fence, the Knick, the
jetty. No new art was drawn and the classic art misses nothing the pictures show. Not taken: the village
from above (the camera's widest view shows about 35 by 22 tiles of its 79 by 63) and the worn track (step 7).

## 16. Handbook and design pages

Done but for the worn track (step 7): the handbook pages and generation.md, travel.md, villagers.md,
reputation.md and gossip.md are written. coast.md and desire-paths.md are left as they are.

- **Handbook:** [villagers.md](../../handbook/villagers.md) (they live in Wehlsbüll from the start; homes
  and workplaces; the village's land and the hammer), [world-and-seasons.md](../../handbook/world-and-seasons.md)
  (the village, its fields, the Koog Warften, the worn track, where to find it),
  [building-and-crafting.md](../../handbook/building-and-crafting.md) (the land's edge and the refused
  take-down), [console.md](../../handbook/console.md) (`village`), [saving.md](../../handbook/saving.md)
  (old saves have no village).
- **Design:** [coast.md](coast.md) (the village's Warften), [generation.md](generation.md) (fields come
  only with the village, which is not generated; the site search), [desire-paths.md](desire-paths.md) (the
  track), [../villagers/reputation.md](../villagers/reputation.md) (the territory is the record),
  [../villagers/villagers.md](../villagers/villagers.md) and [../villagers/travel.md](../villagers/travel.md)
  (the village is done), [../tech/saving.md](../tech/saving.md), and the comments of `data/villagers.cfg`
  that say "until the village does (task 234)".

## Check with the user

- **The track fades without use** (section 7). With the rules of #61 a track that is walked once a day
  becomes grass in under two weeks, because a tile needs 10 steps a day to stay worn. "Keeps itself worn by
  use" is kept as written, with no change of the rules. If the track should last (a track the villagers
  keep up, or a slower fade for it), that is a rule change for the desire paths, not for this plan.
