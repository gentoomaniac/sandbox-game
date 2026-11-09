class_name ScrollingList
extends ScrollContainer
## The growing part of a panel (its rows of recipes, items, settings): as tall as its content
## while the whole panel fits the window, and no taller than what the window leaves, so the
## panel never outgrows it; past that the list scrolls (wheel, bar, and focus moving to a row)
## while the titles and buttons round it stay in place. The window is the one at the current UI
## scale, so a larger UI gives the list less room, and the list follows resizes of the window.

## Room left empty above and below the panel, in UI units.
const MARGIN := 12
## The list is never squeezed below this, however small the window is: a window tinier than the
## panel's other parts loses the panel's edge before the list loses its rows.
const MIN_HEIGHT := 48

## The panel the list sits in; what it holds besides the list is what the list must leave room for.
var _frame: Control
var _content: Control


func _init(frame: Control, content: Control) -> void:
	_frame = frame
	_content = content
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	follow_focus = true
	focus_mode = Control.FOCUS_NONE
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(content)
	content.minimum_size_changed.connect(fit)
	# The rest of the panel changes too (a note, a label), and a page of a menu only counts
	# once it is shown.
	frame.minimum_size_changed.connect(fit)


func _enter_tree() -> void:
	get_viewport().size_changed.connect(fit)


func _exit_tree() -> void:
	get_viewport().size_changed.disconnect(fit)


## The height a list of `content_height` gets in a window of `window_height` when the rest of
## its panel is `chrome_height` tall.
static func height_for(content_height: float, chrome_height: float, window_height: float) -> float:
	var room := window_height - chrome_height - 2 * MARGIN
	return minf(content_height, maxf(room, MIN_HEIGHT))


## Sizes the list again. Call it when the panel opens, as the window it fits is not known to
## change then; anything else that changes the panel or the window is seen by the list itself.
func fit() -> void:
	if not is_visible_in_tree():
		return
	# What the panel is without the list, as the list's own height is part of the panel's.
	var chrome_height := _frame.get_combined_minimum_size().y - get_combined_minimum_size().y
	var content_size := _content.get_combined_minimum_size()
	var height := height_for(
		content_size.y, chrome_height, get_viewport().get_visible_rect().size.y
	)
	var is_scrolling := height < content_size.y
	# The bar takes its width from the list, which would squeeze the rows.
	var bar_width := get_v_scroll_bar().get_combined_minimum_size().x if is_scrolling else 0.0
	var size_wanted := Vector2(content_size.x + bar_width, height)
	if size_wanted != custom_minimum_size:
		custom_minimum_size = size_wanted
