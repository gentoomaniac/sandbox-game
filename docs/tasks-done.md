

## 213. Only the music plays while the pause menu is open

- [x] Done

Done: 2026-11-13. AudioService has a Game bus under Master that Effects and Ambience (and the
muffled OutsideEffects) send to; while the tree is paused it fades to silence over `[paused]
fade_seconds` (0.3, data/ambience.cfg) and back, in dB, so loops and positional sounds keep their
place and return without a click. Music and UI go straight to Master and keep playing. Windows that
pause the game: the pause menu with its pages, the chat and choice dialogs (all muted the same way);
crafting, chests, bag, character and console keep their sound. The audio page plays a UI click at a
moved slider's level for Effects, Ambience and Master, at most every 0.15 s with one at the final
level.

The user, 2026-11-11: "All sound should stop while being in the menu, except the music"
- While the pause menu (PauseMenu, with all its settings pages) is open, every game sound goes
  quiet: ambience, weather, outside effects, footsteps, animals, the fire loops, the bell, tool
  sounds already playing. The Music bus (task 184) keeps playing. The menu's own UI sounds (if
  any) still play, and the audio settings page still lets the player hear a volume change (a test
  sound on the changed bus, or say why not).
- Pause or mute the game buses (AudioService: Master's children except Music and a UI bus), or
  pause the players, whichever resumes cleanly: closing the menu brings everything back where it
  was (loops continue, positional sounds resume), with a short fade both ways so it doesn't click.
  Other windows (crafting, chest, character, chat, console) keep the sound as today, unless the
  game pauses for them too (then the same rule).
- Tests: buses silent with the menu open and the music not, sounds back after closing; README line.
