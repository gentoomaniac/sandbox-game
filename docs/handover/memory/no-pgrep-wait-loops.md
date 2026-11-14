---
name: no-pgrep-wait-loops
description: "sandbox-game: briefs forbid any pgrep/sleep wait loop (run_tests.py, make test, godot); they match themselves or never end"
metadata:
  node_type: memory
  type: feedback
  originSessionId: 299de3b6-007d-4e3d-9063-66dc22decf99
  modified: 2026-11-09T17:51:31.811Z
---

Workers and reviewers must not wait for test runs with loops like `until ! pgrep -f "tools/run_tests.py"; do sleep 5; done` or `while pgrep -f run_tests.py`. The pattern also matches the loop's own `bash -c` command line, so the loop never ends; on 2026-11-09 eighteen such loops were left sleeping for up to 4h40m after their agents had finished, and the user saw them as "processes still running". Killing them was refused by the permission check, so the user had to stop them.

On 2026-11-12 a worker (task 216) did it again with other patterns despite the brief: `while pgrep -f "make test"` (matches itself) and `while pgrep -x godot` (never ends: the user's editor runs a godot LSP all the time), plus background `sleep 290` timers.

**Why:** the user noticed leftover background processes and asked what was still running.
**How to apply:** in every worker and reviewer brief, forbid ANY background wait/poll loop (`pgrep`, `sleep`, `while`/`until` over processes), not just the run_tests.py one, and say the user's editor keeps a godot process running at all times: run `make test` in the foreground (with a timeout) instead of polling; if a wait is unavoidable, use `pgrep -f '[r]un_tests.py'` so the pattern can't match itself. Related: [[quiet-test-runs]].
