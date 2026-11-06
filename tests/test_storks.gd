extends WildlifeCase
## Storks in the view: one sent to a roof flies in and lands on the ridge of the house, in front
## of it to be drawn over it; a roof takes one stork; and a hunting stork flies off when the
## player comes near, while one on a roof stays.

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
