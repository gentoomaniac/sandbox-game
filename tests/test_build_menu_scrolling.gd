extends GutTest
## The build menu's row of buildings in a window narrower than the row: it scrolls sideways and
## keeps the chosen building in view.

var _state: GameState
var _builder: Builder
var _menu: BuildMenu
var _window: SubViewport


func before_each() -> void:
	_state = GameState.new_game(1)
	_builder = Builder.new(_state)
	_builder.select_hammer()


## A menu in a window of this width.
func _open_menu_in_window_of(width: int) -> void:
	_window = SubViewport.new()
	_window.size = Vector2i(width, 180)
	add_child_autofree(_window)
	_menu = BuildMenu.new()
	_window.add_child(_menu)
	_menu.bind(_builder, _state.player.inventory)
	await wait_process_frames(3)


func test_a_row_that_fits_the_window_has_no_bar() -> void:
	await _open_menu_in_window_of(2000)
	assert_false(_menu._row_scroll.is_scrolling())
	assert_eq(_menu._row_scroll.size.x, _menu._row.get_combined_minimum_size().x)


func test_a_row_wider_than_the_window_scrolls_and_stays_inside_it() -> void:
	await _open_menu_in_window_of(320)
	var scroll := _menu._row_scroll
	assert_true(scroll.is_scrolling())
	assert_lte(scroll.size.x, float(320 - 2 * ScrollingList.MARGIN))
	assert_gte(scroll.global_position.x, 0.0)


func test_the_chosen_building_is_kept_in_view_also_when_the_choice_wraps_round() -> void:
	await _open_menu_in_window_of(320)
	var last: StringName = BuildingTypes.ids()[-1]
	for building in [last, BuildingTypes.ids()[0], last]:
		_builder.choose(building)
		await wait_process_frames(3)
		var cell: Control = _menu._cells[building][&""]
		assert_true(
			_menu._row_scroll.get_global_rect().encloses(cell.get_global_rect()),
			"%s is in view" % building
		)


## Counts the wheel events that get past the menu to the game, as Main's hotbar wheel gets them.
class WheelProbe:
	extends Node
	var wheels := 0

	func _unhandled_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			wheels += 1


func _wheel_at(position: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = position
	_window.push_input(motion)
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
	wheel.pressed = true
	wheel.position = position
	_window.push_input(wheel)


func test_the_wheel_over_the_row_reaches_the_game_and_does_not_scroll_it() -> void:
	await _open_menu_in_window_of(320)
	var probe := WheelProbe.new()
	_window.add_child(probe)
	var scroll := _menu._row_scroll
	var before := scroll.scroll_horizontal
	var cell: Control = _menu._cells[BuildingTypes.ids()[0]][&""]
	_wheel_at(cell.get_global_rect().get_center())
	_wheel_at(scroll._bar.get_global_rect().get_center())
	_wheel_at(scroll.get_global_rect().position + Vector2(1, 1))
	assert_eq(probe.wheels, 3, "over a cell, over the bar and over the row's edge")
	assert_eq(scroll.scroll_horizontal, before)


func test_dragging_the_bar_scrolls_the_row_and_it_stays_there() -> void:
	await _open_menu_in_window_of(320)
	var scroll := _menu._row_scroll
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = Vector2(2, 2)
	scroll._on_bar_input(press)
	var drag := InputEventMouseMotion.new()
	drag.position = Vector2(60, 2)
	scroll._on_bar_input(drag)
	var dragged_to := scroll.scroll_horizontal
	assert_gt(dragged_to, 0.0)
	await wait_process_frames(3)
	assert_eq(scroll.scroll_horizontal, dragged_to, "the choice does not pull the row back")


func test_a_later_choice_is_brought_back_into_view_after_a_drag() -> void:
	await _open_menu_in_window_of(320)
	var scroll := _menu._row_scroll
	var ids := BuildingTypes.ids()
	_builder.choose(ids[-1])
	await wait_process_frames(3)
	scroll.scroll_horizontal = 0.0
	await wait_process_frames(3)
	assert_eq(scroll.scroll_horizontal, 0.0, "the drag stays")
	_builder.choose(ids[-2])
	await wait_process_frames(3)
	var cell: Control = _menu._cells[ids[-2]][&""]
	assert_true(scroll.get_global_rect().encloses(cell.get_global_rect()))
