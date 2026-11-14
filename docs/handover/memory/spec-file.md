---
name: spec-file
description: The design document (design/ tree, was SPEC.md) and TASKS.md are living planning docs; update them on every decision and commit to git
metadata:
  node_type: memory
  type: feedback
  originSessionId: 153327b6-9158-4cac-89d7-3a6186daf9e8
  modified: 2026-11-05T07:51:50.483Z
---

Keep the design document up to date with every design decision as it is made. Since 2026-11-08 it is the `design/` folder tree (index design/README.md, one file or folder per category, draft images allowed beside the text; the user asked for the split); SPEC.md is gone. `TASKS.md` holds only the open tasks and the "Later" ideas. Since 2026-11-09 (the user: "from now on put all the done tasks into a separate document"), a merged task is ticked, given its "Done:" note and moved with its full text to `docs/tasks-done.md`, in the task's last commit; put that in every worker brief.

Commit every file change to git ("keep all files in git", 2026-11-05), not only the docs.

**Why:** the user asked on 2026-11-05 for all design ideas to go into a spec file that stays current, and for all files to be kept in git.
**How to apply:** after each decision, edit the matching design/ file in the same turn and commit; briefs point workers at design/.
