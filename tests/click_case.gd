class_name ClickCase
extends GutTest
## Helpers for tests that click a screen's buttons with real mouse events in a viewport that
## holds the game's other layers too, to find whatever eats clicks over part of a button.

var _window: SubViewport


## A viewport of the game's size with the layers Main puts in the tree besides the screens:
## the HUDs that need no game state, console, chat, tooltip and fade screen. (The clock and
## message labels of the main scene are plain labels, which ignore the mouse.)
func _make_window() -> void:
	_window = SubViewport.new()
	_window.size = Vector2i(640, 360)
	add_child_autofree(_window)
	for layer: Node in [
		HarvestHud.new(),
		CoordinatesHud.new(),
		NpcNameTag.new(),
		ConsoleView.new(),
		ChatScreen.new(),
		TooltipView.new(),
		FadeScreen.new(),
	]:
		_window.add_child(layer)


func _move_mouse(position: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = position
	_window.push_input(motion)


## The part of a control that shows: scrolled-out parts are clipped by the scroll containers
## round it.
func _visible_rect(control: Control) -> Rect2:
	var rect := control.get_global_rect()
	var ancestor := control.get_parent()
	while ancestor != null:
		if ancestor is ScrollContainer:
			rect = rect.intersection(ancestor.get_global_rect())
		ancestor = ancestor.get_parent()
	return rect


## The spots of a rect to click: the centre and just inside each corner.
func _spots(rect: Rect2) -> Array[Vector2]:
	var spots: Array[Vector2] = [rect.get_center()]
	var corners := [rect.position, rect.end]
	corners.append(Vector2(rect.end.x, rect.position.y))
	corners.append(Vector2(rect.position.x, rect.end.y))
	for corner: Vector2 in corners:
		spots.append(corner.move_toward(rect.get_center(), 1.0))
	return spots


## Asserts that the mouse, put on each spot of what shows of `control`, is over `control`
## itself and not over a control that covers it.
func _assert_hit_all_over(control: Control, what: String) -> void:
	var rect := _visible_rect(control)
	if not rect.has_area():
		return
	for spot in _spots(rect):
		_move_mouse(spot)
		assert_eq(_window.gui_get_hovered_control(), control, "%s at %s" % [what, spot])
