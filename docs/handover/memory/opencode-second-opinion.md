---
name: opencode-second-opinion
description: "sandbox-game: for a review with a different opinion, run opencode with OpenAI GPT 6.1 Sol at high effort"
metadata:
  node_type: memory
  type: reference
  originSessionId: 299de3b6-007d-4e3d-9063-66dc22decf99
  modified: 2026-11-10T00:42:35.131Z
---

Set by the user on 2026-11-10: when a review needs a different opinion than the Sonnet
my-reviewer gives, call opencode with OpenAI GPT 6.1 Sol at high reasoning:

`opencode run -m 'openai/gpt-6.1-sol#high' "<review brief>" </dev/null` (run from the worktree to review;
read-only brief, no edits; always close stdin with `</dev/null`, else a background run hangs forever with no output). Model ids: `opencode models | grep 6.1-sol`.

**Why:** a reviewer from another model family catches what Sonnet reviewers agree on by habit.
**How to apply:** optional, for larger or riskier changes (e.g. task 154's Simulation refactor);
tell the user when it runs, and add a row (date, what, why, outcome) to
/home/marco/git-private/sandbox-game/second-opinions.md, which is gitignored and kept local. Related: [[merge-fast]], [[atomic-commits]].
