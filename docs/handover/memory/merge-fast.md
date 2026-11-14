---
name: merge-fast
description: "sandbox-game: from 2026-11-08 every atomic commit goes to main as soon as it passes tests and a quick review; the coordinator merges; no long-lived feature branches"
metadata:
  node_type: memory
  type: feedback
  originSessionId: 153327b6-9158-4cac-89d7-3a6186daf9e8
  modified: 2026-11-08T22:42:18.573Z
---

Trunk-style flow, set by the user on 2026-11-08 (after the 32 px art groups), because response, test and integration times had become the main hurdle and parallel feature branches caused much merge work.

- Commits stay atomic ([[atomic-commits]]), and each must not break main.
- A worker reports **each** commit as soon as it passes `make test`/`make lint`/`make -o .venv/.installed assets` on top of the current main. It does this with SendMessage to "main", giving the sha and a one-line summary, then keeps working on the next commit.
- Before reporting, the worker rebases onto main and re-runs the checks if main moved. Integration testing thus runs in parallel in the workers' worktrees.
- **Review before each merge** (the user's choice): a quick reviewer per commit, reading only `git show <sha>`, never the worktree, so it can run while the worker works. Use Haiku for small or mechanical commits and Sonnet for larger ones or shared code.
- **The coordinator merges** (the user's choice). On approval, run `git merge --ff-only <sha>` on main and push. There is no extra verify loop of my own: the worker's run on the rebased commit counts.
- If the review wants changes to a commit that is not merged yet, the worker fixes it with fixup + autosquash and re-reports. Merged commits are never rewritten; later fixes are new commits.
- Shared code is released early: a commit others depend on goes in first.
- If two tasks touch the same code, a separate worker owns the shared code and implements what the other workers are missing. The task workers don't each change it.

**Why:** the user asked on 2026-11-08 to "merge fast back to main"; feature branches living in parallel caused significant integration and merge time.

**How to apply:** put this flow in every worker brief (the brief template rules32.md in the session scratchpad has it). It replaces "verify each commit at the end, then the coordinator verifies again", and makes [[verify-idle-worktrees-only]] mostly moot. Related: [[push-after-merge]].
