---
name: save-upgrade-window
description: sandbox-game: save upgrades only for the last 10 versions; drop older steps and their tests when bumping
metadata:
  type: feedback
---

From 2026-11-08: the game keeps save-upgrade code for at most the last 10 save versions. When VERSION goes up, the oldest upgrade step, its constants and helpers, and its tests go.

**Why:** the game is in development and practically only the user plays it; old upgrade code is weight.

**How to apply:** put it in briefs that bump the save version. A save older than the window is rejected the existing way (renamed .bak). Related: [[atomic-commits]].

From 2026-11-08 also: whenever a save version becomes unreadable (an upgrade step is dropped), that change is a commit of its own with the standard subject `Save: drop the upgrade from version <N> (oldest read: <N+1>)` (for several at once: `Save: drop the upgrades from versions <A> to <B> (oldest read: <B+1>)`). Nothing else goes in that commit.

**Why:** worst case, `git log --grep '^Save: drop'` finds it, and checking out its parent gives a game that still upgrades that old save; load and save it there, then step forward to the latest.
