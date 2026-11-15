extends EnergyCase
## Moving the world map: it pans with a drag, zooms with the wheel about the pointer, and a drag is
## not a click.

var _screen: MapScreen
var _view: MapView
var _clicks: Array[Vector2i] = []


func before_each() -> void:
	super.before_each()
	_screen = MapScreen.new()
	add_child_autofree(_screen)
	_screen.show_state(_state)
	_screen.open()
	await get_tree().process_frame
	_view = _screen._view
	_clicks.clear()
	_view.tile_clicked.connect(func(tile: Vector2i, _at: Vector2) -> void: _clicks.append(tile))


func after_each() -> void:
	_screen.close()


func _mouse(is_pressed: bool, at: Vector2, button := MOUSE_BUTTON_LEFT) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.pressed = is_pressed
	event.position = at
	_view._gui_input(event)


func _drag(from: Vector2, to: Vector2) -> void:
	_mouse(true, from)
	var motion := InputEventMouseMotion.new()
	motion.position = to
	motion.relative = to - from
	_view._gui_input(motion)
	_mouse(false, to)


func test_the_map_opens_on_the_player() -> void:
	assert_eq(_view.tile_at(_view.size / 2.0), _state.player.tile())


func test_dragging_moves_the_map_with_the_pointer() -> void:
	var tile_under := _view.tile_at(_view.size / 2.0)

	_drag(_view.size / 2.0, _view.size / 2.0 + Vector2(_view.tile_pixels() * 10.0, 0))

	assert_eq(_view.tile_at(_view.size / 2.0), tile_under - Vector2i(10, 0))
	assert_true(_clicks.is_empty(), "a drag is no click")


func test_a_press_that_hardly_moves_is_a_click() -> void:
	var at := _view.size / 2.0 + Vector2(40, 30)

	_drag(at, at + Vector2(2, 0))

	assert_eq(_clicks, [_view.tile_at(at + Vector2(2, 0))] as Array[Vector2i])


func test_the_wheel_zooms_about_the_pointer() -> void:
	var pointer := _view.size / 2.0 + Vector2(100, 60)
	var tile_under := _view.tile_at(pointer)
	var before := _view.tile_pixels()

	_mouse(true, pointer, MOUSE_BUTTON_WHEEL_UP)

	assert_gt(_view.tile_pixels(), before)
	assert_eq(_view.tile_at(pointer), tile_under, "the tile under the pointer stays")


func test_the_zoom_stays_within_its_limits() -> void:
	for turn in 60:
		_mouse(true, _view.size / 2.0, MOUSE_BUTTON_WHEEL_UP)
	assert_eq(_view.tile_pixels(), MapView.MAX_SCALE)
	for turn in 120:
		_mouse(true, _view.size / 2.0, MOUSE_BUTTON_WHEEL_DOWN)
	assert_eq(_view.tile_pixels(), MapView.MIN_SCALE)


func test_the_chunks_in_view_are_in_the_world_and_the_nearest_come_first() -> void:
	var chunks := _view.visible_chunks()

	assert_false(chunks.is_empty())
	assert_eq(chunks[0], Chunk.world_to_chunk(_state.player.tile()))
	assert_true(chunks.all(World.is_chunk_in_bounds))


func test_a_name_that_would_cover_another_is_moved_below_it() -> void:
	var first := Rect2(Vector2(10, 10), Vector2(80, MapView.LABEL_SIZE))
	var second := Rect2(Vector2(30, 12), Vector2(60, MapView.LABEL_SIZE))
	var third := Rect2(Vector2(20, 14), Vector2(70, MapView.LABEL_SIZE))

	var placed: Array[Rect2] = [first]
	var moved := MapView.free_spot(second, placed)
	placed.append(moved)
	var moved_again := MapView.free_spot(third, placed)

	assert_false(moved.intersects(first))
	assert_false(moved_again.intersects(first))
	assert_false(moved_again.intersects(moved))
	assert_eq(MapView.free_spot(Rect2(Vector2(200, 10), Vector2(50, 11)), placed).position.y, 10.0)
