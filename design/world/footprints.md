# Footprints

The player and the villagers leave footprints on soft ground, and they fade (decided 2026-11-15,
[#64](https://github.com/gentoomaniac/sandbox-game/issues/64); the user, 2026-11-14, answering
#57). Numbers are in `data/footprints.cfg` (`FootprintRules`); the prints are `World.footprints`
(`Footprints`) and are drawn by `FootprintView`.

## What leaves a print, and where

- **Who:** the player on foot, and the villagers the player sees: a villager's near step (a trip
  or a stroll in a loaded chunk, with the player outdoors). Not:
  - a villager on a far trip, on a chunk that is not loaded, or in the skip of a sleep or a time
    jump (`NpcTravel._wear_entered_tile`), nor while the player is inside a building (the trips are
    walked on the masks, see `design/tech/pathfinding.md`): nobody sees them, so they make none;
  - the player with noclip, or on a horse. The horse's hoof prints are part of #65 with the other
    animals' prints (they differ by size and weight); the rider leaves none. The farm animals leave
    none until then.
- **Where** (`Footprints.kind_at`), by what the step lands on:
  - **snow** where snow lies on most of the tile (`GroundCover.is_snowed`, so under trees and in
    the lee of houses, where less lies, there are none);
  - **mud** on tidal mud the tide does not cover, and on worn ground while the rain has made it mud
    (`World.is_muddy_at`, see `desire-paths.md`);
  - nothing on grass, fields, a way (plank walk or stone path), under a building, and none in
    flooded tidal mud, where the player wades: the water takes them.
- Wet sand is not made: the world has no sand ground (the coast's beach is the mud).

## What a print is

- One print a step along the way walked: every `step_tiles` (0.45 of a tile) of the path a walker
  actually goes (not for each tile it enters), the left and the right foot in turn, each
  `foot_side_tiles` (0.15) to its own side of the line, so the two rows are 0.3 of a tile apart and
  the prints in a row 0.9 apart, as the trail of a shoe in the snow. Its toes point the way the
  walker goes, at any angle (the picture is turned by the instance's transform), diagonals too.
- The distance walked is kept by each walker, a `Footprints.Stride` (a float and which foot is
  next) on the player and on each villager, made once with it: a frame adds its length and writes
  the prints the sum has reached, none if it has not. A move longer than two tiles (a jump, not
  walking) makes none.
- **Not saved:** a print is a look nothing else reads, and it fades in hours anyway. A loaded game
  starts on clean ground.

## Fading

- A print lasts `snow_lasts_minutes` (480 game minutes) in snow and `mud_lasts_minutes` (360) in
  mud in fair weather, fading out linearly.
- The weather speeds that up: each kind has a clock of its own that runs by one plus the weather's
  strength (0 to 1) times a gain: rain on mud (`mud_rain_gain` 3: a downpour fades prints four times
  as fast), snowfall on snow (`snow_snowfall_gain` 6: fresh snow fills the tracks) and the thaw on
  snow (`snow_thaw_gain` 4, the warmth that melts the cover). A print stores the clock's value when
  it was made, so one number per kind does for all and nothing is done to a print as it ages.
  A time jump (sleep) ages them at the pace of the weather they wake to.
- A print also goes at once when its ground stops being soft (`Footprints.check_next_chunk`, one
  chunk a frame): the tide covers the mud, the rain stops and the ground dries, the snow melts, or
  new mud is under snow.

## Cost

- Prints exist only in loaded chunks. Each chunk keeps a ring of `per_chunk` (160, since a print a step is
  more than twice the old one a tile): a new print past that overwrites the oldest, so the total is
  at most 160 times the loaded chunks (about 25), 4000 instances of a few floats. A ring is made when the chunk gets its first print and dropped with the chunk
  (`WorldView._on_chunk_unloaded`).
- Drawn as one MultiMesh a chunk (`FootprintView`): a print is written to its instance once, when
  it is made or when it goes, and the shader (`footprints.gdshader`) fades it by the two clocks,
  handed over only when they change (once a game minute). No node and no allocation per print, and
  none per frame.

## Art

`assets/effects/footprints.png`, four cells a tile square (snow left foot, snow right foot, mud left
foot, mud right foot), in both art sets (`tools/art/footprints.py`; the classic art draws it at 16 px
and it is doubled, so it is the same size on screen). A print is the sole of a shoe, toes up: a broad
ball, a narrow waist on the inside and a round heel, 14 px long at 32 px (7 at 16 px), the two feet
mirrors. It is a dent: in snow a soft grey-blue floor with its rim towards the light shaded; in mud
a dark floor with a pale rim, the lighter on the side away from the light.

## Looking at them

`--footprints=<x>,<y>` (`DebugFootprints`) lays two trails of prints from that tile for a
screenshot, one straight east and one diagonal to the north east, starting a tile north of it: in
snow with `--snow=1`, else in mud (with `--weather=rain`).
