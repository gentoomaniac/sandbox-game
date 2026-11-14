---
name: test-window-title
description: "sandbox-game: every game window an agent or test opens uses --with-working-window-title (title \"Sandbox Game (test)\"); the user's KDE rules match it; make run doesn't set it by default"
metadata:
  node_type: memory
  type: feedback
  originSessionId: 299de3b6-007d-4e3d-9063-66dc22decf99
  modified: 2026-11-10T12:05:21.886Z
---

The user, 2026-11-10: the game has a flag `--with-working-window-title` (task 164) that titles the
window exactly "Sandbox Game (test)". The user's Krohnkite exclude and KWin rule (keep below, own
virtual desktop) match that title. `make screenshot` and other check targets pass it by default;
`make run` does not (the user's own runs keep the normal title).

**Why:** the user runs KDE with Krohnkite; agent/test windows got tiled and took the foreground.
**How to apply:** use the flag for all my and the workers' testing (e.g.
`make run ARGS=--with-working-window-title`); put it in every brief that opens a game window;
never change the title or make `make run` set it by default. Related: [[quiet-test-runs]].
