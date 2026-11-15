# Saving

When and where the game saves, and what happens if a save goes wrong.

## When it saves

- When you sleep, when you pass out and when you quit.
- By itself every 10 minutes of play. Set 10 to 60 minutes in steps of 10 under Settings, Game,
  Autosave every.
- Time in the pause menu or a chat does not count. A save waits for a fade or an open window to
  end.
- F9 saves at once; F8 loads the newest save (see [controls](controls.md)).
- It is written in the background, so the game does not stop. "Saving..." and then "Saved" show
  at the top left; a failed save shows in red.
- Every save is a new file, and the newest 10 are kept: when the 11th is written, the oldest goes.
  A failed save changes none of them.
- Each save notes the game's date and time, the real date and time, and what made it (autosave,
  quick save, sleep, save and quit).

## Quitting

- Quitting waits for a save that is running.
- If the save before quitting fails (disk full, no permission), the game does not quit. It asks
  whether to try again, keep playing, or quit anyway, which loses the progress since the last
  save.

## A damaged save

- The game checks a save before building the world from it.
- A damaged one (a negative count, a missing field, a map that is not there) is not loaded. The
  game says what is wrong and where, moves the file to a dated backup such as
  `world.2026-11-09_21-45-03.json.bak`, and loads the save before it, or starts a new world if
  there is none. Backups are not among the 10 saves and are never deleted.
- A whole save that holds things the game no longer has (a removed item or object) asks you:
  - Load it anyway, leaving those things out. Playing on may run into problems. The file changes
    only when the game next saves, and a dated backup of the old save is kept first.
  - Or cancel: the game closes without touching the file.

## Where

- Saves go to `user://saves/` as `world.000001.json`, `world.000002.json` and so on, each with a
  small `.info` file beside it. A `world.json` from before the game kept ten saves is its oldest
  save. Settings go to `user://settings.cfg`. Both are in Godot's user folder.
- To start a fresh world, run `godot --path . -- --new-game`.
