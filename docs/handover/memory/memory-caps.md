---
name: memory-caps
description: "sandbox-game: test runs are memory-guarded by make itself since #142 (memguard, lock, shard sizing); use make targets, never bare godot; why: OOM kills took VSCodium down twice on 2026-11-17"
metadata:
  type: feedback
---

On 2026-11-17 the kernel OOM-killed VSCodium twice (06:07 and 07:07), and with it the session and every worker. The user: "Make sure we're not OOM crashing again", and "we need to have the guards in our tests as OOM kills kill the whole vscode with the main session".

What I measured:
- A full suite at 8 shards needs about 18–20 GB, at 2–3.4 GB per shard.
- Some single Godot processes reached 12.5–17.7 GB (suspected: a cold import in a fresh worktree).
- systemd stops the whole unit a killed process belongs to, so a Godot started from the editor terminal took the editor down with it.

Since #142 (merged 2026-11-17), `make test`, `make test-changed`, `make screenshot` and the import guard themselves. tools/memguard.py:
- runs each run in its own scope in sandbox-tests.slice;
- kills a run when free memory falls below the floor, or when a shard goes over 5 GB, and names the test it was in;
- sizes the shards to fit the free memory;
- takes the lock `${XDG_RUNTIME_DIR}/sandbox-game-test.lock`.
The details are in docs/development.md.

**Why:** a test run must never take the user's editor or the session down.

**How to apply:**
- Run Godot only through make targets or `tools/memguard.py -- <cmd>`, never as a bare `godot`, in my own runs and in every worker and reviewer brief.
- Workers can't use hand-typed `systemd-run --slice` wrappers: the permission check refuses them when they come from an agent message. The make targets need none.
- A fresh worktree: symlink addons and assets, and copy `.godot` from the main checkout before the first Godot run, to avoid the cold import. Point a symlinked `.venv` past make with `make -o .venv/.installed`.
- Optional extra guard: `systemctl --user set-property --runtime sandbox-tests.slice MemoryMax=20G` caps all runs together. It is runtime only, so a reboot drops it.
- `my-developer` workers are always worktree-isolated, so they can't work in an old worktree. To take over a dead worker's work, commit its leftovers as WIP on its branch and have the new worker `git reset --hard <branch>` in its own worktree.

On 2026-11-18 memguard blocked every full run at the 3000 MB floor although the processes used only a few GB: the ZFS ARC held 11–15 GB, which `MemAvailable` does not count (see docs/development.md). I asked the user to cap `zfs_arc_max` (root); no answer yet. Don't lower the floor or change memguard to count the ARC without the user's yes.

Related: [[no-leftover-processes]], [[quiet-test-runs]], [[merge-check]].
