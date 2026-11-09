# Saving (first version)

- Save format: seed + world edits (terrain, objects and the wear of desire paths) + buildings with their interiors +
  player state (position, current map, home, appearance, inventory) + clock. One JSON
  file per world under `user://saves/`.
- **Autosave when the player sleeps, passes out and when the game quits.** On start, the
  game loads the save if there is one, otherwise it starts a new game (`--new-game` forces
  one).
- **Saving does not freeze the game** (task 145). A save takes the game's JSON text at once, on
  the main thread (`SaveFile.encode`), and writes it on a worker thread to the temporary file that
  is renamed over the save (`SaveService`). Only one save runs at a time; a second request
  while one runs is skipped (the next timed or quick save follows). The notifications say
  "Saving..." while it runs, then "Saved", or a red line if it failed (a failed save leaves the
  previous one as it was). The saves that must not be lost (sleeping, passing out, save and
  quit, closing the window) wait for a running save and then write at once. Quitting never
  happens mid-write. `SaveService.last_succeeded` has the result of the last save, for the
  question about a failed save on quit (task 140).
- **Upgrades kept for ten steps** (the user, 2026-11-08): the game is in
  development, so a save of version `VERSION - 10` to `VERSION` is upgraded step by step on
  load (13 to 23 today); an older one is refused like any unreadable save (renamed `.bak`,
  a new game). When `VERSION` goes up, the oldest step, its constants, helpers and tests go,
  in a commit of its own titled `Save: drop the upgrade from version <N> (oldest read: <N+1>)`.
  To rescue an older save, find that commit with `git log --grep '^Save: drop'`, check out
  its parent (which still upgrades it), load and save the game there, then move on.
- No save menu or multiple slots yet; revisit when there is a main menu.
