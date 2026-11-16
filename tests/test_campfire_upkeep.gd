extends ResourceCase
## Campfires burn their wood down with the game's time (CampfireUpkeep): by the minute, over sleep
## and skips, and out of sight; one that burns out goes dark and is no station, and burns again
## when wood is put in and it is lit.

const LOG_MINUTES := 180


func _lit_fire(logs: int) -> WorldObject:
	var fire := _place(WorldObjectTypes.FIREPLACE)
	fire.storage.add(ItemTypes.LOGS, logs)
	_state.light_campfire(fire)
	return fire


func test_a_log_burns_for_three_hours_and_the_next_one_follows() -> void:
	var fire := _lit_fire(3)
	_state.pass_awake_time(LOG_MINUTES - 1)
	assert_eq(fire.storage.count_of(ItemTypes.LOGS), 2, "still the first log")
	assert_eq(Campfire.minutes_left(fire), 3 * LOG_MINUTES - (LOG_MINUTES - 1))
	_state.pass_awake_time(1)
	assert_eq(fire.storage.count_of(ItemTypes.LOGS), 1, "the second log is on")
	assert_eq(Campfire.minutes_left(fire), 2 * LOG_MINUTES)


func test_a_fire_without_wood_goes_out_dark() -> void:
	var fire := _lit_fire(1)
	assert_false(fire.light().is_empty())
	_state.pass_awake_time(LOG_MINUTES)
	assert_true(Campfire.is_out(fire))
	assert_true(fire.light().is_empty())
	assert_eq(Campfire.minutes_left(fire), 0)


func test_an_out_fire_does_not_cook_and_lit_again_it_does() -> void:
	var fire := _lit_fire(1)
	var crafting := Crafting.new(_state)
	_state.player.position = Vector2(fire.pos) + Vector2(0.5, 1.5)
	assert_true(crafting.is_in_reach(fire))
	_state.pass_awake_time(LOG_MINUTES)
	assert_false(crafting.is_in_reach(fire), "out")
	fire.storage.add(ItemTypes.LOGS, 1)
	_state.light_campfire(fire)
	assert_true(crafting.is_in_reach(fire), "lit again")


func test_a_skip_burns_by_the_hours_that_passed_and_no_more_than_there_is() -> void:
	var fire := _lit_fire(4)
	_state.simulation.skip(5 * 60)
	assert_eq(Campfire.minutes_left(fire), 4 * LOG_MINUTES - 5 * 60)
	_state.simulation.skip(24 * 60)
	assert_true(Campfire.is_out(fire))
	assert_eq(fire.storage.count_of(ItemTypes.LOGS), 0)


func test_a_fire_out_of_sight_burns_as_well() -> void:
	var fire := _lit_fire(2)
	_state.player.position = Vector2(fire.pos) + Vector2(500.5, 0.5)
	_state.pass_awake_time(LOG_MINUTES)
	assert_eq(Campfire.minutes_left(fire), LOG_MINUTES)


func test_an_out_fire_stays_out_and_burns_no_wood() -> void:
	var fire := _place(WorldObjectTypes.FIREPLACE)
	fire.storage.add(ItemTypes.LOGS, 2)
	_state.pass_awake_time(10 * 60)
	assert_true(Campfire.is_out(fire))
	assert_eq(fire.storage.count_of(ItemTypes.LOGS), 2)


func test_the_camp_fire_burns_down_in_twelve_hours() -> void:
	var camp_fire := _world.object_at(
		CampSite.sleeping_bag_of_seed(SEED) - CampSite.SLEEPING_BAG_OFFSET
	)
	_state.simulation.skip(11 * 60)
	assert_false(Campfire.is_out(camp_fire))
	_state.simulation.skip(60)
	assert_true(Campfire.is_out(camp_fire))


func test_the_burning_is_saved_and_goes_on_after_loading() -> void:
	var fire := _lit_fire(2)
	_state.pass_awake_time(60)
	var restored := RealLoad.of(self, _state)
	restored.world.add_chunk(WorldGenerator.new(SEED).generate_chunk(Chunk.world_to_chunk(_tile)))
	restored.pass_awake_time(2 * LOG_MINUTES)
	assert_true(Campfire.is_out(restored.world.object_at(_tile)))
	assert_eq(Campfire.minutes_left(fire), 2 * LOG_MINUTES - 60, "the first game is as it was")


func test_the_hearth_of_a_house_is_no_campfire_and_burns_for_ever() -> void:
	var hearth := WorldObject.new(WorldObjectTypes.HEARTH, Vector2i.ZERO)
	assert_false(Campfire.is_out(hearth))
	assert_false(hearth.light().is_empty())


func test_a_campfire_that_is_out_is_nothing_to_stand_by() -> void:
	var state := GameState.new_game(7)
	var camp_fire := state.world.object_at(
		CampSite.sleeping_bag_of_seed(7) - CampSite.SLEEPING_BAG_OFFSET
	)
	var npc := Npc.create(1, Vector2(camp_fire.pos) + Vector2(0.5, 1.5), NpcRules.default_rules())
	assert_true(NpcMoment.of(state, npc, 8.0).is_by_fire)
	state.pass_awake_time(12 * 60)
	assert_true(Campfire.is_out(camp_fire))
	assert_false(NpcMoment.of(state, npc, 8.0).is_by_fire)
