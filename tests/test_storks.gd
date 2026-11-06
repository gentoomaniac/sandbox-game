extends WildlifeCase
## Storks in the view: one sent to a roof flies in and lands on the ridge of the house, in front
## of it to be drawn over it; a roof takes one stork; a hunting stork flies off when the
## player comes near, while one on a roof stays; and a hunting stork catches the frogs it sees.

const HOUSE_AT := Vector2i(3, 8)

var _house: Building


func before_each() -> void:
	super()
	_house = _state.world.place_building(BuildingTypes.KATE, HOUSE_AT)
	_camera.rig.position = _wildlife._front_middle(_house)


func _storks() -> Array[Animal]:
	return _animals_of(Stork)


func test_a_stork_flies_in_from_outside_the_view_and_lands_on_the_ridge() -> void:
	assert_true(_wildlife._send_stork_to_roof(false))
	var stork: Stork = _storks()[0]
	assert_eq(stork.roof, _house)
	assert_true(stork._is_out_of_view(), "it comes from beside the view")
	assert_eq(stork._state, Stork.ARRIVE)
	_run(stork, 30.0)
	assert_eq(stork._state, Stork.PERCH)
	var feet := stork.position.y - stork._lift
	var bottom := BuildingViews.footprint_bottom(_house)
	assert_lt(feet, bottom - 3 * TerrainTileset.TILE_SIZE, "up on the roof, above the walls")
	assert_eq(stork.z_index, 0, "sorted with the house, not over everything")


func test_a_stork_on_a_roof_sorts_just_in_front_of_its_house() -> void:
	_wildlife.spawn_in_view(WildlifeRules.ROOF_STORK, 1)
	var stork: Stork = _storks()[0]
	var house_sorted_at := BuildingViews.sort_position(_house).y
	assert_almost_eq(stork.position.y, house_sorted_at + 1.0, 0.01)
	assert_true(stork.get_parent() == _wildlife.world_view.entities, "sorted with the house")


func test_a_stork_stands_on_top_of_the_roof_as_it_is_shown() -> void:
	_wildlife.spawn_in_view(WildlifeRules.ROOF_STORK, 1)
	var stork: Stork = _storks()[0]
	var picture: Texture2D = load(_wildlife.world_view.building_picture(_house))
	var image := picture.get_image()
	var column := roundi(stork.position.x) - _house.origin.x * TerrainTileset.TILE_SIZE
	var top := 0
	while image.get_pixel(column, top).a < 0.5:
		top += 1
	var roof_top := BuildingViews.footprint_bottom(_house) - image.get_height() + top
	assert_almost_eq(stork.position.y - stork._lift, roof_top + 2.0, 0.01, "two pixels in")


func test_a_stork_leaves_a_roof_whose_house_is_gone() -> void:
	_wildlife.spawn_in_view(WildlifeRules.ROOF_STORK, 1)
	var stork: Stork = _storks()[0]
	_wildlife.world_view.world = GameState.new_game(1).world
	_run(stork, 10.0)
	assert_eq(stork._state, Stork.FLY)


func test_a_stork_made_by_hand_stands_on_the_roof_at_once() -> void:
	assert_eq(_wildlife.spawn_in_view(WildlifeRules.ROOF_STORK, 1), 1)
	var stork: Stork = _storks()[0]
	assert_eq(stork._state, Stork.PERCH)
	assert_eq(stork.roof, _house)


func test_a_roof_takes_one_stork() -> void:
	assert_eq(_wildlife.spawn_in_view(WildlifeRules.ROOF_STORK, 3), 1)
	assert_false(_wildlife._send_stork_to_roof(false))


func test_no_roof_no_stork() -> void:
	_wildlife.world_view.world = GameState.new_game(1).world
	assert_false(_wildlife._send_stork_to_roof(false))
	assert_eq(_wildlife.spawn_in_view(WildlifeRules.ROOF_STORK, 1), 0)


func test_a_stork_on_a_roof_ignores_the_player_but_a_hunting_one_flies_off() -> void:
	_wildlife.is_player_ignored = false
	_wildlife.spawn_in_view(WildlifeRules.ROOF_STORK, 1)
	var on_roof: Stork = _storks()[0]
	_wildlife.world_view.player_feet = on_roof.position
	_run(on_roof, 1.0)
	assert_eq(on_roof._state, Stork.PERCH)
	assert_eq(_wildlife.spawn_in_view(WildlifeRules.STORK, 1), 1)
	var hunting: Stork = _storks()[1]
	_wildlife.world_view.player_feet = hunting.position + Vector2(20.0, 0.0)
	_run(hunting, STEP)
	assert_eq(hunting._state, Stork.FLY)
	_run(hunting, 20.0)
	assert_true(hunting.is_done, "flown out of the view")


## A hunting stork on an open meadow, and a frog two tiles to its right.
func _stork_and_frog() -> Array[Animal]:
	var meadow := Vector2i(-12, 8)
	for y in range(meadow.y - 3, meadow.y + 4):
		for x in range(meadow.x - 3, meadow.x + 6):
			_state.world.set_terrain(Vector2i(x, y), Tile.Terrain.GRASS)
			_state.world.remove_object(Vector2i(x, y))
	_wildlife._spawn(WildlifeRules.STORK, TerrainTileset.tile_centre(meadow), true)
	_wildlife._spawn(WildlifeRules.FROG, TerrainTileset.tile_centre(meadow + Vector2i(2, 0)), true)
	return [_storks()[0], _animals_of(Frog)[0]]


## Runs a stork until it has walked up to its frog (for at most STALK_SECONDS).
func _run_while_stalking(stork: Stork) -> void:
	for _i in roundi(Stork.STALK_SECONDS / STEP):
		if stork._state != Stork.STALK:
			return
		stork._process(STEP)


func test_a_hunting_stork_walks_up_to_a_frog_strikes_and_swallows_it() -> void:
	var pair := _stork_and_frog()
	var stork: Stork = pair[0]
	var frog: Frog = pair[1]
	var states: Array[StringName] = []
	stork.state_entered.connect(func(state: StringName) -> void: states.append(state))
	stork._choose_next()
	assert_eq(stork._state, Stork.STALK, "it sees the frog")
	_run_while_stalking(stork)
	assert_eq(stork._state, Stork.STRIKE)
	assert_almost_eq(stork.position, frog.position - Vector2(Stork.BILL_REACH, 0.0), Vector2.ONE)
	assert_false(stork._sprite.flip_h, "facing the frog")
	_run(stork, Stork.STRIKE_SECONDS + STEP)
	assert_true(frog.is_done, "caught")
	assert_eq(states, [Stork.STALK, Stork.STRIKE, Stork.SWALLOW] as Array[StringName])


func test_a_frog_that_hops_away_during_the_strike_is_missed() -> void:
	var pair := _stork_and_frog()
	var stork: Stork = pair[0]
	var frog: Frog = pair[1]
	stork._choose_next()
	_run_while_stalking(stork)
	assert_eq(stork._state, Stork.STRIKE)
	frog.position += Vector2(0.0, 12.0)
	_run(stork, Stork.STRIKE_SECONDS + STEP)
	assert_false(frog.is_done)
	assert_ne(stork._state, Stork.SWALLOW)


func test_a_stork_takes_no_notice_of_a_frog_beyond_its_sight() -> void:
	var pair := _stork_and_frog()
	var stork: Stork = pair[0]
	var frog: Frog = pair[1]
	frog.position = (
		stork.position + Vector2((Stork.SIGHT_TILES + 1.0) * TerrainTileset.TILE_SIZE, 0)
	)
	stork._choose_next()
	assert_ne(stork._state, Stork.STALK)
