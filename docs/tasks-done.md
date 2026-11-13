

## 214. Thunder by distance: delay, loudness and sound fit how far the strike was; now and then a close one

- [x] Done

Done: 2026-11-13. Each flash draws a LightningStrike: close (0.1-0.6 km), mid (to 4 km) or far (to
12 km), weights 1 : 4 : 10 (about 1 strike in 15 is close; no hard cap), data/weather.cfg
[strike]. Thunder follows after 3 real seconds per km (paused with the game, so none pile up), as
thunder_close, thunder_mid or thunder_far (new generated sounds, 3 variants each, -2/-9/-16 dBFS),
2 dB quieter per km and low-passed from 12 kHz near to 600 Hz far, through a pool of four
DistantAmbience buses (each sound keeps its own cutoff) into Ambience, so indoors it is muffled and
it fades with the pause like the rest. The flash peaks 0.9 near down to 0.12 far; far strikes swell
in as a sky glow. No bolt is drawn for the close strike. The old `thunder` event is removed.

The user, 2026-11-11: "Thunder and lightning need to carry on loudness and delay to simulate
different distances. Also some different varieties like the occasional close lightning strike"
- Today a lightning flash (data/weather.cfg [thunder], `lightning_per_minute`) is followed after
  `thunder_delay` by one of four `thunder` sounds (game/scenes/ambience_sounds.gd), all the same
  loudness, the delay random and not tied to the flash.
- Each strike gets a distance (drawn per flash, far ones most common): the thunder comes after
  about distance / speed of sound (about 3 s per km; game time or real time: say which, real
  seconds feel right), quieter and duller (low-passed, longer rumble) the farther it is, and the
  flash is fainter and more diffuse the farther it is (a sky glow far off, a bright white flash
  near). Numbers in data/weather.cfg (distance range and weights, loudness and filter by distance).
- Varieties (a sound-designer job, generated in tools/audio like the others): a far rolling rumble,
  a middle-distance roll, and the rare close strike: a sharp crack almost at once with the flash,
  very loud, then a heavy rumble; maybe a bright bolt drawn in the sky or a screen flash for the
  close one (the flash view exists: extend it). The close strike is rare (a few per storm at most).
- Indoors: muffled like the other outside sounds (the OutsideEffects bus); the flash seen through
  windows only as today.
- Tests: the delay grows with distance, loudness falls with it, close strikes are rare and use the
  crack variety; listening files (far, middle, close) for the user.
