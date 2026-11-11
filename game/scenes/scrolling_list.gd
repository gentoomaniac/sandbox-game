class_name ScrollingList
extends ScrollContainer
## The growing part of a panel (its rows of recipes, items, settings): as tall as its content
## while the whole panel fits the window, and no taller than what the window leaves, so the
## panel never outgrows it; past that the list scrolls (wheel, bar, and focus moving to a row)
## while the titles and buttons round it stay in place. The window is the one at the current UI
## scale, so a larger UI gives the list less room, and the list follows resizes of the window.
## A list can also have a fixed height (a log), and can keep the view at the bottom while its
## content grows, unless the player scrolled up.

## Room left empty above and below the panel, in UI units.
const MARGIN := 12
## The list is never squeezed below this, however small the window is: a window tinier than the
## panel's other parts loses the panel's edge before the list loses its rows.
const MIN_HEIGHT := 48

## Not zero: the list is this tall, whatever its content and the window.
var fixed_height := 0.0
## Whether the view stays at the bottom as the content grows. It lets go when the player
## scrolls up and takes hold again when they are back at the bottom.
var keeps_bottom := false

## The panel the list sits in (its nearest PanelContainer); what it holds besides the list is
## what the list must leave room for. Null for a list outside any panel, which has the window to
## itself.
var _frame: PanelContainer
var _content: Control
var _is_at_bottom := true


func _init(content: Control) -> void:
	_content = content
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	follow_focus = true
	focus_mode = Control.FOCUS_NONE
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(content)
	content.minimum_size_changed.connect(fit)
	var bar := get_v_scroll_bar()
	bar.changed.connect(_on_bar_range_changed)
	bar.value_changed.connect(_on_bar_value_changed)


func _enter_tree() -> void:
	var ancestor := get_parent()
	while ancestor != null and not ancestor is PanelContainer:
		ancestor = ancestor.get_parent()
	_frame = ancestor
	# No fit() here: a panel entering the tree is sized by its own minimum size changing, or by
	# the screen's explicit fit() when it opens.
	if _frame != null:
		# The rest of the panel changes too (a note, a label), and a page of a menu only counts
		# once it is shown.
		_frame.minimum_size_changed.connect(fit)
	get_viewport().size_changed.connect(fit)


func _exit_tree() -> void:
	if _frame != null:
		_frame.minimum_size_changed.disconnect(fit)
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
	# What the panel is without the list, as the list's own height is part of the panel's. It
	# assumes the list is in the panel's tallest column; in a shorter one the rest is overstated.
	var chrome_height := 0.0
	if _frame != null:
		chrome_height = _frame.get_combined_minimum_size().y - get_combined_minimum_size().y
	var content_size := _content.get_combined_minimum_size()
	var height := fixed_height
	if height == 0.0:
		height = height_for(content_size.y, chrome_height, get_viewport().get_visible_rect().size.y)
	var is_scrolling := height < content_size.y
	# The bar takes its width from the list, which would squeeze the rows.
	var bar_width := get_v_scroll_bar().get_combined_minimum_size().x if is_scrolling else 0.0
	var size_wanted := Vector2(content_size.x + bar_width, height)
	if size_wanted != custom_minimum_size:
		custom_minimum_size = size_wanted


## Scrolls by whole pages: -1 up, 1 down.
func scroll_pages(pages: int) -> void:
	scroll_vertical += pages * int(size.y)


func scroll_to_bottom() -> void:
	_is_at_bottom = true
	scroll_vertical = int(get_v_scroll_bar().max_value)


func _on_bar_value_changed(value: float) -> void:
	var bar := get_v_scroll_bar()
	_is_at_bottom = value >= bar.max_value - bar.page


## The bar's range changes after the content did, which is when the view can follow it.
func _on_bar_range_changed() -> void:
	if keeps_bottom and _is_at_bottom:
		scroll_to_bottom.call_deferred()


## The sideways sibling of the list, for a row that outgrows the window's width (the build menu's
## row of buildings): as wide as its content until the window, at the current UI scale and less
## `MARGIN` on each side, has no room; past that it scrolls by dragging its bar, and
## `show_in_view` brings a control into view. It has no wheel: a ScrollContainer and its bar take
## every wheel event over them, and over the build menu the wheel keeps turning the hotbar, so the
## row is its own small control. Its owner calls `fit()` when the content or the window changes,
## and places it.
class Row:
	extends Control

	## The row is never squeezed below this, however narrow the window is.
	const MIN_WIDTH := 96
	const BAR_HEIGHT := 8
	const MIN_GRABBER_WIDTH := 16

	## How far the content is scrolled, in UI units.
	var scroll_horizontal := 0.0:
		set(value):
			scroll_horizontal = clampf(value, 0.0, _max_scroll())
			_layout()

	var _content: Control
	var _bar := Control.new()
	var _is_dragging := false
	## Where in the grabber the mouse took hold of it.
	var _grab_x := 0.0

	func _init(content: Control) -> void:
		_content = content
		clip_contents = true
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(content)
		_bar.draw.connect(_draw_bar)
		_bar.gui_input.connect(_on_bar_input)
		add_child(_bar)
		resized.connect(_clamp_and_layout)

	## The width a row of `content_width` gets in a window of `window_width`.
	static func width_for(content_width: float, window_width: float) -> float:
		return minf(content_width, maxf(window_width - 2 * ScrollingList.MARGIN, MIN_WIDTH))

	func is_scrolling() -> bool:
		return _content.get_combined_minimum_size().x > size.x

	func fit() -> void:
		var content_size := _content.get_combined_minimum_size()
		var width := width_for(content_size.x, get_viewport().get_visible_rect().size.x)
		# The bar sits under the content, so the row is taller by its height.
		var bar_height := BAR_HEIGHT if width < content_size.x else 0
		custom_minimum_size = Vector2(width, content_size.y + bar_height)
		_clamp_and_layout()

	func show_in_view(control: Control) -> void:
		var left := control.global_position.x - _content.global_position.x
		var right := left + control.size.x
		if left < scroll_horizontal:
			scroll_horizontal = left
		elif right > scroll_horizontal + size.x:
			scroll_horizontal = right - size.x

	func _max_scroll() -> float:
		return maxf(_content.get_combined_minimum_size().x - size.x, 0.0)

	## A wider window leaves less to scroll: the setter clamps, and lays out.
	func _clamp_and_layout() -> void:
		scroll_horizontal = scroll_horizontal

	func _layout() -> void:
		_content.size = _content.get_combined_minimum_size()
		_content.position = Vector2(-scroll_horizontal, 0)
		_bar.visible = is_scrolling()
		_bar.position = Vector2(0, size.y - BAR_HEIGHT)
		_bar.size = Vector2(size.x, BAR_HEIGHT)
		_bar.queue_redraw()

	func _grabber() -> Rect2:
		var content_width := _content.get_combined_minimum_size().x
		var width := maxf(size.x * size.x / content_width, MIN_GRABBER_WIDTH)
		var travel := size.x - width
		var x := travel * scroll_horizontal / _max_scroll() if _max_scroll() > 0.0 else 0.0
		return Rect2(x, 0, width, BAR_HEIGHT)

	func _draw_bar() -> void:
		_bar.draw_style_box(
			_bar.get_theme_stylebox("scroll", "HScrollBar"), Rect2(Vector2.ZERO, _bar.size)
		)
		var look := "grabber_pressed" if _is_dragging else "grabber"
		_bar.draw_style_box(_bar.get_theme_stylebox(look, "HScrollBar"), _grabber())

	## Only the left button drags; the wheel is not taken, so it reaches the game.
	func _on_bar_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			_is_dragging = event.pressed
			if event.pressed:
				var grabber := _grabber()
				_grab_x = event.position.x - grabber.position.x
				if not grabber.has_point(event.position):
					_grab_x = grabber.size.x / 2
					_drag_to(event.position.x)
			_bar.queue_redraw()
			_bar.accept_event()
		elif event is InputEventMouseMotion and _is_dragging:
			_drag_to(event.position.x)
			_bar.accept_event()

	func _drag_to(mouse_x: float) -> void:
		var travel := size.x - _grabber().size.x
		if travel > 0.0:
			scroll_horizontal = (mouse_x - _grab_x) / travel * _max_scroll()
