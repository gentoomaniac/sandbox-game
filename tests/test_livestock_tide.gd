extends LivestockCase
## The tide and the farm animals: they keep off mud under water, and one caught in it by the rising
## water walks out. The tests' noon of day 45 falls at high water.

## The east half of the pen is tidal mud.
const FIRST_MUD_COLUMN := 1


func before_each() -> void:
	super()
	for y in range(-PEN_RADIUS, PEN_RADIUS + 1):
		for x in range(FIRST_MUD_COLUMN, PEN_RADIUS + 1):
			_world.set_terrain(_middle + Vector2i(x, y), Tile.Terrain.MUD)
	assert_gt(Tide.level(_state.clock.total_minutes()), 0.99, "high water")


func _sheep(at: Vector2) -> FarmAnimal:
	var sheep := FarmAnimal.new(LivestockRules.SHEEP, &"white", _pen_middle() + at)
	_livestock.add(sheep)
	return sheep


func _column_of(animal: FarmAnimal) -> int:
	return animal.tile().x - _middle.x


func test_animals_keep_off_flooded_mud() -> void:
	var sheep := _sheep(Vector2(-1.5, 0.0))
	for _step in 6000:
		_step()
		assert_lt(_column_of(sheep), FIRST_MUD_COLUMN, "on the flooded mud at %s" % sheep.position)


func test_the_mud_is_open_to_animals_at_low_water() -> void:
	_state.clock.day = 1
	_state.clock.minute_of_day = 373
	assert_true(_world.is_walkable_for_animals(_middle + Vector2i(FIRST_MUD_COLUMN, 0)))


func test_an_animal_in_the_rising_water_walks_out_of_it() -> void:
	var sheep := _sheep(Vector2(FIRST_MUD_COLUMN + 0.5, 0.0))
	var was_on_grass := false
	for _step in 6000:
		_step()
		was_on_grass = was_on_grass or _column_of(sheep) < FIRST_MUD_COLUMN
	assert_true(was_on_grass, "it got out of the water")
