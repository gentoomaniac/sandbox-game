# Sound

Decided 2026-11-05. Everything makes sound; no background music for now.

- **All sounds are generated** by a script (`tools/audio/`, run by `make art`), like
  the art: deterministic, in the repo, retro in style, with a few variants per sound
  and a little pitch variation when played. **`data/sounds.cfg`** maps every sound event
  to its files, volume and pitch range, so any sound can later be replaced by a recording
  without touching code. The loops carry their loop points in the WAV file (a "smpl"
  chunk), which Godot's importer reads, so they loop without any setting in the game.
- **World sounds come from where they happen** (positional), on an Effects or Ambience
  bus. Inside a house the weather and the world outside are muffled and faint (task 172,
  2026-11-11): the low-pass fades in, and the Ambience and OutsideEffects buses are turned down by
  `outside_db` (`[indoors]` of `data/ambience.cfg`, -24 dB: rain on the roof and wind only just
  heard), both over the same 0.4 s (`Muffle`). The effects of the player and of the room stay as
  loud.
- **Footsteps** follow the walk animation and the ground: grass, soil, sand or floodplain,
  wetland (squelch), ice, snow (crunch), wooden floor.
- **Work:** axe chop, a tree's crack and thud when it falls, pickaxe on stone, stone
  breaking, scythe swish, shovel dig, hoe, watering, planting, picking a bush, a soft pop
  when an item on the ground is collected, placing a building, and a short "denied" sound
  (e.g. needs a better tool).
  What the player does is heard from its outcome (`GameState.action_done`, one per finished
  action, see `ActionOutcome`), so a refusal makes no work sound; only "denied" (and the scythe's
  swing at nothing) come from the use that did not work. Hits are heard from the object being hit,
  and a tree's fall when it lands. The pick-up pop plays for each pile taken from, so also when
  a pile is only partly taken because the inventory is full.
- **UI:** clicks for menus, the inventory and the hotbar.
- **Weather (ambience):** rain and wind as loops that follow their strength and fade like
  the weather visuals, wind gusts, and thunder after a flash, delayed as if far away.
- **Fire:** `fire_crackle_loop` (task 172, `tools/audio/fire.py`), an 8-second circle of
  crackling only, no bed of noise under it (the user, 2026-11-11): fine flecks of the embers
  all through, ticks and snaps of all sizes over them (short, bright and dry, nothing low or
  ringing: a first version's hollow knock sounded like a drum), the loud ones kept clear of the
  loop's seam. Louder than the weather loops, as it is the main sound of a room with a fire.
  On the Effects bus, not the muffled ones.
  **Indoors a fire crackles** (task 172, `AmbienceSounds`, numbers in `[indoors]` of
  `data/ambience.cfg`): a building's room with a hearth (or a fireplace) plays the loop from the
  fire. It is a positional sound effect heard only near the fire, on top of the other ambient
  sounds, at `fire_level` (0.8) beside it and falling off with the distance to its reach. The
  reach comes from the size of the room (the user, 2026-11-11: heard all the time in smaller
  houses, but not at the door of the big longhouse). Kate's room (9x8, 72 tiles) is small: the
  fire is 3.5 tiles from the door and at most 4.9 from anywhere to stand, and it reaches 9. The
  longhouse (15x8, 120) and the hall house (15x13) are big: their fires are 4.3 and 8.5 tiles
  from the door, and they reach 4 (a room of at most 100 tiles is small). A fire is whatever
  has flames drawn (`AmbientMotion.has_flames`: the hearth and the fireplace); the oven shows
  no fire and is silent. Every fire burns for good today (nothing lights or puts one out), so
  a room with a fire always crackles; the loops follow the room's fires every second, so one
  built or taken out is heard or gone within a second. The loop fades in and out over
  `fire_fade_seconds` as the player enters and leaves, and is stopped on leaving. No music
  indoors yet: see task 171.
- **The bell:** `bell_ring` (task 180, `tools/audio/bell.py`), one strike of a bronze church bell,
  11 seconds long. It is built the way a cast bell sounds: the hum an octave under the strike note,
  the strike note (about G4), the minor third that gives a church bell its dark colour, the fifth,
  the octave and a few higher partials, none of them whole multiples of the strike note, each
  as two pitches a hair apart that beat slowly. The low partials die away over many seconds and the
  high ones in a second or two, so a bright clang turns into a dark hum. A short knock of the
  clapper starts it. On the Effects bus, as a sound of the world outside.
- **Animals:** birds sometimes chirp where they are; frogs croak near rivers and ponds in
  spring and summer, mostly in the evening and at night and when it is warm, louder the
  closer the player is; deer snort now and then and their hooves sound when they bound
  away; rabbits rustle when they flee; squirrels chatter; bees buzz softly at their
  flower. Butterflies are silent. Where frogs are about (task 80) a quiet chorus of them
  swells on spring and summer evenings, fuller with more frogs, as warm as the croaks need
  it. Storks clatter their bills (a dry, hollow rattle) about once a minute or so while one
  is in view; geese honk now and then and when they take off, a skein flying over more
  often. Both are rare and quieter than the farm animals.
- **How the ambience is made** (decided 2026-11-05, numbers in `data/ambience.cfg`): once
  a second the weather sets the loops: rain at its strength, wind from calm (silent) to
  full speed, and in wind a gust now and then plays `wind_gust` and swells the wind loop
  for a couple of seconds. Each lightning flash is followed by one thunder 1 to 9 seconds
  later, plain (not positional) on the Ambience bus. Birds chirp at a chance per second by
  season (winter few), part of the day (none at night) and rain (none in heavy rain), from
  a bird in view or else a tree near the player. Frogs look at some random tiles within 12
  of the player and croak at the nearest water or wetland among them, by season (none in
  winter, few in autumn), part of the day (mostly night), warmth (none below 4 °C, full
  from 16 °C) and distance. Deer, rabbits and squirrels make their sound now and then, and
  when they start to run. The nearest two bees within 4 tiles buzz quietly as loops that
  follow them (changed 2026-11-05: they were too loud and heard from too far). The world's
  effects are muffled in a house like the weather; birds and frogs fall silent there.
