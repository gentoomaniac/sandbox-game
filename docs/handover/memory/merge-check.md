---
name: merge-check
description: "sandbox-game: before merging, test only the branch tip; bisect only if it is red; make art only when generators changed; fold fixups in before the first check"
metadata:
  node_type: memory
  type: feedback
  originSessionId: 299de3b6-007d-4e3d-9063-66dc22decf99
  modified: 2026-11-11T14:08:43.980Z
---

Set by the user on 2026-11-11, replacing my per-commit verify loop (which cost 5-6 min per commit and was rerun after every fixup or rebase).

- **Tip first:** before merging a branch, run `make test-changed BASE=main` (task 192; it selects by the whole range, adds `make art` when generators change, falls back to the full run when unsure) and `make lint` on its last commit only. Green → merge. A worker's green full `make test` on the branch rebased onto the current main also counts.
- **Full run every 5 merges** (or at the end of a batch): a full `make test` on main in a detached scratch worktree; if red, bisect over the merges since the last green full run. Count in the scratchpad file `merges-since-full`.
- **Bisect on red:** if the tip fails, bisect over the branch's commits to find the first failing one, and get that commit fixed. The user accepts the small risk that an inner commit is broken and a later one fixes it.
- **Keep the .godot import cache** between runs; never delete it in the main checkout (that broke the user's running game on 2026-11-11: bird_chirp_2.wav failed to load).
- **Fold fixups in before the first check:** wait for review findings and the user's look verdicts, have them folded in, then run the check once.

**Why:** the per-commit loop and its reruns were the biggest time cost; most branches have few commits.

**How to apply:** script at the session scratchpad `mergecheck.sh <worktree> <branch> [base]` (rewrite it if the scratchpad is gone). Still never run it in a worktree whose worker is active ([[verify-idle-worktrees-only]]). Related: [[merge-fast]], [[atomic-commits]].
