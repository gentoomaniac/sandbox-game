# Saving

When and where the game saves.

The game saves when you sleep, pass out and quit, and by itself every 10 minutes of play (Settings →
Game → Autosave every, 10 to 60 minutes in steps of 10; time in the pause menu or a chat does not
count, and a save waits for a fade or an open window to end). The save is written in the background,
so the game does not stop: "Saving..." and then "Saved" show at the top left, a failed save in red.
Quitting waits for a save that is running. If the save before quitting fails (disk full, no
permission), the game does not quit: it says so and asks whether to try again, keep playing, or quit
anyway, which loses the progress since the last save and says so. The last good save is never
replaced by a failed one.

A save is checked before the game is built from it. One that is damaged (a negative count, a missing
field, a map that is not there...) is not loaded: the game says what is wrong and where, moves the
file to a dated backup such as `world.2026-11-09_21-45-03.json.bak` and starts a new world. A save
that is whole but holds things the game no longer has (an item or object that was removed) asks you:
load it anyway, leaving those things out (playing on may run into problems; the file only changes
when the game next saves, and a copy of the old save is kept as a dated backup of that kind first),
or cancel, which closes the game without touching the file.

Saves go to `user://saves/world.json` and settings to `user://settings.cfg`. To start a fresh world,
run `godot --path . -- --new-game`.
