# Menus and settings

Decided 2026-11-05.

- **Escape opens the pause menu** (in build mode it first leaves build mode). The game
  pauses while it is open: Resume, Settings, Save and quit. A title screen comes later.
- **Settings:**
  - **Controls:** every game action with its keys. Click a binding, then press a key or
    mouse button to change it. Each action has up to two bindings. A key already used by
    another action moves to the new one, and the menu says so. "Reset to defaults" restores
    all keys.
  - **Display:** fullscreen or windowed, and the art: new (drawn at 32 px per tile) or classic
    (the 16 px art doubled, for the groups redrawn since; the rest is the same in both). F7
    switches the art on the fly (task 117, the user's wish of 2026-11-08).
  - **Game:** UI scale (a slider from 0.5× to 2×, the UI only, not the world), the
    energy drain (Low, Normal, High) and the day length variation (0–100 %).
  - **Audio:** Master, Effects and Ambience volume sliders, and "Sound in background"
    (off: the game is silent while its window is not focused).
  - Settings are saved in `user://settings.cfg`, separate from the save game.
  - Gamepads later.
- **Item icons** (task 115): drawn at 32 px like the world and shown at half size in the
  UI's 20 px slots, 16 UI pixels, so an icon's pixel is as big as a world pixel at the widest
  zoom; the classic 16 px icons fill the same 16 UI pixels. Slots of 36 UI pixels for the icons
  at full size were tried and turned down: the hotbar took over a third of the screen's width.
  A shader keeps the icon's pixels square at 1.5 window pixels each (1080p).
- **Tooltips** (decided 2026-11-05): hovering a slot in the hotbar, the inventory or the
  equipment shows a small framed panel by the cursor: the item's name, kind and weight
  (each and stack), a one-line description, and what matters for its kind, from the data
  files: food the energy it gives back (and health once food restores any), tools their type and level, seeds what
  they grow and where they are planted, equipment its slot (stats once there are any).
  Settings show a short explanation on hover too.
- **Scrolling** (task 131): a panel never gets taller than the window. The growing part of it
  (rows of recipes, items, buildings, settings) is a `ScrollingList`, shared by all panels: as
  tall as its content while the panel fits, otherwise as tall as the window (at the current UI
  scale) leaves room for, less a margin of 12 UI pixels above and below. Past that it scrolls by
  mouse wheel, by dragging the bar (drawn in the UI theme), and by focus moving to a row; titles,
  tabs and buttons stay in place. A window too small for even the rest of the panel still
  leaves the list 48 UI pixels, so the panel then crosses the window's edge. It refits on window resizes and UI scale changes.
- **UI look:** a pixel font and a framed panel (9-slice) in palette colours, in one shared
  Godot Theme that all UI uses.

## Coordinates display

Decided 2026-11-05. The player's tile coordinates in the top right corner (inside a
house: the room's, marked "House"). Off by default; F3 (rebindable, "Show coordinates")
toggles it. Not saved.
