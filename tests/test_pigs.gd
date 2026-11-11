extends LivestockCase
## The pigs (task 165): four looks of the old breeds, they root about most of the day, which feeds
## them as grazing does, eat at a stock of feed and drink like the others.


func _pig(look := &"red") -> FarmAnimal:
	var pig := FarmAnimal.new(LivestockRules.PIG, look, _pen_middle())
	_livestock.add(pig)
	_livestock.stand_still(pig)
	return pig


func test_a_pig_comes_in_four_looks_of_the_old_breeds() -> void:
	assert_eq(_livestock.rules.looks(LivestockRules.PIG), ["red", "sandy", "saddleback", "spotted"])


func test_a_pig_roots_about_most_of_its_day() -> void:
	_livestock.spawn(LivestockRules.PIG, 1, _pen_middle(), _world)
	var pig: FarmAnimal = _livestock.all()[0]
	var seconds := {}
	for _step in 2400:
		_step()
		seconds[pig.activity] = float(seconds.get(pig.activity, 0.0)) + STEP_SECONDS
	assert_gt(float(seconds.get(FarmAnimal.Activity.GRAZE, 0.0)), 2400 * STEP_SECONDS / 3.0)
	assert_false(seconds.has(FarmAnimal.Activity.RUN), "a pig never runs about")


func test_rooting_feeds_a_pig() -> void:
	var pig := _pig()
	pig.hunger = 0.4
	_state.cheats.are_needs_off = true
	_run(120.0)
	assert_lt(pig.hunger, 0.4)


func test_a_hungry_pig_eats_at_a_stock_of_feed_and_takes_its_meal_out_of_it() -> void:
	var rack := WorldObject.new(WorldObjectTypes.HAY_RACK, _middle + Vector2i(-1, -1))
	_world.add_object(rack)
	ObjectStock.add(rack, 100)
	var pig := _pig()
	pig.hunger = 0.6
	_state.cheats.are_needs_off = true
	_run(40.0)
	assert_eq(pig.hunger, 0.0)
	assert_eq(ObjectStock.units(rack), 100 - 4, "a pig eats 4")


func test_a_thirsty_pig_drinks_at_the_water() -> void:
	var pig := _pig(&"saddleback")
	pig.thirst = 0.6
	_state.cheats.are_needs_off = true
	_run(40.0)
	assert_eq(pig.thirst, 0.0)


func test_a_pig_sleeps_at_midnight() -> void:
	var pig := _pig(&"spotted")
	_step(MIDNIGHT)
	assert_eq(pig.activity, FarmAnimal.Activity.SLEEP)
