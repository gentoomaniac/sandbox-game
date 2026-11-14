---
name: specialist-agents
description: "sandbox-game: spawn music-composer (opus), pixel-artist (opus) and sound-designer (sonnet) from .claude/agents/ for music, art and sound-effect work"
metadata:
  node_type: memory
  type: feedback
  originSessionId: 299de3b6-007d-4e3d-9063-66dc22decf99
  modified: 2026-11-10T19:15:07.846Z
---

On 2026-11-10 the user asked for agent configs to spawn fresh workers for music, graphics and
sound effects, as these will be refined often. They live in the repo's `.claude/agents/`:
`music-composer` (opus), `pixel-artist` (opus) and `sound-designer` (sonnet). Each carries the
domain rules (style references, originality, listening/crop deliverables) and the project's
working rules.

**Why:** the user keeps refining music, art and sounds and wants specialists with the context
built in, instead of a long brief to a generic my-developer each time.

**How to apply:** use these subagent types for such work; briefs then only need the task, the
scratchpad folder for deliverables and any decisions. Keep the configs current when the user
decides something about style (update the config file directly, no reviewer). Related:
[[workers-cd-worktree]], [[quiet-test-runs]], [[test-window-title]].
