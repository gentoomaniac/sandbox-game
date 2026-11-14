---
name: to-test-file
description: "sandbox-game: keep TO-TEST.md (untracked, in .git/info/exclude) in the main checkout listing what the user should try by hand after each merge"
metadata:
  type: feedback
---

The user, 2026-11-11: "Make me a separate file untracked what I should test once I'm back at my PC".

**Why:** the user tests merged features in the game later, away from the conversation.

**How to apply:** after each merge, add a section "## Task N: title" to /home/marco/git-private/sandbox-game/TO-TEST.md with checkbox lines that each start with the task number ("- [ ] N: what to try"), plus where the tuning numbers live (the user asked for the number on every line). Keep open questions for the user at the bottom. It is untracked: never commit it. Leave lines the user ticked or deleted alone. Related: [[readme-updated]].
