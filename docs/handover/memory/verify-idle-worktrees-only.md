---
name: verify-idle-worktrees-only
description: "sandbox-game: run the per-commit verification loop only in a worktree whose worker has finished, never while it still works there"
metadata:
  node_type: memory
  type: feedback
  originSessionId: 153327b6-9158-4cac-89d7-3a6186daf9e8
  modified: 2026-11-06T16:54:49.925Z
---

Run the per-commit verify loop (checkout each commit, `git checkout -- .`) only in a worktree whose worker has finished and isn't resumed.

**Why:** On 2026-11-06 I ran it while the task-83 worker was fixing review findings. The commit IDs changed mid-run, the loop could discard the worker's uncommitted edits, and the main checkout ended up on the task branch.

**How to apply:** After sending a worker fixes (SendMessage resumes it), wait for its report before verifying. Rebase or verify only after it reports.

Also never alongside a reviewer reading the same worktree, and never a second loop while one still runs there (the loop checks out older commits). On 2026-11-07 a Haiku reviewer of task 89 saw the worktree detached at the first commit and reported the docs commit as missing, and my next loop overlapped a still-running background one. Run the review first, then the verify loop; or verify in the foreground before starting the review.
