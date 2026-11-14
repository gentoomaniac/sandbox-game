---
name: send-files-to-phone
description: "sandbox-game: the user often reads on the phone; send referenced screenshots/WAVs with SendUserFile, not just paths"
metadata:
  node_type: memory
  type: feedback
  originSessionId: 8399a729-f898-40ed-a3a8-3a81782e855f
  modified: 2026-11-13T05:57:43.049Z
---

When a summary or report refers to pictures, crops, comparison shots or listening files, send them with SendUserFile (one per file, a one-line caption naming the task or question), besides giving the absolute path.

**Why:** the user, 2026-11-13, asking for /good-morning: "include referenced files in the summary since I'll likely be on the phone". Scratchpad and worktree paths can't be opened from the phone.

**How to apply:** the /good-morning skill (.claude/skills/good-morning/SKILL.md) does this for morning summaries; do the same for art and sound verdicts asked while the user is away. Related: [[questions-file]].
