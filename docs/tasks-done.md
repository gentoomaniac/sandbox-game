

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
