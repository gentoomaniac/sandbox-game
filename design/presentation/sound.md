# Sound

Decided 2026-11-05. Everything makes sound. Music (task 184, 170): a Music bus under Master with its
own volume slider in Settings → Audio, saved with the others; 0 mutes it. Two calm everyday pieces,
"Tide" and "Harbour evening", play by themselves, each looping three times before the other
crossfades in on the next beat (EverydayMusic, data/music.cfg); the console's `play` and `stop`
steer the same player. They are rendered in the background (never waited for: what plays goes on
looping) and kept in a bounded cache in user://music_cache/. Off in test runs (`--mute`) and
headless. Task 171's director will choose the music by the time of day, season, weather and place.

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
- **Paused: only the music plays** (task 213, 2026-11-13, "All sound should stop while being in the
  menu, except the music"). Effects and Ambience send to a `Game` bus (OutsideEffects still to Effects),
  Music and UI straight to Master. While the tree is paused, which only a window with `pauses_game`
  does (the pause menu with all its pages, a chat, a choice dialog; the crafting, chest, character,
  bag and console windows don't pause and keep the sound), an amplifier on Game fades to silence over
  `fade_seconds` (0.3, `[paused]` of `data/ambience.cfg`) and back when the game goes on. Fading the
  bus rather than pausing the players keeps loops, the bell's tail and positional sounds where they
  were, and nothing clicks. The UI bus is not touched, so the menu's own sounds play. Moving a volume slider of
  Settings → Audio plays a `ui_click` (`AudioService.play_volume_test`) at the slider's level for
  Effects and Ambience (a click on the UI bus, which only Master governs, since those buses are silent
  now; Master's is a click at full level; Music is heard as it plays; nothing at 0 %). A moving slider clicks at most every 0.15 s (`TEST_CLICK_SECONDS`), the last click at its final level.
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
  the weather visuals, wind gusts, and thunder after a flash, by how far the strike was. Thunder
  comes in three kinds by distance (task 214, `weather.py`; six variants each since task 222, differing in length, pitch, attack and
  the number of rolls: one roll, a double roll, a long rolling series): `thunder_far` (low, soft, long
  rumble, no crack, -16 dBFS), `thunder_mid` (a roll with body, -9) and the rare `thunder_close`
  (a sharp crack at once, then a heavy rumble, -2); the game lowers and dulls them further by
  distance (see the ambience below). `thunder_crawl` (task 222) is lightning running across the
  sky: a 6-9 s rolling rumble of many overlapping decaying bursts at random (Poisson) gaps, with
  sharp crackles and rips scattered irregularly, thickest in the middle, about the mid level (-9);
  no steady rate of pulses anywhere (the first version had a rippling flutter and sounded like a
  helicopter, the user, 2026-11-13); mono, so the game pans or moves its source.
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
  **Ringing it** (task 180, `GameState.ring_bell`, heard by `GameSounds`): E or a click on the bell
  frame with a footprint tile within a tile of the player (`Interaction.bell_frame_to_ring`) plays
  it (E gives way to a bed in reach, so the player can still sleep next to the frame; a click gives
  way to a use the held item has on the tile, which no item has on a building today, and to eating
  a held food or lighting a held lantern, which come first in Main) from the middle of the frame, 120 tiles of reach (`reach_tiles` of its section in
  `data/sounds.cfg`, outdoors a bit under four times the 31 tiles of the other effects, fading
  evenly over it), and it is muffled and faint indoors like the other sounds of the outside
  (`is_from_outside`). **Ringing again while it sounds: the strikes overlap**, each a new play on
  top of the ones still ringing. A real bell struck again rings on under the new stroke; restarting
  would cut an 11-second tail off, which is the one thing a bell never does, and waiting would make
  a click that does nothing. At most three strikes sound at once (`voices` of its section in
  `data/sounds.cfg`): a fourth ring cuts off the oldest strike, never a footstep or another sound,
  so a bell rung over and over cannot crowd the pool of twelve players. The swing is a damped pendulum (`BellSwing`, a 1.1 s period fading over 4 s)
  that a ring kicks to a full swing from wherever the bell is, so a second ring never makes it
  jump (`BuildingViews`). The bell is not in the bell frame's picture: `bell_swing` (both arts,
  `tools/art/church.py` and `classic/church.py`) draws it as 11 frames leaning 15 degrees left to
  15 right, each row slid sideways so the pixels stay crisp, and the game lays the strip over the
  frame, fading with it. No game effect yet: calling the villagers, gossip and events come later.
- **Animals:** birds sometimes chirp where they are; frogs croak near rivers and ponds in
  spring and summer, mostly in the evening and at night and when it is warm, louder the
  closer the player is; deer snort now and then and their hooves sound when they bound
  away; rabbits rustle when they flee; squirrels chatter; bees buzz softly at their
  flower. Butterflies are silent. Where frogs are about (task 80) a quiet chorus of them
  swells on spring and summer evenings, fuller with more frogs, as warm as the croaks need
  it. Storks clatter their bills (a dry, hollow rattle) about once a minute or so while one
  is in view; geese honk now and then and when they take off, a skein flying over more
  often. Both are rare and quieter than the farm animals. A flock of crows caws now and then
  (`crow_caw`, 5 variants, `[crows]` in data/ambience.cfg) and calls out as it takes off
  (`crow_flock_rise`, 2 variants).
  The farm animals (cow, sheep, hen, dog, cat, horse) have their own sounds, quiet. A rooster's
  crow (`rooster_crow`, task 204: "cock-a-doodle-doo", three variants, about two seconds) is
  sharper and louder than a cluck (-17 dBFS against -22), since it carries across the farm; it
  is positional like the other animal sounds, faint indoors through the outside muffling.
- **How the ambience is made** (decided 2026-11-05, numbers in `data/ambience.cfg`): once
  a second the weather sets the loops: rain at its strength, wind from calm (silent) to
  full speed. A gust is heard when a gust front, the ones the plants sway in (the shader's
  formula on the CPU, with the weather view's wind and the shaders' clock), reaches the
  player (decided 2026-11-12, task 176): it plays `wind_gust` and swells the wind loop for a
  couple of seconds, softly where gusts only begin to show (3 m/s) and at full volume and
  swell in a storm, and not at all below that speed. Indoors the Ambience bus turns it down
  like the rest. Each lightning flash strikes at a distance (decided
  2026-11-13, task 214; `LightningStrike`, numbers in `data/weather.cfg` `[strike]`): 0.1 to
  12 km, drawn by band (close to 0.6 km, middle to 4 km, far beyond) with the weights 1 : 4 : 10,
  so a close one is rare (about one flash in fifteen; a full thunderstorm flashes about six times
  per game hour). The thunder comes after distance times 3 s/km in real seconds (not game time),
  as one of `thunder_close` (the crack), `thunder_mid` or `thunder_far` by band, plain (not
  positional) on the Ambience bus (muffled indoors). It gets 2 dB quieter per km (about -40 dBFS
  at 12 km for the far kind) and is low-passed from 12 kHz at the nearest strike to 600 Hz at the
  farthest: the cutoff is set on one of four DistantAmbience buses taken in turn, so a rumble
  keeps its own cutoff while it plays. One strike in six (weight 3 of 18, `crawl_weight`) is a
  sky-crawler instead: 0.6 to 12 km away like a mid or far strike, with `thunder_crawl` after the
  same delay; its flash flickers along the sky (see seasons-and-weather) and the mono rumble pans
  across the sky the same way over its length (a panner after the low-pass of each
  DistantAmbience bus, swept from 0.9 on one side to 0.9 on the other). A thunder that is due
  while the game is paused waits with the tree and comes after the pause for what was left of its delay (it is not dropped and does
  not pile up with others). Birds chirp at a chance per second by
  season (winter few), part of the day (none at night) and rain (none in heavy rain), from
  a bird in view or else a tree near the player. Frogs look at some random tiles within 12
  of the player and croak at the nearest water or wetland among them, by season (none in
  winter, few in autumn), part of the day (mostly night), warmth (none below 4 °C, full
  from 16 °C) and distance. Deer, rabbits and squirrels make their sound now and then, and
  when they start to run. The nearest two bees within 4 tiles buzz quietly as loops that
  follow them (changed 2026-11-05: they were too loud and heard from too far). The world's
  effects are muffled in a house like the weather; birds and frogs fall silent there.
