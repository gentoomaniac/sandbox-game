---
name: push-after-merge
description: "In sandbox-game, push main to GitHub (origin) after every merge without asking"
metadata:
  node_type: memory
  type: feedback
  originSessionId: 153327b6-9158-4cac-89d7-3a6186daf9e8
  modified: 2026-11-05T19:08:46.870Z
---

After every merge into `main` in sandbox-game, push `main` to `origin` (git@github.com:gentoomaniac/sandbox-game.git, via the repo-local deploy key in `.deploy-key/`). No need to ask first.

**Why:** the user answered "Yes" on 2026-11-05 to "push now, and after every merge from now on?".

**How to apply:** after merging and ticking tasks, run `git push origin main`. Only `main`; feature branches stay local. Related: [[spec-file]].
