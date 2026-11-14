# Tasks

Since 2026-11-14 the tasks are GitHub issues (the user): the
[project board](https://github.com/users/gentoomaniac/projects/2) holds the order and the state, the
[issues](https://github.com/gentoomaniac/sandbox-game/issues) hold the specs. The user gave the go for the queue
on 2026-11-14: one task of the Parallel lane and one of the Chain lane at a time.

- **Board columns (Status):** Needs answer (questions for the user), Backlog (ideas for later),
  Queue (in order, worked without asking), In progress, In review (reviewed, waiting for the
  user's verdict or the merge), To test (merged, the user tries it by hand), Done.
- **Lane:** Parallel (no dependencies, runs alongside), Chain (one after another), Later.
- **Dependencies** are GitHub's "blocked by" links; big tasks get sub-issues for their steps.
- **Milestones:** "M2: A first season without the console" and "Prototype polish".
- **Labels:** the area (villagers, farming, crafting, ui, art, music, sound, world, saving,
  economy, tech-debt), plus `plan-first`, `needs-verdict` (art, sound and music the user judges),
  `question`, `idea` and `hand-test`.
- **Numbers:** the tasks up to 240 keep their old number in the issue title ("231: ..."); code,
  design docs and [docs/tasks-done.md](docs/tasks-done.md) refer to those. New tasks are named
  by their issue number.
- **Talking:** the user and the coordinator talk in the chat, not on the issues (the user,
  2026-11-14). The board shows the state, and the coordinator keeps it current. New issues and
  comments are watched, as outside issues may come in.
- **When a task is merged:** the coordinator moves its card to To test and adds what to try by
  hand to the issue as a checklist. The user says in the chat what works; the coordinator ticks
  it and closes the issue, or makes an issue of what doesn't work. The tasks done before
  2026-11-14 are in [docs/tasks-done.md](docs/tasks-done.md); the open hand tests from then are
  in one issue labelled `hand-test`.
- **New tasks** need the user's yes and go to the end of the queue unless the user names a place.

Rules for every task:

- Use only make targets for build, run, test and lint. A new multi-step command gets a new
  make target.
- Keep game state (world, tiles, buildings, crops, time) in plain GDScript classes with no
  rendering or input code. Scenes only read the state and send actions to it.
- State logic gets GUT tests (`make test`). Rendering and input are checked by hand with
  `make run`.
- `make lint` passes.
- Visuals come from the art generator (task 5 on). Until a task adds art for something,
  use simple placeholder shapes in palette colours.
