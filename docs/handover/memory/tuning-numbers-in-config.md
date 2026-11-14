---
name: tuning-numbers-in-config
description: "sandbox-game: game-balance numbers (yields, chances, bonuses) are picked by the worker and put in data/; don't ask the user to confirm them"
metadata:
  type: feedback
---

The user, 2026-11-11, on the kiln's skill bonus: "Don't ask me for it, I can fine tune the extra layer in the config file."

**Why:** the user tunes balance numbers themselves in data/*.cfg; asking them to confirm each default slows things down.

**How to apply:** in briefs and task text, let workers pick sensible balance numbers and put them in data/. Don't relay the numbers as questions; at most mention where they live. Design choices (behaviour, UI, rules) still go to the user. Related: [[questions-file]].
