---
name: atomic-commits
description: "sandbox-game: one commit per suggestion/change so each can be reverted on its own; don't squash"
metadata:
  node_type: memory
  type: feedback
  originSessionId: 153327b6-9158-4cac-89d7-3a6186daf9e8
  modified: 2026-11-05T23:44:10.939Z
---

Commits are atomic per suggestion or change: each holds its code, regenerated assets, tests and doc lines, passes the tests on its own, and is not squashed into others when merging.

**Why:** on 2026-11-06 the user asked, for the art style changes, "Make sure commits are atomic to the suggestions so that we can revert if necessary".

**How to apply:** put it in every worker brief that covers several changes; merge with fast-forward (no squash); my own review fixes go in separate commits. Related: [[push-after-merge]], [[readme-updated]].
