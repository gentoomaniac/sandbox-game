extends CoopCase
## The chicken coop of the farm yard (task 122): built with the hammer, the hens walk to it at
## bedtime and sleep in it out of sight (as many as it has roosts for), lay their eggs in its nests,
## come out in the morning, a skip of time over their bedtime counts the eggs, and the player takes
## the eggs out of the nests by hand.


func test_the_hammer_builds_the_coop_for_twelve_logs_and_four_stone() -> void:
	var builder := Builder.new(_state)
	builder.choose(BuildingTypes.CHICKEN_COOP)
	assert_eq(builder.costs(), {ItemTypes.LOGS: 12, ItemTypes.STONE: 4})
	assert_eq(BuildingTypes.TYPES[BuildingTypes.CHICKEN_COOP]["footprint"], Vector2i(2, 2))


func test_a_hen_walks_to_the_coop_at_bedtime_and_sleeps_in_it_out_of_sight() -> void:
	var hen := _hens(1)[0]
	_run(30.0, NIGHT)
	assert_true(hen.is_housed)
	assert_eq(hen.activity, FarmAnimal.Activity.SLEEP)
	assert_eq(_world.building_at(hen.tile()), _coop, "on a tile of the coop")


func test_a_hen_in_the_coop_is_not_shown() -> void:
	var hen := _hens(1)[0]
	_run(30.0, NIGHT)
	var view := FarmAnimalView.new(hen)
	add_child_autofree(view)
	view._update(0.0)
	assert_false(view.visible)


func test_only_as_many_hens_go_in_as_it_has_roosts_and_the_others_sleep_outside() -> void:
	var hens := _hens(8)
	_run(60.0, NIGHT)
	assert_eq(_housed(hens).size(), 6, "six roosts")
	for hen in hens:
		assert_eq(hen.activity, FarmAnimal.Activity.SLEEP)


func test_hens_with_no_coop_sleep_where_they_stand() -> void:
	_world.remove_building(_coop)
	var hen := _hens(1)[0]
	var before := hen.position
	_run(10.0, NIGHT)
	assert_false(hen.is_housed)
	assert_eq(hen.activity, FarmAnimal.Activity.SLEEP)
	assert_eq(hen.position, before)


func test_a_coop_beyond_the_call_is_not_gone_to() -> void:
	var far := _pen_middle() + Vector2(float(_livestock.yard.coop("call_tiles")) + 4.0, 0.0)
	assert_null(Coop.nearest_free(_world, _livestock.all(), far, _livestock.yard, {}, _anywhere))
	assert_eq(
		Coop.nearest_free(_world, _livestock.all(), _pen_middle(), _livestock.yard, {}, _anywhere),
		_coop
	)


func test_other_animals_sleep_where_they_stand_and_never_go_in() -> void:
	var cow := FarmAnimal.new(LivestockRules.COW, &"angler", _pen_middle() + Vector2(0.0, 2.0))
	_livestock.add(cow)
	_run(30.0, NIGHT)
	assert_eq(cow.activity, FarmAnimal.Activity.SLEEP)
	assert_null(_world.building_at(cow.tile()))


func test_a_hen_lays_an_egg_in_a_nest_as_she_goes_in() -> void:
	_hens(1)
	_run(30.0, NIGHT)
	assert_eq(_eggs(), 1)


func test_a_hen_lays_by_the_chance_of_the_data_file() -> void:
	_livestock.yard = _yard_with("egg_chance", 0.0)
	_hens(3)
	_run(30.0, NIGHT)
	assert_eq(_eggs(), 0)


func test_a_nest_holds_so_many_eggs_and_the_hens_lay_in_the_next_one() -> void:
	var nests := Coop.nests(_coop)
	assert_eq(nests.size(), 2, "two nests, the hay piles of its inside")
	for _egg in 6:
		assert_true(Coop.lay_egg(_coop, _livestock.yard, _livestock.rng))
	assert_eq(Coop.eggs_in(nests[0]), 4)
	assert_eq(Coop.eggs_in(nests[1]), 2)
	assert_true(Coop.lay_egg(_coop, _livestock.yard, _livestock.rng))
	assert_true(Coop.lay_egg(_coop, _livestock.yard, _livestock.rng))
	assert_false(Coop.lay_egg(_coop, _livestock.yard, _livestock.rng), "every nest is full")
	assert_eq(_eggs(), 8)


func test_the_hens_come_out_in_the_morning_in_front_of_the_door() -> void:
	var hens := _hens(3)
	_run(30.0, NIGHT)
	assert_eq(_housed(hens).size(), 3)
	_run(3.0, MORNING)
	for hen in hens:
		assert_false(hen.is_housed)
		assert_null(_world.building_at(hen.tile()))
		assert_lt(hen.position.distance_to(Coop.door_front(_coop)), 1.0)


func test_the_empty_hand_takes_the_eggs_out_of_a_nest() -> void:
	Coop.lay_egg(_coop, _livestock.yard, _livestock.rng)
	Coop.lay_egg(_coop, _livestock.yard, _livestock.rng)
	var nest := Coop.nests(_coop)[0]
	_go_in()
	assert_eq(_state.use_at(nest.pos), ToolUse.Use.COLLECT)
	assert_eq(_state.use_tile(nest.pos), ToolUse.Use.COLLECT)
	assert_eq(_state.player.inventory.count_of(ItemTypes.EGG), 2)
	assert_eq(_eggs(), 0)
	assert_eq(_state.use_at(nest.pos), ToolUse.Use.NOTHING, "nothing left to take")


func test_taking_eggs_tells_the_nest_and_the_eggs() -> void:
	var outcomes: Array[ActionOutcome] = []
	_state.action_done.connect(func(outcome: ActionOutcome) -> void: outcomes.append(outcome))
	Coop.lay_egg(_coop, _livestock.yard, _livestock.rng)
	var nest := Coop.nests(_coop)[0]
	_go_in()
	_state.use_tile(nest.pos)
	assert_eq(outcomes.size(), 1)
	assert_eq(outcomes[0].kind, ActionOutcome.COLLECT)
	assert_eq(outcomes[0].items, {ItemTypes.EGG: 1})
	assert_ne(SoundEvents.action(ActionOutcome.COLLECT), &"")


func test_seven_hens_that_call_at_once_fill_six_roosts_and_no_more() -> void:
	var hens := _hens(7)
	_run(90.0, NIGHT)
	assert_eq(_housed(hens).size(), 6)
	assert_eq(Coop.hens_in(_world, _coop, _livestock.all()), 6)
	assert_eq(_eggs(), 6)


func test_only_a_coop_houses_hens_not_any_building() -> void:
	var shack := _world.place_building(BuildingTypes.SHACK, _middle + Vector2i(-3, 1))
	assert_not_null(shack)
	assert_false(Coop.is_coop(shack, _livestock.yard))
	assert_true(Coop.is_coop(_coop, _livestock.yard))
	var hen := _hens(1)[0]
	hen.position = Vector2(shack.door_tile()) + Vector2(0.5, 0.5)
	_run(0.5, MORNING)
	assert_false(hen.is_housed, "on the door tile of a house")


func test_a_trip_that_cannot_be_walked_is_not_tried_again_at_once() -> void:
	_make_a_wall_between()
	var cow := FarmAnimal.new(LivestockRules.COW, &"angler", _pen_middle())
	_livestock.add(cow)
	_livestock.stand_still(cow)
	cow.thirst = 0.9
	cow.goal = _pen_middle() + Vector2(0.0, 3.0)
	cow.goal_need = &"thirst"
	cow.goal_source = _middle + Vector2i(0, 4)
	cow.activity = FarmAnimal.Activity.WALK
	cow.seconds_left = 0.0
	_run(0.2, NOON)
	assert_false(cow.goal.is_finite())
	assert_gt(cow.search_seconds, 0.0)


## A line of stones across the pen, so that a straight walk south from its middle is blocked.
func _make_a_wall_between() -> void:
	for x in range(-PEN_RADIUS, PEN_RADIUS + 1):
		_world.remove_object(_middle + Vector2i(x, 1))
		_world.add_object(WorldObject.new(WorldObjectTypes.STONE, _middle + Vector2i(x, 1)))


func test_the_coop_has_a_door_and_a_walkable_floor_and_no_bed() -> void:
	var coop_type: Dictionary = BuildingTypes.TYPES[BuildingTypes.CHICKEN_COOP]
	assert_eq(coop_type["beds"], 0)
	assert_true(_coop.has_inside())
	assert_eq(_coop.inside().size, Vector2i(6, 6))
	assert_true(YardRules.default_rules().is_valid())


func test_a_hen_on_the_walkable_door_tile_is_not_in_the_coop() -> void:
	var hens := _hens(6)
	_run(90.0, NIGHT)
	assert_eq(_housed(hens).size(), 6)
	var seventh := FarmAnimal.new(
		LivestockRules.CHICKEN, &"white", Vector2(_coop.door_tile()) + Vector2(0.5, 0.5)
	)
	_livestock.add(seventh)
	_run(5.0, NIGHT)
	assert_false(seventh.is_housed, "the door tile is where she stands, not inside")
	assert_eq(Coop.hens_in(_world, _coop, _livestock.all()), 6, "six roosts, six hens")
	assert_eq(_eggs(), 6)
