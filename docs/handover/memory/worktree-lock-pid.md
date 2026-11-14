---
name: worktree-lock-pid
description: "sandbox-game: the pid in a \"claude agent\" worktree lock is Claude Code itself; never ask the user to kill it"
metadata:
  node_type: memory
  type: feedback
  originSessionId: 299de3b6-007d-4e3d-9063-66dc22decf99
  modified: 2026-11-10T16:18:47.175Z
---

The pid named in a worktree's lock reason ("claude agent agent-… (pid N …)") is the Claude Code
process, not a leftover worker. On 2026-11-10 I asked the user to kill it to free a merged
worktree; that killed the session and the running stork worker (task 152), which had to be resumed.

**Why:** the lock only says which session made the worktree; the agent itself is in-process.
**How to apply:** for a merged, locked agent worktree, stop the agent with TaskStop, then
`git worktree unlock` + `git worktree remove --force` myself. Only hand the user kill commands for
real leftovers (godot, run_tests, make, opencode serve), checked with ps. See [[no-leftover-processes]].
