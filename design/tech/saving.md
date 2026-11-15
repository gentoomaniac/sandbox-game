# Saving (first version)

- Save format: seed + world edits (terrain, objects, the days of wear of desire paths, the steps
  taken today, how long tilled soil has lain fallow, and the record of the village, if the world was
  built with one: `World.village`, see [../world/wehlsbuell.md](../world/wehlsbuell.md)) + buildings with their interiors (and the
  items lying on their floors) +
  player state (position, current map, home, appearance, inventory) + clock. One JSON
  file per save under `user://saves/`, see the next point.
- **The newest ten saves are kept** (#16, the user, 2026-11-14: "not just one save file but maybe
  ten rising, first in first out"). Every save (autosave, quick save, sleep, quit) writes a new
  file, `world.000001.json`, `world.000002.json`, and so on, written as before (a temporary file,
  flushed, renamed; `SaveFile.store`), and then the files beyond the newest ten go, the oldest
  first (`SaveList.prune`). The count is `[keep] saves` in `data/saves.cfg`. The numbers only go
  up, so the order of the files is the order of the saves. A save that fails to write changes
  nothing: the other saves stay, and so does the oldest. The backups of unusable saves
  (`.bak`, below) are not saves of this list and are never pruned.
- **A header beside each save** (`SaveHeader`, the file `world.000001.json.info`): the game day
  and minute, the real time (seconds since 1970) and what made it (autosave, quick save, sleep,
  save and quit), and the save's version, so that the list is made without parsing ten worlds.
  The header is written before the save and removed again if the save fails, so a save is never
  listed without one. A save without a header (the single `world.json` of the game before this,
  which is the oldest of the list, "an earlier save") gets one made of its own data and file
  time the first time it is listed. A save whose header is missing and can't be made, or is of a
  version the game does not read, is listed as one that can't be loaded (`SaveEntry.problem`).
- **Autosave when the player sleeps, passes out and when the game quits, and on a timer** (task
  145): every `autosave_minutes` of play (Settings → Game, "Autosave every", 10 to 60 in steps of
  10, default 10), counted by `AutosaveTimer` from `Main._process`, so time the game is paused
  for (pause menu, chat) does not count. A save that comes due during a fade, a sleep, a collapse
  or while a window or the console is open waits for the next frame free of them. Any save
  starting restarts the count.
- On start, the game loads the newest save that can be loaded, otherwise it starts a new game
  (`--new-game` forces one). A save that is refused is moved aside and told about, and the one
  before it is tried. `--save-path` names the world's save path (`world.json`); its saves are
  named after it.
- **Quick save and quick load** (task 145): F9 saves now in the background; F8 loads the newest
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
- **The load dialog** (#16, `LoadDialog`): the pause menu's Load button opens it. It lists
  `SaveList.entries` newest first, each row with `SaveHeader.game_text` and `how_text`, as toggle
  buttons of one group, so the mouse and the arrow keys and Enter all pick; the newest save that
  can be loaded is picked and focused when it opens, and a picked row hands the focus on to Load.
  A save that can't be loaded (`SaveEntry.problem`: no header and none can be made, or a version
  this game does not read) is a disabled row that says why. The list holds only what the headers
  say: a file that turns out to be refused when loaded is moved aside like at the start
  (`QuickLoadFlow`, with its note), and is gone from the list the next time it opens. Load closes
  the list and `Main` asks "Load this save?" (`SaveQuestions.is_load_confirmed`; always, as
  unsaved play can't be told from saved; Cancel is the safe button and reopens the list), then
  loads through `QuickLoadFlow.run`, the way F8 does. There is no title menu yet, so the pause
  menu is the only way in. `--load-dialog` opens it for a screenshot.
- **Saving does not freeze the game** (tasks 145, 147, 158). A save takes a snapshot of the game
  at once on the main thread (`SaveFile.snapshot`: the big maps, such as the tilled soil, the
  soil moisture and the piles, are copied as they are, which takes about a fifth of what making
  save data of them does; about 10 ms on the bench save with 30,000 tilled tiles, 10,000 piles
  and 155 villagers, before 55), and a worker thread makes the save data and the JSON text of it
  (`SaveFile.text_of`) and writes it to the temporary file that is renamed over the save
  (`SaveService`). Only one save runs at a time; a second request
  while one runs is skipped (the next timed or quick save follows). The notifications say
  "Saving..." while it runs, then "Saved", or a red line if it failed (a failed save leaves the
  previous one as it was). Sleeping in a bed and passing out save in the background too
  (`SaveService.save_without_stalling`), a frame after the sleep, under the black screen. The saves
  that must not be lost (save and quit, closing the window) wait for a running save and then
  write at once. Quitting never
  happens mid-write. `SaveService.last_succeeded` and `last_error` have the result of the last
  save.
- **A failed save is never quietly given up** (the user, 2026-11-09, task 140). Every step of the
  write is checked (the folder, the open, the store and flush, the rename); a failure removes the
  temporary file, leaves the previous save as it was and says what went wrong (`SaveFile.write_text`
  returns the text). A failed timed or quick save shows the red note. "Save and quit" and closing
  the window go through `SaveBeforeQuit`: after a failed save the game does not quit; a
  `ChoiceDialog` says "The game could not be saved", what went wrong, that the last save is still
  there but that quitting now loses the progress since it, and offers "Try saving again", "Keep
  playing" (the focus, and what Escape does) and "Quit anyway and lose the progress since the last
  save". Only the last one quits.
- **Upgrades kept for ten steps** (the user, 2026-11-08): the game is in
  development, so a save of version `VERSION - 10` to `VERSION` is upgraded step by step on
  load (36 to 46 today); an older one is refused like any unreadable save (renamed `.bak`,
  a new game). When `VERSION` goes up, the oldest step, its constants, helpers and tests go,
  in a commit of its own titled `Save: drop the upgrade from version <N> (oldest read: <N+1>)`.
  To rescue an older save, find that commit with `git log --grep '^Save: drop'`, check out
  its parent (which still upgrades it), load and save the game there, then move on.
- **A save is checked before anything is built from it** (task 140, review R2). After the upgrades,
  `SaveValidator` walks the whole game data once: field types, counts and stack limits of every
  item slot (inventory, chests), the selected hotbar slot, equipment slots, object, building and
  animal data, object state (every entry but a stump's `tree` and a station's `work` is a number),
  the map references (the current and home map must name the world or a building
  that has an inside), station work (a known, slow recipe), the villagers' fields (their topics
  of the village are texts), and the deed log and the villagers' stories (a known deed kind, whole
  numbers, a place, whether it is judged: the stories not judged yet are the queue of the judge, so
  it is saved with them). Each
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
