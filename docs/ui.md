# Windows and the UI library

How to build a window over the game (crafting, the chest, the character screen, chat, the pause
menu). The base class is `Modal` (`game/scenes/modal.gd`); the class comments there are the
reference, this is the short guide. The look of the panels is in
[design/presentation/menus-and-hud.md](../design/presentation/menus-and-hud.md).

## A new window

A window extends `Modal` and only builds its contents. The base does the rest: the dimmed
backdrop, the themed panel (`_panel`) centred in the window, opening and closing, Escape and
one-at-a-time.

```gdscript
class_name RecipeBook
extends Modal

var _book: Book
var _title := Label.new()
var _rows := VBoxContainer.new()  # the part that grows


func _init() -> void:
	super()
	closes_on_backdrop_click = true
	var column := VBoxContainer.new()
	column.add_child(_title)
	column.add_child(_scrolling(_rows))
	_panel.add_child(column)


## A window that needs arguments has a method of its own that stores them and calls open().
func open_book(book: Book) -> void:
	close()  # it may be open already; this lets _on_close see the old book
	_book = book
	open()


func _on_open() -> void:
	_title.text = _book.title
	# ... fill _rows; the panel is refitted afterwards
```

- `open()`, `close()`, `toggle()` and `is_open()` take no arguments, because GDScript does not
  allow an override with another signature. `open()` does nothing for a window that is open.
  The signals `opened` and `closed` come after the hooks.
- Hooks (all optional): `_on_open()`, `_on_close()`, `_takes_escape()`,
  `_on_backdrop_input(event)`.
- Contents that change size need nothing: the panel refits itself when its minimum size
  changes, when the window is resized and when the UI scale changes (that too is a resize of the
  root). `refit()` forces it; the lists size themselves only while the window is shown.

## The growing part: ScrollingList

`_scrolling(part)` wraps the part of the window that grows (rows of recipes, a chest's slots,
settings) in a `ScrollingList` and returns it, to be added where the part belongs. The list is as
tall as its part while the panel fits the window; past that it is as tall as the window leaves
room for, less `MARGIN` (12 UI pixels above and below), and scrolls by wheel, bar and focus.
Titles, tabs and buttons round it stay put. It assumes the list is in the tallest column of the
panel, as what the panel holds besides the list is what it measures, and it never gets smaller
than `MIN_HEIGHT` (48 UI pixels), so a tiny window crosses the panel's edge rather than leave no
rows. The base puts every list back to the top when the window opens. To swap what is in the
growing part (a chest with other slots), keep the part as a fixed container and swap its children.

The character screen is another window whose methods take arguments: `open_tab(tab)` stores the
tab and calls `open()` (or switches tab when the screen is open), and `toggle_tab(tab)` closes it
when it is open on that tab. Its tab keys (Tab, K) are Main's; it registers no `close_actions`, so
E does nothing while it is open.

## Escape, backdrop clicks, pause, one at a time

- **Escape** is `ui_cancel` (not rebindable) or the rebindable pause key, and closes the window.
  A window that wants it first returns true from `_takes_escape()` (the pause menu goes back a
  page and stays open). A window must stay a child of Main: input reaches children before their
  parent, which is why Escape gets to the window first and is not handled twice.
- **Other keys:** `close_actions` (set in `_init`) lists input actions that close the window at
  once, as Escape does: the crafting screen and the chest register `interact`, so E closes them.
  `_takes_escape()` is asked for Escape and the pause key only, not for these. A key not listed
  does nothing to the window.
- **Backdrop click:** `closes_on_backdrop_click = true` closes on a left click outside the panel.
  A window that uses those clicks itself (the chest lets go of the picked stack) overrides
  `_on_backdrop_input(event)`; it should then set `_panel.mouse_filter` to ignore, so clicks
  on the panel reach it.
- **Pause:** `pauses_game = true` (set in `_init`) pauses the tree while the window is open; the
  window then keeps running (`PROCESS_MODE_ALWAYS`). It unpauses when it closes, or is freed
  while open, whatever else asked for the pause, so once the migration is done only Modals pause
  the tree: the pause menu becomes one, and Main stops pausing for it.
- **One at a time:** opening a window closes the open one, so windows need not know of each
  other. `Modal.is_any_open()` says whether one is open (Main uses it instead of its own
  conditions: then the player neither walks nor acts) and `Modal.close_open()` closes it.
  The open window is one static variable of the base, no registry.

## Theme and palette

`Modal` gives the panel the shared theme (`game/scenes/ui_theme.tres`: pixel font, framed panel,
the scroll bar) and the dimmed backdrop is `UiColors.BACKDROP`. Use the theme's controls and
`UiColors` for colours rather than your own. There are no shared builders for titles or button
rows yet: add one to the base when a second window needs the same.

## Testing a window headless

Put the window in a `SubViewport` of a small size and wait a frame or two, e.g.
`tests/test_modal.gd` and `test_storage_screen.gd`:

```gdscript
var window := SubViewport.new()
window.size = Vector2i(320, 180)
add_child_autofree(window)
window.add_child(my_window)
my_window.open()
await wait_process_frames(2)
assert_lte(panel.size.y, window.size.y)
```

`window.push_input(event)` with an `InputEventAction` for `ui_cancel` presses Escape. Press a
button by emitting its `pressed` signal. Set `get_tree().paused = false` after a test of a
pausing window.

## Not windows

The HUDs (hotbar, harvest notes, coordinates), tooltips and the build menu are not `Modal`s:
they are overlays that stay up while the player plays, take no input away from the game and
need neither a backdrop nor one-at-a-time. The console takes the input like a window, but is a
strip, not a centred panel, and keeps its own code.
