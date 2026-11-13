

## 223. Birds taking off from the ground are seen from the front or behind too

- [x] Done

Done: 2026-11-13. FlightView (game/scenes/wildlife/flight_view.gd) holds the side, front and back
views and the head-on rule (45 degrees), shared by Flock, GroundFlock and Bird. Geese flying off
the marsh (GroundFlock) and sparrows taking off (Bird) pick the view from their flight direction,
unflipped head on; a sheet without the rows (oystercatcher, dunlin, gull, stork) keeps the side
view. The view is chosen at take-off and re-chosen only while a flock wheels. No new art.

The user, 2026-11-13, after task 220: birds taking off from the ground should get the new views
too.
- Task 220 gave the sky flocks (Flock) `fly_down` and `fly_up` rows for the sparrow and goose
  sheets and `Flock.view_of(heading)` (within HEAD_ON_DEGREES of the vertical: front or back,
  unflipped). Ground flocks (GroundFlock, game/scenes/wildlife/ground_flock.gd: sparrows,
  greylag geese and any other ground flock) still fly off with the side view, flipped by
  `_flight_direction.x`.
- Use the same rule for a ground flock's flight (take-off, flying away, landing if it lands
  flying): pick the view from the flight direction with `Flock.view_of` (move it to a shared
  place if that reads better), unflipped head on; the side view as today otherwise. Other single
  birds that fly (gulls, storks, the Bird class) if they share the sheets or have a fly row: say
  which, and give them the same rule only where art exists (no new art in this task unless a kind
  clearly needs it: say so).
- Tests: the view per flight direction around the compass for a ground flock; screenshots of a
  flock taking off upwards and downwards in both arts.

## 125. The deed log: what the player does near villagers, and who saw it

- [x] Done

The deeds come from the action outcomes of task 143: listen to `GameState.action_done` (see
game/state/action_outcome.gd; a hammer take-down is `take_down` for a placed object and
`demolish` for a building).

From design/villagers/gossip.md (Deeds). No language model in this task.
- A `data/gossip.cfg` with the deed kinds (felled a tree, built a building, took down a building,
  placed a fence or wall, tilled, sowed, harvested, dug clay, mowed), each with its words and a
  fixed opinion change for later, the radius (20 tiles, 6 at night) and the place words per biome.
- A deed log in the game state, saved (save version bump): each deed within 20 tiles of any
  villager as `{day, minute, kind, count, place, witnesses}`; the same kind and place on the
  same day merge, adding up the count and the witnesses. Kept for 7 days.
- The place in words: "by <name>'s house" for the villager whose home is nearest within 20 tiles,
  else the biome's word.
- Every villager within the radius is a witness and gets the deed as a story they saw at once,
  for now kept in a plain list on the villager (task 126 makes it the gossip buffer). The chat
  prompt tells it as a template line ("Today you saw the newcomer fell 7 trees by Antje's house.").
- Console: `deeds` lists the log.
- Tests: logging, merging, witnesses by radius and night, the place words, save and load.

Done: f6be06e6. Nine deed kinds in data/gossip.cfg; witnesses within 20 tiles by day, 6 at night; kept 7 days, pruned on record, new day and load; saved (version 34) in GameState.deeds and each villager's stories; the newest 5 stories are told in the chat prompt; console `deeds`. Not deeds: digging up a bush, taking down placed objects (only demolishing a building), anything indoors.

## 212. Wild rabbits flee even when asleep

- [x] Done

The user, 2026-11-11: "Wild rabbits should run away even when sleeping"
- Find out what the user saw: a wild rabbit (WildlifeRules RABBIT, `flee_tiles`) that rests or
  sleeps (by its phase weights at night, or a resting state) and then ignores the player, or the
  tame rabbit (a farm animal, task 173) asleep. Fix it so a sleeping or resting wild rabbit wakes
  and flees when the player comes within its flee distance (maybe a little closer than when
  awake: a startled jump first). Check the other wild ground animals (squirrel, deer, mouse, frog)
  for the same gap and give them the same rule if they have it. The tame rabbit and the farm
  animals keep sleeping (they are used to the player).
- Tests: a sleeping wild rabbit flees when the player comes near; a sleeping tame rabbit does
  not.

Done: closed without a change (the user, 2026-11-13): sleeping rabbits, wild or tame, keep sleeping.
