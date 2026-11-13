

## 204. A rooster among the chickens, crowing now and then

- [x] Done

Done: 2026-11-13. A chicken flock (chickens within `[rooster] flock_tiles` 12 of one another or of
a coop, ChickenFlocks) has one rooster (look `rooster`): random looks never pick him, a flock that
gets its first hens gets one, `spawn rooster`/`killall rooster`; he lays no eggs and counts as a
chicken elsewhere. Save version 32 gives every old flock one (extra rooster-look chickens become
brown hens). He crows a run of 2-4 around sunrise (following the season) and 1-2 now and then by
day, never asleep, at night or in the coop (Crowing, `rooster_crow`, three generated variants, heard
60 tiles, muffled indoors). The 32 px rooster was redrawn a head taller than his hens (34x32 cell,
upright, arched sickle tail; approved by the user), his petting mark and z's use his own head
(LOOK_HEADS). The classic rooster stays hen-sized. Known: merged flocks keep two roosters; a split
flock gets one at the next spawn.

The user, 2026-11-11: "The chicken need a rooster that's occasionally shouting"
- Today the chickens (data/livestock.cfg, the chicken coop of task 122) are all hens with a cluck
  (`chicken_cluck` in data/sounds.cfg).
- Add a rooster: a chicken flock has one (a flock that gets its first hens gets a rooster too;
  `spawn rooster` in the console; old saves get one per coop or flock, with the save upgrade per
  the save rules). Bigger than a hen, upright tail and red comb and wattles: art in both sets, the
  same moves as the hens (a pixel-artist job); it walks and pecks with them, sleeps in the coop,
  lays no eggs, can be petted (friendship, task 173) and counts as a chicken where the game counts
  them (or say where it doesn't).
- It crows now and then: most at dawn (a run of crows around sunrise), a few times through the
  day, never at night while asleep. A new generated cock-a-doodle sound (2 or 3 variants, a
  sound-designer job), positional, heard across the farm, faint indoors like other outside
  sounds. How often: pick it, numbers in data/ (the user tunes them).
- Tests: a flock has a rooster, it lays no eggs, it crows at dawn and not at night, save and load;
  a listening file and a picture of the rooster in both arts for the user; README, design pages.
