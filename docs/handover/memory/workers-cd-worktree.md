---
name: workers-cd-worktree
description: sandbox-game: worker AND reviewer briefs must say never to run git checkout in the main checkout (read with git show/diff); workers and reviewers switched main's checkout
metadata:
  type: feedback
---

Every worker brief must say: start every git or make command with `cd <worktree> &&`. It must also say never to run checkout, switch or rebase in the main checkout. Before each commit or merge on main, check `git branch --show-current` and stop unless it prints `main`.

**Why:** On 2026-11-06, two workers (tasks 83 and 80) ended with "git checkout <branch>" while their shell had fallen back to the repo root. That switched the main checkout to their branch. My next commits (a Makefile fix, then two NPC docs) landed on task branches, and `git push origin main` silently pushed nothing new.

On 2026-11-10 my-reviewer agents did it too: one detached HEAD in the main checkout "while reading files" (it said so), and the 149 one left it detached at the branch tip.

**How to apply:** Reviewer briefs too: read only with `git show <ref>:<path>` / `git diff`, never checkout. Put the rule in the project-rules block of every brief. Chain `[ "$(git branch --show-current)" = main ] &&` in front of merges and commits on main. Related: [[verify-idle-worktrees-only]].
