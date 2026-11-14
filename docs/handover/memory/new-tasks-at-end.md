---
name: new-tasks-at-end
description: "sandbox-game: a new task goes to the end of the TASKS.md queue unless the user names a place"
metadata:
  type: feedback
---

The user, 2026-11-11: "Put that task at the end of the queue. All other new ones as well" (after I put task 201 next in line).

**Why:** the user decides the order; new requests shouldn't jump ahead of what's already queued.

**How to apply:** add every new task just before "## Later" in TASKS.md, unless the user says where it goes ("next", "before X", "start now"). Bug reports too. Related: [[confirm-before-new-tasks]], [[spec-file]].
