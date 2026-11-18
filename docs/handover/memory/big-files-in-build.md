---
name: big-files-in-build
description: "sandbox-game: screenshots, world maps, art crops and other big outputs go in the worktree's build/ (NVMe), not /tmp or the scratchpad (tmpfs = RAM); in every brief"
metadata:
  type: feedback
---

/tmp is a tmpfs, so every file in it, the Claude scratchpad included, takes RAM. On 2026-11-18 the session scratch folders under /tmp/claude-1000 had grown to 13 GB, on a machine already short of memory (see [[memory-caps]]). The user: "keep it in build, that FS is nvme backed so fast enough".

**Why:** files in /tmp compete with the test runs and the editor for memory, and add to the OOM risk.

**How to apply:**
- Screenshots, world maps, art crops, renders, logs and any other output bigger than a few KB go in `build/` of the checkout or worktree that makes them (e.g. `OUT=build/shots/x.png`, `MAP_OUT=build/maps/x.png`). `build/` is ignored by git and `make clean` empties it.
- The scratchpad is only for small notes, plans and briefs.
- Say this in every worker, reviewer and specialist brief.
- Files to send to the user's phone can be sent straight from `build/`.

Related: [[memory-caps]], [[quiet-test-runs]].
