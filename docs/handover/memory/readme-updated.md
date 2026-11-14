---
name: readme-updated
description: "sandbox-game: README is a short pitch with a few shots; the player handbook (handbook/) gets the feature text, controls, console commands and screenshots with every merged feature"
metadata:
  node_type: memory
  type: feedback
  originSessionId: 153327b6-9158-4cac-89d7-3a6186daf9e8
  modified: 2026-11-13T23:32:05.483Z
---

Keep the player documentation current as features land, in the right place:
- **handbook/** (player handbook, topic pages): feature text, controls, console commands, settings,
  and the screenshots in docs/screenshots/ that show them.
- **README.md**: short (about 100-150 lines): what the game is, 4-6 representative shots, a
  one-line feature list linking to the handbook, how to run it, main controls. Touch it only when a
  feature belongs in that short list or a representative shot is outdated.
- Developer material (make targets, debug flags, tools) goes to docs/, not the handbook.

**Why:** the user reminded me on 2026-11-05 to keep the readme updated; on 2026-11-14 they said the
README had "way too much text and is more like a documentation than a readme" and asked for a short
README with representative shots and the rest as a handbook (docs/ holds development docs).

**How to apply:** in every worker brief, say "update the handbook page (and screenshots if the look
changed); the README only if the short feature list or a representative shot changes". Check it at
merge time. Related: [[spec-file]], [[push-after-merge]].
