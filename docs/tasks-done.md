

## 220. Sky flocks flying north or south show the birds sideways (bug)

- [x] Done

Done: 2026-11-13. The sparrow and goose sheets got `fly_down` (front: head and breast, both wings
spread) and `fly_up` (back and tail) rows with the side view's three wingbeat frames, hand-drawn
maps mirrored one shade darker on the right, both arts (approved by the user). Flock.view_of
shows them unflipped within HEAD_ON_DEGREES (45) of the screen's vertical, the side view
(flipped by heading) otherwise; migrating flocks (at most 25 degrees off) always fly head on.
Head on the V spreads wider (`head_on_spacing`) so neighbours' wings clear. Ground flocks taking
off still use the side view.

The user, 2026-11-13: "birds flying from north to south or south to north fly sideways".
- Since task 183 the sky flocks (Flock, game/scenes/wildlife/flock.gd: the sparrow V of kind
  FLOCK and the skein of greylag geese, FLYING_GEESE) often fly north to south or south to north,
  but every bird is a side view (the `fly` animation of tools/art/animals.py and
  classic/animals.py) that only flips left or right by `_heading.x`, so a V heading south shows
  birds flying sideways.
- New art (a pixel-artist job, both arts): flying birds seen heading down the screen (the
  front: head and breast, both wings spread) and heading up (the back and tail, both wings
  spread), with the same wingbeat frames as the side view, for the sparrows and the geese.
- The flock picks the view by its heading: the side view (flipped) when it flies mostly across,
  the up or down view when mostly along the screen's vertical (threshold in data or a named
  constant: say which). The shadows stay as they are.
- Tests: the view chosen for headings around the compass; screenshots of a north- and a
  south-bound V of each kind in both arts for the user.
