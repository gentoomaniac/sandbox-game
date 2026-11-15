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


func test_the_names_show_for_the_villagers_under_the_pointer_the_nearest_first() -> void:
	var near := _state.npcs.spawn_villager("antje", _state.player.position, _state.world)
	var nearer := _state.npcs.spawn_villager("kerrin", _state.player.position, _state.world)
	near.position = _state.player.position + Vector2(1, 0)
	nearer.position = _state.player.position
	var at := _view._point_of_villager(nearer)

	var under := _view.villagers_at(at + Vector2(1, 0))

	assert_eq(under.size(), 2, "both dots are within reach at this zoom")
	assert_eq(under[0], nearer)
	assert_eq(under[1], near)
	assert_true(
		_view.villagers_at(at + Vector2(200, 200)).is_empty(), "nobody far from the pointer"
	)
	assert_true(_view.villagers_at(MapView.NO_POINTER).is_empty(), "no pointer on the map")
