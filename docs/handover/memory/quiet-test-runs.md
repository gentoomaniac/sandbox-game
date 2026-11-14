---
name: quiet-test-runs
description: "sandbox-game: game test runs must be muted, not steal focus, and never use the real save (copies are allowed)"
metadata:
  node_type: memory
  type: feedback
  originSessionId: 153327b6-9158-4cac-89d7-3a6186daf9e8
  modified: 2026-11-05T21:50:11.191Z
---

Game runs for screenshots and checks must stay out of the user's way: no sound unless the run tests sound, no focus or mouse stealing, and never the real save.

**Why:** on 2026-11-05 the user asked for "a flag for disabling sound … when you don't need sound tests" and to "prevent your test instances to steal my mouse focus". The user plays on KDE Plasma (Wayland) while agents run the game.

**How to apply:** use `make screenshot` (it passes `--mute --background`, the native `--display-driver wayland`, and `--save-path=build/screenshot.save`). Direct godot runs need `--display-driver wayland` before `--path`, and `--mute --background --new-game --save-path=<scratch> --settings-path=<scratch>` after `--`. Drop `--mute` only for sound checks. Put this in every worker brief. Related: [[readme-updated]].

On 2026-11-06 the user allowed testing with a **copy** of their save. Copy `~/.local/share/godot/app_userdata/Sandbox Game/saves/world.json` into the worktree's build/ (or the scratchpad), then run with `KEEP_SAVE=1 ARGS="--save-path=<the copy>"` or `--save-path=<the copy>` without `--new-game`. Never open, load or write the original itself.

On 2026-11-10 a worker (task 169) overwrote the real save by running one GUT file by hand with a **relative** `XDG_DATA_HOME=build/user-data`: Godot ignores relative XDG paths and falls back to the real user folder, and `test_sleeping_in_bed.gd` saved over world.json. Briefs must say: run tests only via the make targets, or with an **absolute** XDG_DATA_HOME/XDG_CONFIG_HOME inside the worktree.

**Use only half the cores** (the user, 2026-11-11: "I need some CPU myself", then two more cores, then "cut it down to half the cores i have, i still have stutters in a video call"): every test, make, godot or art run by me or a worker is prefixed with `taskset -c 0-10 nice -n 19` (22 cores; cores 11-21 stay free, lowest priority). Put it in every brief; the scratchpad mergecheck.sh pins itself. Runs already going can be moved with `taskset -a -cp 0-10 <pid>` and `renice -n 19 -p <pid>`.
