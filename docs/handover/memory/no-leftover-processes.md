---
name: no-leftover-processes
description: sandbox-game: after every task, check no subprocess (godot, run_tests, make, wait loops) is left running; the user's CPU burns
metadata:
  type: feedback
---

After every finished task (and after each review or worker run), check that no subprocess is left behind: Godot test shards, tools/run_tests.py, make, `until ... sleep` wait loops, scratch clones still running tests. The user said on 2026-11-09: "after every task finished, make sure it doesn't leave any subprocesses around. It's burning my cpu :)".

**Why:** leftover test runs and wait loops kept running for hours after their agents finished.
**How to apply:**
- Put the rule in every worker and reviewer brief: check with `ps` before the final report and stop your own processes; no background test runs.
- After each task notification, run `ps -eo pid,etime,args | grep -E "godot|run_tests|make|sleep"` myself.
- Killing processes is blocked by the auto-mode permission check. List the leftovers to the user with a ready `kill` command instead.

Related: [[no-pgrep-wait-loops]], [[quiet-test-runs]].
