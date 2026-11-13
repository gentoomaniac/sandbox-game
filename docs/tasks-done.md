

## 209. Animals stuck at a fence turn left and right for a long time (bug)

- [x] Done

Done: 2026-11-13. Cause: Livestock._walk tried straight, then detours of ±0.6, ±1.2 rad each
frame and turned the animal to whichever worked, so behind a fence it faced left and right every
frame (about 80 flips in 6 s), and every detour counted as progress, so nothing gave up. Now a
detour turns the animal at most once per `turn_hold_seconds` (1 s); `stuck_seconds` grows on
detour and blocked steps and restarts once the animal has moved `progress_tiles` (0.3); after
`blocked_give_up_seconds` (2 s) a wanderer picks something else, a trip to water or feed is given
up for a while, and a follower waits facing the player for `follow_retry_seconds` (3 s) instead of
being teleported through the fence (still put beside the player beyond 15 tiles). Every species;
villagers have their own walking code and were not changed. The cat hunt moved into CatHunt to keep
livestock.gd under the line limit. Known limit: a follower shut in a closed pen waits until the
player walks off; the steering cannot route round a fence when the goal is straight behind it.

The user, 2026-11-11: "Sometimes horses, potentially other animals as well, get stuck on a fence
and start spinning left right for a long time."
- Reproduce first: a horse (and the other farm animals and pets: cow, sheep, pig, chicken, dog,
  cat, rabbit) wandering, following the player or grazing next to a fence or wall (the pen fence of
  task 165, wattle fences, stone walls, Knicks, buildings since task 181), and a wander target or
  follow target on the other side. Find the cause: a target beyond the fence with no path, a
  steering that flips its facing every frame when the direct way is blocked, a body wider than a
  tile (the horse) touching the fence on both sides, or a stuck check that never fires.
- Fix it at the cause: an animal never flips its facing back and forth (a short hold on a new
  facing, or face by the path not by each blocked step); a blocked target is given up after a
  short try and a new one picked on its own side; a following animal that can't reach the player
  waits facing them. Same rules for every animal kind, and for villagers if they share the code.
- Tests: a horse with a target behind a fence stops turning within a few seconds and picks another
  target; facing changes at most a few times in that span; the same for a small animal and for a
  following dog.
