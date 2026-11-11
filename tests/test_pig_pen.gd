extends LivestockCase
## The pig pen keeps its pigs in (task 165): a ring of fence with its gate round the middle of the
## test pen, the pigs inside. They root about, look for what they need and are put somewhere new by
## a skip only inside it; an open gate lets them out.

## The fence runs round the tiles this many tiles from the middle; the gate is in its bottom side.
const RING := 2
const GATE := Vector2i(0, RING)


func before_each() -> void:
	super()
	for y in range(-RING, RING + 1):
		for x in range(-RING, RING + 1):
			var at := Vector2i(x, y)
			_world.remove_object(_middle + at)
			if maxi(absi(x), absi(y)) < RING:
				continue
			var type := WorldObjectTypes.PEN_GATE if at == GATE else WorldObjectTypes.PEN_FENCE
			_world.add_object(WorldObject.new(type, _middle + at))


func _pig(look := &"red", at := Vector2.ZERO) -> FarmAnimal:
	var pig := FarmAnimal.new(LivestockRules.PIG, look, _pen_middle() + at)
	_livestock.add(pig)
	_livestock.stand_still(pig)
	return pig


func _is_in_pen(animal: FarmAnimal) -> bool:
	var at := animal.tile() - _middle
	return maxi(absi(at.x), absi(at.y)) < RING


func test_the_gate_lets_the_player_through_and_not_the_animals() -> void:
	assert_true(_world.is_walkable(_middle + GATE))
	assert_false(_world.is_walkable_for_animals(_middle + GATE))
	assert_false(_world.is_walkable_for_animals(_middle + Vector2i(1, RING)), "nor the fence")


func test_a_pig_in_a_pen_roots_about_in_it_and_never_leaves() -> void:
	var pig := _pig()
	for _step in 6000:
		_step()
		assert_true(_is_in_pen(pig), "at %s" % pig.position)
		if not _is_in_pen(pig):
			return


func test_a_skip_leaves_a_pig_somewhere_in_its_pen() -> void:
	var pig := _pig()
	for seed_value in 20:
		_livestock.catch_up(_world, _state.clock, _state.player.position, seed_value, 600)
		assert_true(_is_in_pen(pig), "at %s after skip %d" % [pig.position, seed_value])


func test_a_thirsty_pig_cannot_reach_the_water_outside_its_pen() -> void:
	var pig := _pig()
	pig.thirst = 0.6
	_state.cheats.are_needs_off = true
	_run(40.0)
	assert_eq(pig.thirst, 0.6)
	assert_true(_is_in_pen(pig))


func test_a_pig_drinks_and_eats_at_the_troughs_in_its_pen() -> void:
	var water := WorldObject.new(WorldObjectTypes.TROUGH, _middle + Vector2i(-1, -1))
	_world.add_object(water)
	ObjectStock.add(water, 100)
	var feed := WorldObject.new(WorldObjectTypes.FEED_TROUGH, _middle + Vector2i(-1, 1))
	_world.add_object(feed)
	ObjectStock.add(feed, 100)
	var pig := _pig(&"sandy", Vector2(1.0, 0.0))
	pig.thirst = 0.6
	pig.hunger = 0.7
	_state.cheats.are_needs_off = true
	_run(60.0)
	assert_eq(pig.thirst, 0.0)
	assert_eq(pig.hunger, 0.0)
	assert_eq(ObjectStock.units(water), 96)
	assert_eq(ObjectStock.units(feed), 96)


func test_a_skip_counts_the_meals_of_a_pig_at_the_troughs_of_its_pen() -> void:
	var water := WorldObject.new(WorldObjectTypes.TROUGH, _middle + Vector2i(-1, -1))
	_world.add_object(water)
	ObjectStock.add(water, 100)
	var pig := _pig()
	pig.thirst = 0.9
	_livestock.catch_up(_world, _state.clock, _state.player.position, SEED, 480)
	assert_lt(pig.thirst, 0.5)
	assert_lt(ObjectStock.units(water), 100)


func test_an_open_gate_is_a_way_out() -> void:
	var inside := ReachableTiles.within(_middle, 6.0, _world.is_walkable_for_animals)
	assert_false(inside.has(_middle + GATE + Vector2i.DOWN))
	var gate := _world.object_at(_middle + GATE)
	_world.replace_object(gate, WorldObject.new(WorldObjectTypes.PEN_GATE_OPEN, gate.pos))
	var out := ReachableTiles.within(_middle, 6.0, _world.is_walkable_for_animals)
	assert_true(out.has(_middle + GATE + Vector2i.DOWN))
