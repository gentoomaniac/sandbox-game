---
name: confirm-before-new-tasks
description: "sandbox-game: start no new task without the user's explicit \"yes\" for that task (repeated 2026-11-09); finishing running ones is fine"
metadata:
  node_type: memory
  type: feedback
  originSessionId: 299de3b6-007d-4e3d-9063-66dc22decf99
  modified: 2026-11-09T20:41:08.269Z
---

Start no new task on my own. Ask the user to confirm each start. Repeated on 2026-11-09 ("wait for my confirmation before you start anything new"), after I started 144 on my own reading of an earlier "start the review tasks".

**Why:** the user wants control over what runs. On 2026-11-06 it was to slow down after parallel churn. On 2026-11-09 I started a task in a chain without asking.

**How to apply:**
- Finishing a running task without asking is fine: its reviews, fixes, verification and merge.
- Anything not yet started needs a "yes" first, even if it is the next one in a chain the user approved earlier ("after X, start Y"). Follow-ups and small tasks I add myself count too.
- When a task finishes, report it and propose the next one; don't start it.

**Exception (2026-11-11):** the user said "put 176 at the end, then start the queue one after the other without confirmation unless you have questions". So the TASKS.md queue runs in order, one task at a time, without asking. Ask only when a task raises a real question. Tasks added later still need a yes before they join the queue, and this holds only until the user takes it back.

Related: [[questions-file]].
