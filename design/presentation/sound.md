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
