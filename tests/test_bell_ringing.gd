extends ResourceCase
## Ringing the bell of a bell frame: who is close enough (the 3x3 tiles around the player reach it,
## as every use does), the clicks and the E key of Main, and how far the bell is heard.

const MAIN_SCENE := preload("res://game/scenes/main.tscn")
const SETTLE_SECONDS := 30.0

var _rung: Array[Building] = []


func before_each() -> void:
	super.before_each()
	_rung.clear()


func _stand_on(state: GameState, tile: Vector2i) -> void:
	state.player.position = TerrainTileset.tile_centre(tile) / TerrainTileset.TILE_SIZE


func test_a_bell_frame_within_one_tile_of_the_player_is_rung_by_e() -> void:
	var frame := _place_building_nearby(BuildingTypes.BELL_FRAME)
	for offset in [Vector2i(-1, 0), Vector2i(-1, -1), Vector2i(2, 1), Vector2i(1, 2)]:
		_stand_on(_state, frame.origin + offset)
		assert_eq(Interaction.bell_frame_to_ring(_state), frame, str(offset))


func test_a_bell_frame_two_tiles_away_is_not_rung() -> void:
	var frame := _place_building_nearby(BuildingTypes.BELL_FRAME)
	for offset in [Vector2i(-2, 0), Vector2i(0, -2), Vector2i(3, 1), Vector2i(1, 3)]:
		_stand_on(_state, frame.origin + offset)
		assert_null(Interaction.bell_frame_to_ring(_state), str(offset))


func test_a_click_rings_the_bell_frame_only_on_the_frame() -> void:
	var frame := _place_building_nearby(BuildingTypes.BELL_FRAME)
	_stand_on(_state, frame.origin + Vector2i(-1, 0))
	# The far tile of the frame is two tiles from the player, but the frame is within reach.
	assert_eq(Interaction.bell_frame_to_ring(_state, frame.origin + Vector2i(1, 1)), frame)
	assert_eq(Interaction.bell_frame_to_ring(_state, frame.origin), frame)
	assert_null(Interaction.bell_frame_to_ring(_state, frame.origin + Vector2i(-1, 1)))


func test_no_other_building_is_rung() -> void:
	var builder := Builder.new(_state)
	builder.choose(BuildingTypes.SHACK)
	for item: StringName in builder.costs():
		_state.player.inventory.add(item, builder.costs()[item])
	var shack: Building = null
	for y in range(2, 20):
		for x in range(-10, 10):
			if shack == null:
				shack = builder.place(_state.player.tile() + Vector2i(x, y))
	assert_not_null(shack)
	_stand_on(_state, shack.origin + Vector2i(-1, 0))
	assert_null(Interaction.bell_frame_to_ring(_state))


func test_e_leaves_the_bell_to_a_bed_in_reach_but_a_click_still_rings() -> void:
	var frame := _place_building_nearby(BuildingTypes.BELL_FRAME)
	_stand_on(_state, frame.origin + Vector2i(-1, 0))
	_world.add_object(WorldObject.new(WorldObjectTypes.SLEEPING_BAG, _state.player.tile()))
	assert_not_null(_state.bed_in_reach())
	assert_null(Interaction.bell_frame_to_ring(_state), "E sleeps")
	assert_eq(Interaction.bell_frame_to_ring(_state, frame.origin), frame, "a click rings")


func test_a_click_rings_with_a_tool_in_hand_since_no_tool_does_anything_there() -> void:
	var frame := _place_building_nearby(BuildingTypes.BELL_FRAME)
	_stand_on(_state, frame.origin + Vector2i(-1, 0))
	for item in [
		ItemTypes.NONE,
		ItemTypes.AXE,
		ItemTypes.PICKAXE,
		ItemTypes.HOE,
		ItemTypes.SHOVEL,
		ItemTypes.SCYTHE,
		ItemTypes.WATERING_CAN,
	]:
		_hold(item)
		assert_eq(_state.use_at(frame.origin), ToolUse.Use.NOTHING, str(item))
		assert_eq(Interaction.bell_frame_to_ring(_state, frame.origin), frame, str(item))


func test_a_rider_does_not_ring() -> void:
	var frame := _place_building_nearby(BuildingTypes.BELL_FRAME)
	_stand_on(_state, frame.origin + Vector2i(-1, 0))
	_state.player.horse = FarmAnimal.new(LivestockRules.HORSE, &"bay", _state.player.position)
	assert_null(Interaction.bell_frame_to_ring(_state))
	_state.player.horse = null


func test_ringing_says_which_bell_and_changes_nothing_else() -> void:
	var frame := _place_building_nearby(BuildingTypes.BELL_FRAME)
	_state.world.bell_rung.connect(func(building: Building) -> void: _rung.append(building))
	_stand_on(_state, frame.origin + Vector2i(-1, 0))
	var snapshot := _state.to_dict()
	assert_true(_state.ring_bell_in_reach())
	assert_true(_state.ring_bell_in_reach(frame.origin))
	assert_false(_state.ring_bell_in_reach(frame.origin + Vector2i(-1, 1)))
	assert_eq(_rung, [frame, frame])
	assert_eq(_state.to_dict(), snapshot)


func test_e_and_a_click_in_the_game_ring_the_bell() -> void:
	var main: Node = MAIN_SCENE.instantiate()
	add_child_autofree(main)
	await wait_until(
		func() -> bool: return main._view != null and main._view.is_settled, SETTLE_SECONDS
	)
	# The helpers of ResourceCase work on the game that Main plays.
	_state = main._state
	_world = _state.world
	var frame := _place_building_nearby(BuildingTypes.BELL_FRAME)
	_state.world.bell_rung.connect(func(building: Building) -> void: _rung.append(building))
	_stand_on(_state, frame.origin + Vector2i(-1, 0))

	main._unhandled_input(_pressed(&"interact"))
	assert_eq(_rung, [frame], "E rings it")

	main._use_highlight.debug_mouse_tile = frame.origin + Vector2i(1, 1)
	main._unhandled_input(_pressed(&"use_click"))
	assert_eq(_rung, [frame, frame], "a click on it rings it")

	main._use_highlight.debug_mouse_tile = frame.origin + Vector2i(-1, 1)
	main._unhandled_input(_pressed(&"use_click"))
	assert_eq(_rung, [frame, frame], "a click beside it does not")


func _pressed(action: StringName) -> InputEventAction:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	return event


func test_at_most_three_strikes_sound_at_once_and_the_oldest_is_cut_off_for_a_new_one() -> void:
	var audio := AudioService.new()
	add_child_autofree(audio)
	audio.play(&"axe_chop", Vector2.ZERO)
	var strikes: Array[AudioStreamPlayer2D] = []
	for ring in 5:
		audio.play(&"bell_ring", Vector2.ZERO)
		for node in audio.get_children():
			if node is AudioStreamPlayer2D and node.playing and node.stream.get_length() > 8.0:
				if not strikes.has(node):
					strikes.append(node)
	assert_eq(strikes.size(), 3, "the same three players carry all five strikes")
	var chops := audio.get_children().filter(
		func(node: Node) -> bool:
			return node is AudioStreamPlayer2D and node.playing and node.stream.get_length() < 1.0
	)
	assert_eq(chops.size(), 1, "the chop was not cut off")


func test_the_bell_is_heard_much_farther_than_other_effects() -> void:
	var audio := AudioService.new()
	add_child_autofree(audio)
	audio.play(&"axe_chop", Vector2.ZERO)
	audio.play(&"bell_ring", Vector2.ZERO)
	var reaches := {}
	for node in audio.get_children():
		if node is AudioStreamPlayer2D and node.playing:
			reaches[node.stream.resource_path.get_file()] = node.max_distance
	assert_eq(reaches.size(), 2)
	var bell_reach: float = SoundRules.default_rules().event(&"bell_ring")["reach_tiles"]
	for file: String in reaches:
		if file.begins_with("bell_ring"):
			assert_eq(reaches[file], bell_reach * TerrainTileset.TILE_SIZE)
		else:
			assert_eq(reaches[file], AudioService.MAX_DISTANCE)
	assert_gt(bell_reach * TerrainTileset.TILE_SIZE, 3.0 * AudioService.MAX_DISTANCE)
