extends ResourceCase
## The sounds the game makes by itself: steps, tool hits and uses, pickups, the hotbar, panels
## opening and closing. The audio service is real; what it plays is recorded.

var _audio: AudioService
var _sounds: GameSounds
var _player_view: PlayerView
var _build_mode: BuildMode
var _view: WorldView
var _events: Array[StringName] = []
var _is_panel_open := false


func before_each() -> void:
	super.before_each()
	_audio = AudioService.new()
	add_child_autofree(_audio)
	_audio.played.connect(
		func(event: StringName, _position: Variant) -> void: _events.append(event)
	)
	_player_view = PlayerView.new()
	autofree(_player_view)
	_build_mode = BuildMode.new()
	autofree(_build_mode)
	_view = WorldView.new()
	add_child_autofree(_view)
	_sounds = GameSounds.new()
	add_child_autofree(_sounds)
	_sounds.listen(_audio, _state, _view, _player_view, _build_mode)
	_events.clear()


## Holds the item without the sound of selecting its hotbar slot.
func _hold_quietly(item: StringName) -> void:
	_hold(item)
	_events.clear()


func _use_and_sound() -> void:
	var tile := _state.player.facing_tile()
	_sounds.used(_state.use_tile(tile), tile)


func test_a_step_sounds_like_the_ground_under_the_player() -> void:
	_player_view.stepped.emit()
	_world.set_terrain(_state.player.tile(), Tile.Terrain.SOIL)
	_player_view.stepped.emit()
	_world.set_terrain(_state.player.tile(), Tile.Terrain.FLOODPLAIN)
	_player_view.stepped.emit()
	assert_eq(_events, [&"step_grass", &"step_soil", &"step_sand"])


func test_a_walk_makes_two_steps_per_cycle_at_the_pace_of_the_walk() -> void:
	assert_eq(_steps_in_a_second_walking_at(1.0), 6, "one every 0.2 s, the first at once")
	assert_eq(_steps_in_a_second_walking_at(0.5), 3, "at half the pace, half the steps")


func test_hits_chop_and_a_felled_tree_falls_when_it_lands() -> void:
	_make_room()
	_place(WorldObjectTypes.OAK)
	var hits := ceili(5.0 / ItemTypes.tool_power(ItemTypes.AXE))
	_hold_quietly(ItemTypes.AXE)
	for _i in hits:
		_use_and_sound()
	assert_eq(_events, _repeat(&"axe_chop", hits))
	_view.tree_landed.emit(WorldObject.new(WorldObjectTypes.OAK, _tile))
	assert_eq(_events.back(), &"tree_fall")


func test_a_stone_is_hit_and_then_breaks() -> void:
	_place(WorldObjectTypes.STONE)
	_hold_quietly(ItemTypes.PICKAXE)
	var hits := 0
	while _world.object_at(_tile) != null:
		_use_and_sound()
		hits += 1
	assert_eq(_events, _repeat(&"pickaxe_hit", hits - 1) + [&"stone_break"])


func test_a_tool_that_is_too_weak_is_denied() -> void:
	_place(WorldObjectTypes.PINE)
	_hold_quietly(ItemTypes.AXE)
	_use_and_sound()
	assert_eq(_events, [&"denied"])


func test_uses_sound_by_what_they_do() -> void:
	_hold_quietly(ItemTypes.HOE)
	_use_and_sound()
	assert_eq(_events, [&"hoe_till"])
	_events.clear()
	_hold_quietly(ItemTypes.SCYTHE)
	_world.set_terrain(_state.player.facing_tile(), Tile.Terrain.GRASS)
	_use_and_sound()
	assert_eq(_events, [&"scythe_swish"], "also when it mows nothing")


func test_collecting_an_item_pops() -> void:
	_world.drop_items(_tile, {ItemTypes.LOGS: 1})
	_state.player.position = _world.ground_items()[0].position
	_state.collect_ground_items(0.1)
	assert_eq(_events, [&"item_pickup"])


func test_placing_a_building_is_heard() -> void:
	_world.place_building(BuildingTypes.SHACK, _tile + Vector2i(5, 5))
	assert_eq(_events, [&"build_place"])


func test_a_refused_placement_is_denied() -> void:
	_build_mode.placement_refused.emit()
	assert_eq(_events, [&"denied"])


func test_a_new_hotbar_slot_clicks_but_other_changes_do_not() -> void:
	var inventory := _state.player.inventory
	inventory.add(ItemTypes.LOGS, 1)
	assert_eq(_events, [])
	inventory.select(3)
	assert_eq(_events, [&"hotbar_select"])
	inventory.select(3)
	assert_eq(_events, [&"hotbar_select"], "the same slot again is no change")


func test_a_panel_opening_and_closing_is_heard() -> void:
	_sounds.watch_panel(func() -> bool: return _is_panel_open)
	simulate(_sounds, 1, 0.1)
	assert_eq(_events, [])
	_is_panel_open = true
	simulate(_sounds, 2, 0.1)
	_is_panel_open = false
	simulate(_sounds, 2, 0.1)
	assert_eq(_events, [&"ui_open", &"ui_close"])


func test_the_storage_screen_squeaks_open_and_thumps_shut() -> void:
	_sounds.watch_panel(func() -> bool: return _is_panel_open, &"chest_open", &"chest_close")
	_is_panel_open = true
	simulate(_sounds, 2, 0.1)
	_is_panel_open = false
	simulate(_sounds, 2, 0.1)
	assert_eq(_events, [&"chest_open", &"chest_close"])


func test_placing_a_chest_and_taking_one_down_inside_are_heard() -> void:
	_hold_quietly(ItemTypes.CHEST)
	_sounds.used(GameState.Use.PLACE, _tile)
	_sounds.used(GameState.Use.TAKE_DOWN, _tile)
	_sounds.used(GameState.Use.NO_ROOM, _tile)
	assert_eq(_events, [&"build_place", &"axe_chop", &"denied"])


func test_a_button_clicks_when_pressed() -> void:
	var root := Control.new()
	var button := Button.new()
	root.add_child(button)
	add_child_autofree(root)
	_sounds.click_on_press_in(root)
	button.pressed.emit()
	assert_eq(_events, [&"ui_click"])


## The steps a player view makes in 16 frames of 1/16 s (exact in binary, so the animation's
## frame changes don't depend on rounding) while it walks at `speed`.
func _steps_in_a_second_walking_at(speed: float) -> int:
	var view := PlayerView.new()
	autofree(view)
	view.show_player(_state.player)
	view.walk_speed = speed
	var steps := []
	view.stepped.connect(func() -> void: steps.append(true))
	for _i in 16:
		_state.player.position += Vector2(0.01, 0.0)
		view._process(0.0625)
	return steps.size()


func _repeat(event: StringName, times: int) -> Array[StringName]:
	var events: Array[StringName] = []
	events.resize(times)
	events.fill(event)
	return events
