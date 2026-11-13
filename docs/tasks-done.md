

## 215. Character window: no trash can; the bag can be open beside it to drag gear onto the figure

- [x] Done

Done: 2026-11-13. The character window has no trash can. The bag (B, the bag button) docks at the
bottom right above the bag button and the character window (C, K for skills) in the middle of the
screen; each opens and closes on its own key, Escape closes both, neither pauses the game, and the
player keeps walking, using tools and the hotbar while only these two are open (clicks outside the
panels reach the world; a stack dragged out of the bag onto the world drops; the take-down hold
only counts presses that began on the world; the highlight hides over a panel). Gear drags both
ways between them; the hotbar is shared (the last opened answers). Where the two don't fit side by
side (UI scale 1.75 and 2.0), opening the second closes the first. Other windows stay one at a time
and close both; doors and sleep close them. Main's debug options moved to DebugGameOptions.

The user, 2026-11-12, after task 191: "The character window doesn't need a trash can. Dragging
into an item slot should happen when the bag is open at the same time."
- Remove the trash can from the character window (CharacterScreen); the bag keeps its own.
- The bag (B) and the character window (C) may be open together, side by side without overlapping
  (both stay movable). Dragging a stack from the backpack onto an equipment slot wears it;
  dragging worn gear back into the backpack takes it off. Hotbar drags and right click keep working.
- Today only one Modal is open at a time ("other windows' keys do nothing"): allow this one pair
  (B over the character window opens the bag and C over the bag opens the character window; each
  key closes only its own window).
  Other windows keep the one-at-a-time rule.
- The user, 2026-11-12: "The idea UI wise is like in world of warcraft." So the usual MMO layout:
  the character window docks on the left side of the screen, the bag at the bottom right above the
  bag button; each opens and closes on its own key or button, independently of the other, and both
  can be open at once while you keep playing. Escape closes all open windows at once. No art or
  look is copied from that game, only this layout and behaviour.
- Tests for both windows open, the drags both ways and the keys; screenshots for the user; README
  and docs (docs/ui.md, design/presentation/menus-and-hud.md, design/player/inventory-and-character.md).
