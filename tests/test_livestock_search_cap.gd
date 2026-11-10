extends LivestockCase
## The searches of the animals for water and feed are flood fills of the ground round them, so an
## update makes no more than `searches_per_update` of them, however big the herd or many the needs
## (task 122).

const HERD := 100


func before_each() -> void:
	super()
	_state.cheats.are_needs_off = true
	# A closed pen of open ground with no water that can be drunk and no stock: nothing to find.
	for y in range(-PEN_RADIUS - 1, PEN_RADIUS + 2):
		for x in range(-PEN_RADIUS - 1, PEN_RADIUS + 2):
			var tile := _middle + Vector2i(x, y)
			if _world.tile_at(tile).terrain == Tile.Terrain.WATER:
				_world.set_terrain(tile, Tile.Terrain.SEA)


## A rule set with another cap on the searches of one update.
func _cap(searches: int) -> void:
	var values := DataFile.read_sections(YardRules.DEFAULT_PATH)
	values["needs"]["searches_per_update"] = searches
	_livestock.yard = YardRules.new(values)


func _decide_now(animal: FarmAnimal) -> void:
	animal.thirst = 0.9
	animal.hunger = 0.9
	animal.activity = FarmAnimal.Activity.IDLE
	animal.seconds_left = 0.0


func test_an_animal_with_two_pressing_needs_stays_within_one_search() -> void:
	_cap(1)
	var cow := FarmAnimal.new(LivestockRules.COW, &"angler", _pen_middle())
	_livestock.add(cow)
	_decide_now(cow)
	_step()
	assert_eq(_livestock.search_count, 1, "one search of two needs")
	assert_gt(cow.search_seconds, 0.0, "and not again at once")


func test_a_big_herd_that_finds_nothing_stays_within_the_cap_and_a_time_bound() -> void:
	_cap(2)
	_livestock.spawn(LivestockRules.COW, HERD, _pen_middle(), _world)
	for animal in _livestock.all():
		_decide_now(animal)
	var started := Time.get_ticks_usec()
	_step()
	var seconds := (Time.get_ticks_usec() - started) / 1000000.0
	assert_lte(_livestock.search_count, 2, "searches in one update")
	assert_lt(seconds, 0.5, "an update of a big herd")
	var searches := _livestock.search_count
	for _frame in 20:
		_step()
	assert_lte(_livestock.search_count - searches, 2 * 20)
