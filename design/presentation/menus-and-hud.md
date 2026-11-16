# Menus and settings

Decided 2026-11-05.

- **Escape opens the pause menu** (in build mode it first leaves build mode). The game
  pauses while it is open: Resume, Settings, Save and quit. A title screen comes later.
- **Settings:**
  - **Controls:** every game action with its keys. Click a binding, then press a key or
    mouse button to change it. Each action has up to two bindings. A key already used by
    another action moves to the new one, and the menu says so. "Reset to defaults" restores
    all keys. A binding may be a key with Shift (crafting's default is Shift+C, task 191); a key
    pressed to rebind never takes the Shift held with it.
  - **Display:** fullscreen or windowed, and the art: new (drawn at 32 px per tile) or classic
    (the 16 px art doubled, for the groups redrawn since; the rest is the same in both). F7
    switches the art on the fly (task 117, the user's wish of 2026-11-08).
  - **Game:** UI scale (a slider from 0.5× to 2×, the UI only, not the world), the
    energy drain (Low, Normal, High), the day length variation (0–100 %) and "Autosave every"
    (10 to 60 minutes of play in steps of 10, default 10; task 145) and the frame rate limit
    (10 to 240 in steps of 10, default 60, and a last stop "No limit" = vsync only; task 216) and the
    action hint, on by default (issue 3, task 233): a line over the hotbar naming what E and Use
    will do on the target ("E: Open chest", "Use: Harvest"), asked from the rules that do it
    (`Interaction.choice_at`, `ToolUse.use_at`), so it never differs; quiet with nothing to do.
  - **Audio:** Master, Effects and Ambience volume sliders, and "Sound in background"
    (off: the game is silent while its window is not focused).
  - Two keys of the Controls page work in play: **F9** quick save, **F8** quick load (task 145,
    see [saving](../tech/saving.md)); neither asks or shows a dialog, the notifications tell.
  - Settings are saved in `user://settings.cfg`, separate from the save game.
  - Gamepads later.
- **Item icons** (task 115): drawn at 32 px like the world and shown at half size in the
  UI's 20 px slots, 16 UI pixels, so an icon's pixel is as big as a world pixel at the widest
  zoom; the classic 16 px icons fill the same 16 UI pixels. Slots of 36 UI pixels for the icons
  at full size were tried and turned down: the hotbar took over a third of the screen's width.
  A shader keeps the icon's pixels square at 1.5 window pixels each (1080p).
- **The bag** (task 190, 2026-11-11): a bag icon beside the hotbar, set a little apart from it
  (the same icon in both arts); clicking it or pressing B opens the bag (the backpack
  with its weight and a trash can), which is docked at the bottom right of the window above the
  hotbar. A workbench icon beside it opens hand crafting, as Shift+C does (issue 3, task 233). Tab is
  unbound; the hammer has no key (it is selected on the hotbar).
- **The notice board** (#12): E on a board opens a small window, "Notice board", with the rough line
  of each quest posted and not yet taken and whom to see, or "Nothing new on the board."; E, Escape or
  the close button closes it, and the game stands still meanwhile. A bobbing "!" hangs over each board
  while a quest is posted that the player has not taken. The action hint says "Read the notice board".
  See [../villagers/quests.md](../villagers/quests.md).
- **The character window** (task 191, 2026-11-12): C opens a window of its own with the figure, the
  equipment slots round it (no trash can: that is the bag's) a Skills tab (K opens it there) and a Quests tab (J, #12: the quests taken, oldest first, each with who
  gave it, what it asks, how far the player is and the days left, the reward in a tooltip; "No open
  quests." when there are none; read-only, handing in is done at the villager). It
  is docked in the middle of the window (the user, 2026-11-13: it fits beside the bag) and open beside the bag (task 215, 2026-11-13, the usual MMO
  layout: each opens and closes on its own key or button, both can be open at once, Escape closes
  both, the world is not dimmed and you keep playing: walking, the hotbar keys and wheel and clicks
  on the world work with them open; the layout and behaviour only, no art or look is copied; where
  the two do not fit side by side, at a large UI scale, opening one closes the other). A stack is
  dragged from the backpack in the bag onto an equipment slot to wear it, and worn gear back into
  the bag to take it off; the HUD's hotbar is the quick bar of both, so a stack is dragged from it
  onto an equipment slot, and right click wears or takes off in either. Crafting is on Shift+C, and
  on the button beside the bag button.
- **Tooltips** (decided 2026-11-05): hovering a slot in the hotbar, the inventory or the
  equipment shows a small framed panel by the cursor: the item's name, kind and weight
  (each and stack), a one-line description, and what matters for its kind, from the data
  files: food the energy it gives back (and health once food restores any), tools their type and level, seeds what
  they grow and where they are planted, equipment its slot (stats once there are any).
  Settings show a short explanation on hover too.
- **Scrolling** (task 131): a panel never gets taller than the window. The growing part of it
  is a `ScrollingList`, shared by the panels that have one: the crafting screen's recipes, the
  chest's slots in the storage screen, and the rows of the Controls and Language model pages
  (not the character screen or the short pages of the pause menu, which do not grow). The list
  is as tall as its content while the panel fits, otherwise as tall as the window leaves room
  for, less a margin of 12 UI pixels above and below. Past that it scrolls by mouse wheel, by
  dragging the bar (drawn in the UI theme), and by focus moving to a row; titles, tabs and
  buttons stay in place. A window too small for even the rest of the panel still leaves the
  list 48 UI pixels, so the panel then crosses the window's edge. The list fits itself when
  the window is resized or the UI scale changes (both change the viewport's visible rect) and
  when anything in the panel changes size. The build menu's row of buildings is not a window:
  when wider than the window it scrolls sideways in `ScrollingList.Row`, by dragging its bar and
  by following the chosen building, and the mouse wheel over it still turns the hotbar.
- **The trade screen** (#10, `TradeScreen`): what the shopkeeper sells on the left with its price and
  what is left, what she takes on the right with its value, the room she has today and how many the
  player has, a `[-] n [+]` on every row (never above her stock, her room or the bag), and below what
  the player gets and gives in Schilling, one line that says what is right or wrong with the deal
  ("Short by 5 Schilling.", "Your bag is full.", "She keeps the 2 ß over."; the texts are `Shops`'s) and
  `Cover it` (the cheapest of the bag, until the goods are paid), `Trade` (on only when the deal is
  fair) and `Talk` (asks for the chat). It is a `Modal` that pauses the game; E and Escape close
  it. Rows with nothing to trade are grey. Until E on the keeper opens it, the console's `shop`
  does ([console.md](console.md)).
- **Windows** (task 132): every window (crafting, chest, character, chat, the pause menu) is built
  on one base, `Modal`: a dimmed backdrop and a framed panel that stays centred in the window
  whatever its content or the window does. The player can drag a window by its frame to move it
  aside (task 189; it stays on the screen and is centred again when reopened, nothing is saved).
  Buttons, slots, text fields and the rows of a list take their own clicks and never drag; the
  empty area of a list and the gaps between rows do. The pause menu with its settings and the
  confirmation dialogs set `is_movable` off and stay put. Every window has a close button (a small
  cross) in its top right corner. Escape, the button and a left click on the dimmed area outside
  the window do the same (task 196: the pause menu goes back a page first; for a question, its
  safe answer). Only one window is open at a time (opening one closes the other),
  and the game pauses while a window that asks for it is open. HUDs, tooltips and the build menu
  are not windows. How to build one: [docs/ui.md](../../docs/ui.md).
- **UI look:** a pixel font and a framed panel (9-slice) in palette colours, in one shared
  Godot Theme that all UI uses.

## Notifications

Decided 2026-11-09 (task 145). A few short lines at the top left, below the clock and the harvest
note, for what happens beside the player's play: "Saving...", "Saved" and a failed save.
`NotificationHud` is on its own canvas layer, in the UI theme: each line sits on a plate, dim for
news and the palette's ember red for trouble, so it reads over any ground and at every UI scale.
A line fades after two seconds (a failure after six, so it is not missed); one that is kept (a
save under way) stays until the line of the same key replaces it, so "Saving..." turns into
"Saved" in place. At most four lines; the oldest goes first. It keeps running while the game is
paused. No dialogs: a failed timed or quick save is a red line and nothing else.

## Coordinates display

Decided 2026-11-05. The player's tile coordinates in the top right corner (inside a
house: the room's, marked "House"), under the energy and health bars (task 188). Off by default; F3 (rebindable, "Show coordinates")
toggles it. Not saved. Its last line is the frames per second the game draws now (the user,
2026-11-12), to check the frame rate limit in the Game settings.
