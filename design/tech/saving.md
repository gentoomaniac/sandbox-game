# Saving (first version)

- Save format: seed + world edits (terrain, objects and the wear of desire paths) + buildings with their interiors +
  player state (position, current map, home, appearance, inventory) + clock. One JSON
  file per world under `user://saves/`.
- **Autosave when the player sleeps, passes out and when the game quits, and on a timer** (task
  145): every `autosave_minutes` of play (Settings → Game, "Autosave every", 10 to 60 in steps of
  10, default 10), counted by `AutosaveTimer` from `Main._process`, so time the game is paused
  for (pause menu, chat) does not count. A save that comes due during a fade, a sleep, a collapse
  or while a window or the console is open waits for the next frame free of them. Any save
  starting restarts the count.
- On start, the game loads the save if there is one, otherwise it starts a new game (`--new-game` forces
  one).
- **Quick save and quick load** (task 145): F9 saves now in the background; F8 loads the last
  save file without asking (the user: "quick load generally doesn't ask in games"; only a save
  with content the game no longer has asks, see below), after
  waiting for a save that runs. Both are rebindable actions (`quick_save`, `quick_load`) in the
  controls page. F8 reads the save and starts the game scene again from it (`Main` hands the
  loaded `GameState` to the new scene), so no view, window or paused state is left over; the
  player keys and the settings are read afresh. Of the command line's debug flags only the harmless view ones carry over (the
  paths, sound, zoom, coordinates, art; `StartupOptions.kept_for_quick_load`): the ones that
  change the game or open windows (`--at`, `--time`, `--field`, `--console`, `--inventory`...)
  would otherwise run again over the loaded game. No save file: a note says "No save to load".
  They work with a window open, not in the pause menu or a chat (the game is paused there) nor
  during a fade.
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
- **A save is checked before anything is built from it** (task 140, review R2). After the upgrades,
  `SaveValidator` walks the whole game data once: field types, counts and stack limits of every
  item slot (inventory, chests), the selected hotbar slot, equipment slots, object, building and
  animal data, object state (every entry but a stump's `tree` and a station's `work` is a number),
  the map references (the current and home map must name the world or a building
  that has an inside), station work (a known, slow recipe) and the villagers' fields. Each
  problem has its place, "player inventory slot 4: count -7 is not between 1 and 99". Nothing is
  built from a save with a problem: `SaveFile.load_game` gives a `LoadResult` (no save, refused,
  ready) and the file is not touched; `SaveFile.read` and the game's start move a refused save
  aside (as a dated backup, below) and start a new game. `from_dict` stays strict behind the
  validator (it asserts); assertions are for internal invariants, the validator is the input
  check. A new save field gets its check in the validator in the same commit.
- **Content the game no longer has** (an item, object, tree, recipe or animal id that was
  removed) is not damage: the validator lists it apart (`missing`) and the player decides (the
  user, 2026-11-09). A `ChoiceDialog` at the start says what is missing and offers "Load anyway,
  dropping what is missing" (the game then leaves those things out; the text says plainly that
  playing on may run into problems and that the file only changes when the game next saves, which
  the autosave and the quit save also do) or "Cancel and quit the game", which leaves the file as
  it is. Agreeing first copies the old save to a backup (the dialog names it),
  so nothing is lost when that next save writes the game without the missing things; if the copy
  can't be made the save is not loaded. Nothing is dropped silently. F8 asks the same when the last
  save holds missing content (Cancel keeps the game being played); a save without missing content
  still loads without a question. A damaged save is refused with a `ChoiceDialog` that lists what
  is wrong and says where the file went (the F8 note says so too); the game then starts anew.
  Backups are named with the date and time, `world.2026-11-09_21-45-03.json.bak` (a number is added
  if two land in the same second), so they sort by age and one never replaces another.
