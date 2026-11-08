# Saving (first version)

- Save format: seed + world edits (terrain, objects and the wear of desire paths) + buildings with their interiors +
  player state (position, current map, home, appearance, inventory) + clock. One JSON
  file per world under `user://saves/`.
- **Autosave when the player sleeps, passes out and when the game quits.** On start, the
  game loads the save if there is one, otherwise it starts a new game (`--new-game` forces
  one).
- **Upgrades kept for ten steps** (the user, 2026-11-08): the game is in
  development, so a save of version `VERSION - 10` to `VERSION` is upgraded step by step on
  load (13 to 23 today); an older one is refused like any unreadable save (renamed `.bak`,
  a new game). When `VERSION` goes up, the oldest step, its constants, helpers and tests go,
  in a commit of its own titled `Save: drop the upgrade from version <N> (oldest read: <N+1>)`.
  To rescue an older save, find that commit with `git log --grep '^Save: drop'`, check out
  its parent (which still upgrades it), load and save the game there, then move on.
- No save menu or multiple slots yet; revisit when there is a main menu.
