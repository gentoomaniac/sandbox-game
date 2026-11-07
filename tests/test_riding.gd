extends ResourceCase
## Riding a saddled horse: E gets on and off it (Interaction, GameState `mount` and `dismount`),
## the horse goes where the player rides it, at a walk and then at a trot, for no energy, and the
## use key, the hammer and doors wait until the player is on foot again. Getting off puts them on
## free ground beside the horse, and so does loading a game saved on horseback.

var _horse: FarmAnimal


func before_each() -> void:
	super()
	_set_ground_around(Tile.Terrain.GRASS)
	_horse = FarmAnimal.new(LivestockRules.HORSE, &"bay", Vector2(_tile) + Vector2(0.5, 0.5))
	_horse.is_saddled = true
	_state.livestock.add(_horse)


## Makes the ground within DISMOUNT_REACH of the tile (and the player above it) `terrain`, with
## nothing on it.
func _set_ground_around(terrain: Tile.Terrain) -> void:
	var reach := GameState.DISMOUNT_REACH
	for y in range(-reach - 1, reach + 1):
		for x in range(-reach, reach + 1):
			_world.remove_object(_tile + Vector2i(x, y))
			_world.set_terrain(_tile + Vector2i(x, y), terrain)


## A shack below the tile, on grass, its door facing down on its bottom row.
func _place_shack() -> Building:
	for y in range(2, 8):
		for x in range(-2, 3):
			_world.remove_object(_tile + Vector2i(x, y))
			_world.set_terrain(_tile + Vector2i(x, y), Tile.Terrain.GRASS)
	return _world.place_building(&"shack", _tile + Vector2i(-1, 3))


func _ride(direction: Vector2, seconds: float) -> void:
	for _step in int(seconds / 0.05):
		_state.walk(direction, 0.05, _state.walk_speed_factor())


func test_e_gets_on_the_saddled_horse_in_front() -> void:
	assert_eq(Interaction.horse_to_mount(_state, _tile), _horse)

	_state.mount(_horse)

	assert_eq(_state.player.horse, _horse)
	assert_true(_horse.is_ridden)
	assert_eq(_state.player.position, _horse.position)


func test_a_horse_without_a_saddle_is_not_got_on() -> void:
	_horse.is_saddled = false
	assert_null(Interaction.horse_to_mount(_state, _tile))


func test_the_horse_goes_where_the_player_rides_and_does_nothing_itself() -> void:
	_state.mount(_horse)
	_ride(Vector2.RIGHT, 0.3)
	assert_eq(_horse.position, _state.player.position)
	assert_eq(_horse.facing, 1.0)

	var position := _horse.position
	for _step in 40:
		_state.livestock.update(0.05, _world, _state.player.position, _state.clock)
	assert_eq(_horse.position, position)


func test_the_horse_walks_then_trots_at_twice_the_walking_speed() -> void:
	var rules := _state.livestock.rules
	_state.mount(_horse)
	assert_eq(_state.walk_speed_factor(), rules.general("ride_walk_factor"))
	assert_false(_state.is_trotting())

	_ride(Vector2.RIGHT, rules.general("trot_after_seconds") + 0.1)

	assert_true(_state.is_trotting())
	assert_eq(_state.walk_speed_factor(), rules.general("ride_trot_factor"))
	assert_eq(rules.general("ride_trot_factor"), 2.0 * rules.general("ride_walk_factor"))
	_ride(Vector2.ZERO, 0.05)
	assert_false(_state.is_trotting(), "standing still, it walks off again")


func test_riding_costs_no_energy_and_tiredness_does_not_slow_the_horse() -> void:
	_state.player.energy = 5.0
	_state.mount(_horse)
	_ride(Vector2.DOWN, 2.0)

	assert_eq(_state.player.energy, 5.0)
	assert_eq(_state.walk_speed_factor(), _state.livestock.rules.general("ride_trot_factor"))


func test_no_tool_and_no_building_on_horseback() -> void:
	_state.player.inventory.add(ItemTypes.HAMMER, 1)
	_hold(ItemTypes.HOE)
	_state.mount(_horse)

	assert_false(_state.can_use_held_item())
	assert_eq(_state.use_facing_tile(), ToolUse.Use.RIDING)
	var builder := Builder.new(_state)
	assert_true(builder.select_hammer())
	assert_false(builder.is_building())


func test_e_gets_off_onto_free_ground_beside_the_horse_which_stays() -> void:
	_state.mount(_horse)
	_ride(Vector2.RIGHT, 0.2)
	var horse_position := _horse.position

	assert_true(_state.dismount())

	assert_null(_state.player.horse)
	assert_false(_horse.is_ridden)
	assert_eq(_horse.position, horse_position)
	assert_ne(_state.player.tile(), _horse.tile())
	assert_eq(_state.player.tile().x, _horse.tile().x, "at its side, not at its head or tail")
	assert_true(PlayerState.can_stand_at(_world, _state.player.position))


func test_getting_off_never_puts_the_player_in_the_water() -> void:
	_set_ground_around(Tile.Terrain.WATER)
	_world.set_terrain(_tile, Tile.Terrain.GRASS)
	_world.set_terrain(_tile + Vector2i(2, 2), Tile.Terrain.GRASS)
	_state.mount(_horse)

	assert_true(_state.dismount())

	assert_eq(_state.player.tile(), _tile + Vector2i(2, 2))


func test_with_no_room_beside_the_horse_the_player_stays_on() -> void:
	_set_ground_around(Tile.Terrain.WATER)
	_world.set_terrain(_tile, Tile.Terrain.GRASS)
	_state.mount(_horse)

	assert_false(_state.dismount())

	assert_eq(_state.player.horse, _horse)


func test_a_horse_is_not_ridden_through_a_door() -> void:
	var door := _place_shack().door_tile()
	_horse.position = Vector2(door) + Vector2(0.5, 1.5)
	_state.mount(_horse)

	_ride(Vector2.UP, 1.0)

	assert_false(PlayerState.touches_building(_world, _state.player.position))
	assert_false(_state.door_underfoot())
	assert_true(_state.is_door_ahead())


func test_a_horse_in_a_doorway_is_ridden_out_not_in() -> void:
	_horse.position = Vector2(_place_shack().door_tile()) + Vector2(0.5, 0.5)
	_state.mount(_horse)

	assert_false(_state.door_underfoot())
	_ride(Vector2.DOWN, 0.5)
	assert_false(PlayerState.touches_building(_world, _state.player.position))


func test_a_game_saved_on_horseback_loads_with_the_player_beside_the_horse() -> void:
	_state.mount(_horse)

	var restored := _through_save()

	var horse := restored.livestock.all()[0]
	assert_null(restored.player.horse)
	assert_false(horse.is_ridden)
	assert_true(horse.is_saddled)
	assert_eq(horse.position, _horse.position)
	assert_ne(restored.player.tile(), horse.tile())
	assert_true(PlayerState.can_stand_at(restored.world, restored.player.position))


func test_passing_out_or_a_teleport_leaves_the_horse_where_it_is() -> void:
	_state.mount(_horse)
	_state.teleport_to(_tile + Vector2i(10, 0))
	assert_null(_state.player.horse)
	assert_false(_horse.is_ridden)

	_state.mount(_horse)
	_state.pass_out()
	assert_null(_state.player.horse)
	assert_eq(_horse.position, Vector2(_tile) + Vector2(0.5, 0.5))
