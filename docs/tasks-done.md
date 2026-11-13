

## 211. Sleeping animals show a "zzz" now and then

- [x] Done

Done: 2026-11-13. A sleeping farm animal or pet on screen shows the player's rising "z"s
(SleepZs, effects/sleep_z.png, both arts) from its head (FarmAnimalView.HEADS) now and then:
`[zs] gap_seconds` 6-20 and `shown_seconds` 3-5 in data/livestock.cfg, each animal its own seeded
dice; the rise per species is art geometry in FarmAnimalView.ZS_RISES. Nothing while awake, off
screen or housed; waking or petting clears them (the anger mark still shows). No wild animal
sleeps in the game. The rooster uses the hen's head until his redraw (task 204) lands.

The user, 2026-11-11: "Add the zzz bubbles occasionally to sleeping animals."
- The player's "zzz..." bubble exists (game/scenes/tiredness_signs.gd, BUBBLE_ICON `zzz`); farm
  animals and pets know they are asleep (FarmAnimalView `is_asleep`, FarmAnimal.Activity.SLEEP),
  and the petting marks of task 173 already sit over each kind's head (FarmAnimalView.HEADS).
- A sleeping animal shows a small "zzz" rising over its head now and then (not all at once and not
  all the time: a random gap per animal, a few seconds shown), sized for the animal, in both arts;
  reuse the bubble art or the petting-mark placement. Farm animals and pets; wild animals too if
  they sleep in the game (say which do). Nothing while awake; it goes when the animal wakes or is
  petted (the anger mark of task 173 wins). Numbers (gap, duration) in data/.
- Cheap: a timer per sleeping animal on screen, nothing for animals off screen.
- Tests: a sleeping animal shows it within the gap and not while awake; screenshots of a sleeping
  cow and chicken in both arts for the user.
