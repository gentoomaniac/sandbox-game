extends ResourceCase
## An outdoor fire (Campfire): the camp starts lit with wood, a fire the player sets up is out, wood
## goes into its slot, lighting it takes a log out of the slot, and the words tell how it is doing.

const LOG_MINUTES := 180


func _camp_fire() -> WorldObject:
	return _world.object_at(CampSite.sleeping_bag_of_seed(SEED) - CampSite.SLEEPING_BAG_OFFSET)


func _put_wood(fire: WorldObject, logs: int) -> void:
	fire.storage.add(ItemTypes.LOGS, logs)


func test_the_camp_fire_of_a_new_game_burns_on_four_logs() -> void:
	var camp_fire := _camp_fire()
	assert_false(Campfire.is_out(camp_fire))
	assert_eq(Campfire.minutes_left(camp_fire), 4 * LOG_MINUTES)
	assert_eq(camp_fire.storage.count_of(ItemTypes.LOGS), 3, "one is burning")
	assert_false(camp_fire.light().is_empty())


func test_a_fireplace_put_down_is_out_and_dark_with_a_slot_for_wood() -> void:
	var fire := _place(WorldObjectTypes.FIREPLACE)
	assert_true(Campfire.is_out(fire))
	assert_true(fire.light().is_empty(), "no light")
	assert_eq(fire.storage.slots.size(), 1)
	assert_false(Campfire.can_light(fire), "no wood")


func test_a_fire_with_wood_is_lit_by_the_player_and_takes_a_log_out_of_the_slot() -> void:
	var fire := _place(WorldObjectTypes.FIREPLACE)
	_put_wood(fire, 2)
	assert_true(Campfire.can_light(fire))
	_state.light_campfire(fire)
	assert_false(Campfire.is_out(fire))
	assert_eq(Campfire.minutes_left(fire), 2 * LOG_MINUTES)
	assert_eq(fire.storage.count_of(ItemTypes.LOGS), 1)
	assert_false(fire.light().is_empty())
	assert_false(Campfire.can_light(fire), "it burns already")


func test_lighting_a_fire_with_no_wood_does_nothing() -> void:
	var fire := _place(WorldObjectTypes.FIREPLACE)
	_state.light_campfire(fire)
	assert_true(Campfire.is_out(fire))


func test_only_wood_burns() -> void:
	assert_eq(Campfire.burn_minutes_of(ItemTypes.LOGS), LOG_MINUTES)
	assert_eq(Campfire.burn_minutes_of(ItemTypes.STONE), 0)


func test_the_words_tell_how_much_wood_is_left() -> void:
	var fire := _place(WorldObjectTypes.FIREPLACE)
	assert_eq(Campfire.state_text(fire), "Campfire, out: no wood")
	_put_wood(fire, 2)
	assert_eq(Campfire.state_text(fire), "Campfire, out: wood for about 6 hours")
	_state.light_campfire(fire)
	assert_eq(Campfire.state_text(fire), "Campfire, burning: wood for about 6 hours")
	fire.state[Campfire.LOG_LEFT] = 61
	fire.storage.take_from(0, 1)
	assert_eq(Campfire.state_text(fire), "Campfire, burning low: wood for about 2 hours")
	fire.state[Campfire.LOG_LEFT] = 60
	assert_eq(Campfire.state_text(fire), "Campfire, burning low: wood for about 1 hour")
	assert_eq(_state.object_text_at(_tile), Campfire.state_text(fire))


func test_the_wood_and_the_flame_are_kept_when_the_world_is_saved_and_loaded() -> void:
	var fire := _place(WorldObjectTypes.FIREPLACE)
	_put_wood(fire, 3)
	_state.light_campfire(fire)
	var restored := GameState.from_dict(JSON.parse_string(JSON.stringify(_state.to_dict())))
	restored.world.add_chunk(WorldGenerator.new(SEED).generate_chunk(Chunk.world_to_chunk(_tile)))
	var kept := restored.world.object_at(_tile)
	assert_false(Campfire.is_out(kept))
	assert_eq(Campfire.minutes_left(kept), 3 * LOG_MINUTES)
	assert_eq(kept.storage.count_of(ItemTypes.LOGS), 2)


func test_taking_the_fire_down_gives_the_wood_in_it() -> void:
	var fire := _place(WorldObjectTypes.FIREPLACE)
	_put_wood(fire, 5)
	var gives := ToolUse.new(_state).items_of_placed(fire)
	assert_eq(gives, {ItemTypes.LOGS: 5, ItemTypes.FIREPLACE: 1})
