extends GutTest
## Stealing, damage and rudeness (Harm): whose things are whose, what is seen and what is not, the
## points the witnesses lose, the caps, and what the player's own things cost. Run in the village
## of seed 1, where the villagers have their houses.

var _state: GameState
var _antje: Npc
var _gesche: Npc
## A tile on the village's land by Antje's house.
var _tile: Vector2i
var _friendship := FriendshipRules.default_rules()


func before_each() -> void:
	_state = GameState.new_game(1, true)
	_antje = _state.npcs.find("antje")
	_gesche = _state.npcs.find("gesche")
	_tile = Vector2i(_antje.anchor)
	_state.clock.minute_of_day = 12 * GameClock.MINUTES_PER_HOUR
	_state.player.position = Vector2(_tile) + Vector2(5.5, 0.5)
	for npc in _state.npcs.all():
		_send_far_away(npc)


func _send_far_away(npc: Npc) -> void:
	npc.position = Vector2(9000, 9000)


func _stand_by_the_tile(npc: Npc, tiles_away := 1.0) -> void:
	npc.position = Vector2(_tile) + Vector2(0.5 + tiles_away, 0.5)


func _cut_the_knick() -> void:
	_state.report(ActionOutcome.BREAK, _tile, WorldObjectTypes.KNICK, {ItemTypes.LOGS: 1})


func _kinds_logged() -> Array:
	return _state.deeds.entries.map(func(entry: Dictionary) -> StringName: return entry["kind"])


func test_the_village_is_there() -> void:
	assert_not_null(_state.world.village)
	assert_not_null(_antje)
	assert_true(_state.world.is_village_land(_tile))


func test_a_thing_by_a_house_is_its_villagers_and_one_far_away_is_nobodys() -> void:
	assert_eq(_state.harm.owner_of(_state.world, _tile), _antje, "first of her household")
	assert_null(_state.harm.owner_of(_state.world, _tile + Vector2i(500, 500)))


func test_a_thing_inside_a_house_is_its_residents() -> void:
	var house := _antje.house
	var inside := house.inside()

	assert_eq(_state.harm.owner_of(inside, Vector2i(1, 1)), _antje)


func test_which_actions_are_harm() -> void:
	var cases := [
		[ActionOutcome.BREAK, WorldObjectTypes.KNICK, GossipRules.DAMAGED],
		[ActionOutcome.BREAK, WorldObjectTypes.WATTLE_FENCE, GossipRules.DAMAGED],
		[ActionOutcome.TAKE_DOWN, WorldObjectTypes.STONE_WALL, GossipRules.DAMAGED],
		[ActionOutcome.BREAK, WorldObjectTypes.STONE_PATH, &""],
		[ActionOutcome.BREAK, &"oak", &""],
		[ActionOutcome.HARVEST, &"turnip", GossipRules.STOLE],
		[ActionOutcome.COLLECT, &"nest", GossipRules.STOLE],
		[ActionOutcome.TAKE_FROM_CHEST, WorldObjectTypes.CHEST, GossipRules.STOLE],
		[ActionOutcome.TILL, &"", &""],
	]
	for entry in cases:
		var outcome := ActionOutcome.new(entry[0], _state.world, _tile, entry[1])
		assert_eq(Harm.kind_of(outcome), entry[2], "%s of %s" % [entry[0], entry[1]])


func test_a_harm_that_is_seen_costs_each_witness_its_points() -> void:
	_stand_by_the_tile(_antje)
	_stand_by_the_tile(_gesche, 3.0)

	_cut_the_knick()

	var points := _friendship.harm_points(GossipRules.DAMAGED)
	assert_eq(_antje.opinion, points)
	assert_eq(_gesche.opinion, points, "who saw it, though it is not theirs")
	assert_has(_kinds_logged(), GossipRules.DAMAGED)
	assert_eq(_antje.stories.back()["kind"], GossipRules.DAMAGED)


func test_a_harm_nobody_sees_costs_nothing_the_owner_included() -> void:
	_cut_the_knick()

	assert_eq(_antje.opinion, 0)
	assert_eq(_gesche.opinion, 0)
	assert_false(_kinds_logged().has(GossipRules.DAMAGED))


func test_when_the_owner_is_away_those_who_saw_lose_it_and_the_owner_does_not() -> void:
	_stand_by_the_tile(_gesche, 2.0)

	_cut_the_knick()

	assert_eq(_gesche.opinion, _friendship.harm_points(GossipRules.DAMAGED))
	assert_eq(_antje.opinion, 0)


func test_at_night_a_villager_sees_less_far() -> void:
	_state.clock.minute_of_day = 23 * GameClock.MINUTES_PER_HOUR
	var night_radius := GossipRules.default_rules().radius(true)
	_stand_by_the_tile(_gesche, night_radius + 2.0)

	_cut_the_knick()

	assert_eq(_gesche.opinion, 0)


func test_stealing_costs_more_than_damage() -> void:
	_stand_by_the_tile(_antje)

	_state.report(ActionOutcome.HARVEST, _tile, &"turnip", {ItemTypes.TURNIP: 2})

	assert_eq(_antje.opinion, _friendship.harm_points(GossipRules.STOLE))
	assert_lt(
		_friendship.harm_points(GossipRules.STOLE), _friendship.harm_points(GossipRules.DAMAGED)
	)


func test_harm_counts_within_the_cap_of_the_actions() -> void:
	_stand_by_the_tile(_antje)

	for round in 3:
		_state.report(ActionOutcome.HARVEST, _tile, &"turnip", {ItemTypes.TURNIP: 1})

	assert_eq(_antje.opinion, -_friendship.action_daily_cap())


func test_the_players_own_things_cost_nothing() -> void:
	var far_away := _tile + Vector2i(500, 500)
	_stand_by_the_tile(_antje)

	_state.report(ActionOutcome.BREAK, far_away, WorldObjectTypes.KNICK, {ItemTypes.LOGS: 1})
	_state.report(ActionOutcome.HARVEST, far_away, &"turnip", {ItemTypes.TURNIP: 1})

	assert_eq(_antje.opinion, 0)


func test_walking_through_a_villager_is_rude_once_a_day() -> void:
	var feet := Vector2(_tile) + Vector2(0.5, 0.5)
	_stand_by_the_tile(_antje, 0.2)
	_stand_by_the_tile(_gesche, 4.0)

	_state.harm.check_pushing(feet)
	_state.harm.check_pushing(feet)

	var points := _friendship.harm_points(GossipRules.RUDE)
	assert_eq(_antje.opinion, points, "once")
	assert_eq(_gesche.opinion, points, "who saw it")
	assert_has(_kinds_logged(), GossipRules.RUDE)

	_state.clock.advance(GameClock.MINUTES_PER_DAY)
	_state.harm.check_pushing(feet)
	assert_eq(_antje.opinion, 2 * points, "again the next day")


func test_keeping_out_of_a_villagers_way_is_not_rude() -> void:
	_stand_by_the_tile(_antje, 1.0)

	_state.harm.check_pushing(Vector2(_tile) + Vector2(0.5, 0.5))

	assert_eq(_antje.opinion, 0)


func test_walking_checks_for_pushing() -> void:
	_state.player.position = Vector2(_tile) + Vector2(0.5, 0.5)
	_stand_by_the_tile(_antje, 0.1)

	_state.walk(Vector2.ZERO, 0.1)

	assert_eq(_antje.opinion, _friendship.harm_points(GossipRules.RUDE))


func test_the_stories_of_harm_are_whispered_into_another_kind() -> void:
	assert_true(SpreadRules.default_rules().is_valid(), str(SpreadRules.default_rules().problems()))
	assert_true(GossipRules.default_rules().is_valid())
