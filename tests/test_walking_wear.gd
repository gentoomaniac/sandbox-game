extends ResourceCase
## Walking wears the grass: one step for each tile the player steps onto, outdoors only.

## A fifth of a second at full speed is one tile.
const ONE_TILE_SECONDS := 1.0 / PlayerState.SPEED


func _wear_of(tile: Vector2i) -> float:
	for entry: Array in _world.to_dict()["wear"]:
		if Vector2i(entry[0], entry[1]) == tile:
			return entry[2]
	return 0.0


func test_each_tile_stepped_onto_takes_one_step() -> void:
	_world.remove_object(_tile + Vector2i.DOWN)
	_state.player.position = Vector2(_tile) + Vector2(0.5, 0.1)
	_state.walk(Vector2.DOWN, ONE_TILE_SECONDS)
	assert_eq(_state.player.tile(), _tile + Vector2i.DOWN)
	assert_eq(_wear_of(_tile + Vector2i.DOWN), 1.0)
	assert_eq(_wear_of(_tile), 0.0, "the tile they started on")


func test_walking_about_within_a_tile_wears_nothing() -> void:
	_state.player.position = Vector2(_tile) + Vector2(0.5, 0.5)
	for direction in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
		_state.walk(direction, ONE_TILE_SECONDS / 4)
	assert_eq(_world.to_dict()["wear"], [])


func test_walking_inside_a_house_wears_no_ground() -> void:
	var house: Building
	for y in range(-12, 13):
		for x in range(-12, 13):
			if house == null:
				house = _world.place_building(BuildingTypes.KATE, _tile + Vector2i(x, y))
	_state.player.position = Vector2(house.door_tile()) + Vector2(0.5, 0.5)
	_state.pass_door()
	for direction in [Vector2.UP, Vector2.LEFT, Vector2.RIGHT, Vector2.DOWN]:
		_state.walk(direction, ONE_TILE_SECONDS * 2)
	assert_true(_state.is_inside())
	assert_eq(_world.to_dict()["wear"], [])


func test_a_night_lets_the_grass_grow_back() -> void:
	var rules := PathRules.default_rules()
	for _i in rules.trodden_from():
		_world.wear_tile(_tile)
	_sleep_days(1)
	assert_eq(_wear_of(_tile), rules.trodden_from() - rules.regrowth_per_night())
