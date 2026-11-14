---
name: godot-import-segfault
description: "sandbox-game: Godot 4.7.2 sometimes segfaults on the first start or the first --import after a change; a second try works. Known, not to investigate unless the user asks"
metadata:
  type: project
---

Seen on 2026-11-11 three times: a worker's `make test-changed` right after the art pack step, my full `make test` in a fresh scratch worktree (in `godot --headless --quiet --import`), and the user's first game start on their other machine. Each time the second try worked.

The user: "Maybe some caching issue. Keep that in mind, no investigation needed right now."

**How to apply:** when a run dies with a segfault at the import or right at start, retry once before treating it as red; worker briefs say so. If it starts happening often or on a second try, tell the user and offer a task to look into it.
