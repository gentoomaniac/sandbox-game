---
name: questions-file
description: "sandbox-game: while the user is away, collect questions in QUESTIONS.md instead of asking"
metadata:
  node_type: memory
  type: feedback
  originSessionId: 153327b6-9158-4cac-89d7-3a6186daf9e8
  modified: 2026-11-05T23:12:17.678Z
---

When the user is unavailable, don't block on questions: proceed with a sensible default and write the question (with the default taken) into QUESTIONS.md at the repo root, committed and pushed. Answered questions move into SPEC.md and leave the file.

**Why:** the user said on 2026-11-06 "I'll be unavailable so keep questions for later when I'm back in an extra markdown file".

**How to apply:** no AskUserQuestion while they are away; record decisions taken on their behalf there too, so they can confirm or change them. Related: [[spec-file]].
