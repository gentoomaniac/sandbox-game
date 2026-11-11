extends LivestockCase
## What stops animals (WorldObjectTypes `stops_animals`): the player walks over it, the farm animals
## do not. A row of it across the pen keeps them on their side in play and over a skip, and one that
## comes under an animal's feet does not trap it. A test-only type stands for it, so these tests do
## not hang on any one object that has it.

## The row of stiles runs across the pen on this row of tiles from its middle.
const ROW := 0

var _types: Dictionary


func before_each() -> void:
	_types = WorldObjectTypes.TYPES
	WorldObjectTypes.TYPES = _types_with_stile(_types)
	super()
	for x in range(-PEN_RADIUS, PEN_RADIUS + 1):
		var tile := _middle + Vector2i(x, ROW)
		_world.remove_object(tile)
		_world.add_object(WorldObject.new(STILE, tile))


func after_each() -> void:
	WorldObjectTypes.TYPES = _types


func _sheep(at: Vector2) -> FarmAnimal:
	var sheep := FarmAnimal.new(LivestockRules.SHEEP, &"white", _pen_middle() + at)
	_livestock.add(sheep)
	_livestock.stand_still(sheep)
	return sheep


func _row_of(animal: FarmAnimal) -> int:
	return animal.tile().y - _middle.y


func test_the_player_walks_over_it_and_the_animals_do_not() -> void:
	var tile := _middle + Vector2i(0, ROW)
	assert_true(_world.is_walkable(tile))
	assert_false(_world.is_walkable_for_animals(tile))
	assert_true(_world.is_walkable_for_animals(tile + Vector2i.UP), "grass")
	_world.remove_object(tile)
	_world.add_object(WorldObject.new(WorldObjectTypes.STONE, tile))
	assert_false(_world.is_walkable_for_animals(tile), "nor over what blocks anyone")


func test_animals_keep_to_their_side_of_it() -> void:
	var sheep := _sheep(Vector2(-1.0, -2.0))
	for _step in 3000:
		_step()
		assert_lt(_row_of(sheep), ROW, "at %s" % sheep.position)
		if _row_of(sheep) >= ROW:
			return


func test_a_skip_puts_an_animal_on_its_side_of_it() -> void:
	var sheep := _sheep(Vector2(-1.0, -1.0))
	for seed_value in 20:
		_livestock.catch_up(_world, _state.clock, _state.player.position, seed_value, 600)
		assert_lt(_row_of(sheep), ROW, "at %s after skip %d" % [sheep.position, seed_value])


func test_water_beyond_it_is_out_of_reach() -> void:
	var sheep := _sheep(Vector2(-1.0, -2.0))
	# The ring of water above the row is salt: the only fresh water is below it.
	for x in range(-PEN_RADIUS - 1, PEN_RADIUS + 2):
		_world.set_terrain(_middle + Vector2i(x, -PEN_RADIUS - 1), Tile.Terrain.SEA)
	for y in range(-PEN_RADIUS - 1, ROW):
		_world.set_terrain(_middle + Vector2i(-PEN_RADIUS - 1, y), Tile.Terrain.SEA)
		_world.set_terrain(_middle + Vector2i(PEN_RADIUS + 1, y), Tile.Terrain.SEA)
	sheep.thirst = 0.6
	_state.cheats.are_needs_off = true
	_run(40.0)
	assert_eq(sheep.thirst, 0.6)


func test_an_animal_it_comes_under_walks_off_it() -> void:
	var sheep := _sheep(Vector2(0.0, float(ROW)))
	assert_false(_world.is_walkable_for_animals(sheep.tile()), "it stands on a stile")
	_run(60.0)
	assert_ne(_row_of(sheep), ROW, "not trapped at %s" % sheep.position)
