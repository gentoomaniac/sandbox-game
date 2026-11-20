# Handover

The state of the work for the next coordinating agent, as of 2026-11-20. The rules are in
[TASKS.md](../../TASKS.md), [docs/development.md](../development.md) and the
[memory notes](memory/MEMORY.md) (one rule per file, kept in the repo). Read those first, then this. Update this file when you hand over again.

## How the work runs

- The tasks are GitHub issues on the [project board](https://github.com/users/gentoomaniac/projects/2).
  The board holds the order and the state. Keep it current.
- You coordinate. Workers are `my-developer` and reviewers `my-reviewer` (both Sonnet), and art,
  sound and music go to the specialist agents. Tell the user which model each runs on.
- Every task gets a review until it's approved. You run the full `make test` on the branch tip,
  fast-forward merge it to main as atomic commits, and push after every merge.
- At most two tasks run at a time. On 2026-11-18 the user narrowed this: **only run #155** until
  they say otherwise.
- After a merge, move the card to To test, add a hand-test checklist to the issue, and add the
  same lines to the untracked `TO-TEST.md` in the main checkout.
- Board ids (for `gh project item-edit`):
  - project `PVT_kwHOAD5Uec4BrmlZ`;
  - Status field `PVTSSF_lAHOAD5Uec4BrmlZzhp4imc`;
  - options: Needs answer `91d8f50b`, Backlog `aeea0a99`, Queue `6189ce60`, In progress
    `d79ae0e6`, In review `59c3d24d`, To test `c9dd03fd`, Done `b8fea50a`.
  - New issues usually auto-add to the board. If they haven't yet, `gh project item-add` returns
    the item id.

## In flight

### #155 Frame rate drops to about 11 fps in winter with footprints (In review)

- **Branch:** `worktree-agent-af2b84f36d8ccaec0`, worktree
  `.claude/worktrees/agent-af2b84f36d8ccaec0`, two commits on main `5c071bf6`:
  - `4a36bfda` a bench, `tools/bench/footprints.gd`;
  - `8509624d` the fix.
- **Cause:** the footprints used `GroundCover.is_snowed`, a slow search of up to 1 ms per call, on
  every step and every ring slot. They now use `CoverMap.is_snowed`, which reads the ground that's
  already drawn.
- **Bench:** 133 ms down to 6.8 ms a frame with 7,840 prints, the same as without prints.
- **Review:** APPROVED, no blockers.
- **Not yet done:** the full `make test`. The footprint and cover tests and `make lint` pass.
- **Next:**
  1. Rebase it on main (docs commits only since).
  2. Run the full suite.
  3. Merge, push, and move it to To test.
- **Hand test:**
  - a winter day with snow and several villagers walking: about 60 fps, footprints look as before;
  - prints vanish when the snow melts;
  - prints appear on a chunk you just walked onto.

### #22 Where crafting lives (paused in the Queue)

- **Branch:** `worktree-agent-a7d354b068601e62a`, worktree
  `.claude/worktrees/agent-a7d354b068601e62a`, behind main. Four commits:
  - `8d2121e7` the kiln, oven and net frame are made at the workbench, the rest by hand;
  - `cebcfecd` hand crafting moves into the bag as a second "Crafting" page;
  - `f9087519` Shift+C is removed, and `crafting` goes into RETIRED_ACTIONS;
  - `ba29efa5` a cleanup.
- **Not tested yet.** Rebase it, then run the full suite. These tests were rewritten and are the
  likely failures: test_bag_crafting, test_click_areas, test_modal_keys, test_bag_key,
  test_settings_c_key, test_view_rebinding. Then screenshots, a review, the merge.
- **Open questions for the user:** is the recipe split right; does the workbench icon button stay;
  should bag crafting be blocked on horseback?

### #45 The river gets thin in steep bends (paused in the Queue)

- **Branch:** `worktree-agent-adaed166213de2c07`, one WIP commit `334b8d18`:
  - meanders: MEANDER_AMPLITUDE 90→60, MEANDER_FREQUENCY 0.003→0.0025, BEND_AMPLITUDE 5→4;
  - the slope bound in `tests/test_river_line.gd` is now 0.75;
  - `design/world/generation.md` updated.
- **Untested.** The world fingerprint hashes still need updating.
- **Plan after that:**
  1. Inner-bend bars: `RiverLine.is_bar` via the curvature, FLOODPLAIN terrain, crossed like a
     ford.
  2. Before/after maps via
     `make world-map SEED=42 AT=0,-60 MAP_SIZE=320 MAP_SCALE=4 MAP_OUT=build/maps/...`.
- **Open question for the user:** are bars that look like ford shallows OK?
- **To continue:** have a new worker `git reset --hard worktree-agent-adaed166213de2c07` in its own
  worktree. Split the WIP into atomic commits.

## The Queue

The Queue runs in board order. The newest at the end: #154 (at the top, LLM request count, budget,
back-off and bundled judging at most every half game day), then #46, #23, #143, #145–#153, #155,
#156, #157. #144 (watermill) is in the Backlog.

Open questions written on the issues, with the defaults the worker should use if no answer comes:
- **#147:** does the windmill turn on its own, with the door fixed?
- **#149:** are tools left out of gifts?
- **#152:** is only the Stranger heart yellow, or every heart?

New on 2026-11-18:
- **#156:** `make bench` is broken. `frames.gd` is stale, and the fixture save is out of date.
- **#157:** hit effects and footstep sounds should use `CoverMap.is_snowed` too.

## Kept branches and files

- **Branches:**
  - `questions-pictures`: 21 picture commits for the questions;
  - `w-final`, `w2` and `w3`: one "temp" commit each. The user knows; don't delete them without
    asking.
- **Untracked in the main checkout:** `TO-TEST.md` (hand tests), `second-opinions.md`,
  `.deploy_key*`.
- **Big outputs go in `build/`, not /tmp** (see [[big-files-in-build]] in the memory notes).
  `build/session-scratch/` holds the last session's scratch pictures.
