extends GutTest
## The deed log: what the player does within sight of villagers is written down once, merged by
## kind, place and day, with who saw it and the place in words, and kept for 7 days.

const NOON := 12 * GameClock.MINUTES_PER_HOUR
const DEEP_NIGHT := 2 * GameClock.MINUTES_PER_HOUR

var _state: GameState
var _spot: Vector2i


func before_each() -> void:
	_state = GameState.new_game(7)
	_state.clock.minute_of_day = NOON
	_spot = _state.player.tile()


## A villager of data/villagers.cfg standing `distance` tiles east of the spot, whose house (the
## anchor) is `house_distance` tiles east of it.
func _villager(villager_id: String, distance: float, house_distance := 500.0) -> Npc:
	var npc := Npc.create_villager(villager_id, Vector2.ZERO, _state.npcs.villagers)
	var spot := Vector2(_spot) + Vector2(0.5, 0.5)
	npc.position = spot + Vector2(distance, 0.0)
	npc.anchor = spot + Vector2(house_distance, 0.0)
	_state.npcs.add(npc)
	return npc


func _fell_a_tree() -> void:
	_state.report(ActionOutcome.BREAK, _spot, WorldObjectTypes.OAK, {ItemTypes.LOGS: 3})


func test_a_felled_tree_seen_by_a_villager_is_written_down() -> void:
	_villager("antje", 5.0)
	_state.clock.day = 3
	_state.clock.minute_of_day = 600

	_fell_a_tree()

	var entry := _state.deeds.entries[0]
	assert_eq(_state.deeds.entries.size(), 1)
	assert_eq(entry["kind"], GossipRules.FELLED)
	assert_eq([entry["day"], entry["minute"], entry["count"]], [3, 600, 1])
	assert_eq(entry["witnesses"], ["Antje Boysen"])


func test_a_deed_no_villager_saw_is_not_written_down() -> void:
	_fell_a_tree()
	_villager("antje", 21.0)
	_fell_a_tree()

	assert_eq(_state.deeds.entries, [] as Array[Dictionary])


func test_every_villager_within_20_tiles_is_a_witness_and_no_one_beyond() -> void:
	var near := _villager("antje", 19.5)
	var far := _villager("hinrich", 20.5)

	_fell_a_tree()

	assert_eq(_state.deeds.entries[0]["witnesses"], [near.name])
	assert_eq(near.stories.size(), 1)
	assert_eq(far.stories, [] as Array[Dictionary])


func test_at_night_a_villager_sees_only_within_6_tiles() -> void:
	var close := _villager("antje", 5.5)
	var farther := _villager("hinrich", 6.5)
	_state.clock.minute_of_day = DEEP_NIGHT

	_fell_a_tree()

	assert_eq(_state.deeds.entries[0]["witnesses"], [close.name])
	assert_eq(farther.stories, [] as Array[Dictionary])


func test_the_same_deed_in_the_same_place_on_the_same_day_merges() -> void:
	_villager("antje", 5.0)
	_state.clock.minute_of_day = 600
	_fell_a_tree()
	var hinrich := _villager("hinrich", 8.0)
	_state.clock.minute_of_day = 700
	_fell_a_tree()
	_fell_a_tree()

	assert_eq(_state.deeds.entries.size(), 1)
	var entry := _state.deeds.entries[0]
	assert_eq(entry["count"], 3)
	assert_eq(entry["minute"], 700)
	assert_eq(entry["witnesses"], ["Antje Boysen", "Hinrich Boysen"])
	assert_eq(hinrich.stories[0]["count"], 2, "told only what they saw")


func test_another_kind_another_place_or_another_day_is_an_entry_of_its_own() -> void:
	_villager("antje", 5.0, 3.0)
	_fell_a_tree()
	_state.report(ActionOutcome.TILL, _spot)
	_state.clock.day += 1
	_fell_a_tree()
	var other_place := _villager("hinrich", 5.0, 1.0)
	other_place.anchor = Vector2(_spot) + Vector2(0.5, 0.5) + Vector2(-1.0, 0.0)
	_fell_a_tree()

	assert_eq(_state.deeds.entries.size(), 4)


func test_a_deed_is_kept_for_7_days() -> void:
	var antje := _villager("antje", 5.0)
	_state.clock.day = 1
	_fell_a_tree()
	_state.clock.day = 7
	_state.report(ActionOutcome.TILL, _spot)
	assert_eq(_state.deeds.entries.size(), 2, "day 1 is the 7th day back on day 7")

	_state.clock.day = 8
	_state.report(ActionOutcome.TILL, _spot)

	assert_eq(_state.deeds.entries.map(func(entry: Dictionary) -> int: return entry["day"]), [7, 8])
	assert_eq(antje.stories.size(), 3, "the stories stay in the buffer")


func test_a_deed_is_forgotten_when_the_days_pass_without_a_new_one() -> void:
	var antje := _villager("antje", 5.0)
	_fell_a_tree()

	_state.clock.advance(6 * GameClock.MINUTES_PER_DAY)
	assert_eq(_state.deeds.entries.size(), 1, "the 7th day it is")

	_state.clock.advance(GameClock.MINUTES_PER_DAY)
	assert_eq(_state.deeds.entries, [] as Array[Dictionary])
	assert_eq(antje.stories.size(), 1, "the story stays in the gossip buffer")


func test_what_has_grown_old_is_forgotten_when_a_game_is_loaded() -> void:
	var old := {
		"day": 1, "minute": 600, "kind": "felled", "count": 2, "place": "x", "witnesses": []
	}
	var recent := old.duplicate(true)
	recent["day"] = 20
	_state.clock.day = 20

	_state.deeds.load_array([old, recent])

	assert_eq(_state.deeds.entries.size(), 1)
	assert_eq(_state.deeds.entries[0]["day"], 20)


func test_the_place_is_the_house_of_the_villager_with_the_nearest_home() -> void:
	_villager("antje", 3.0, 15.0)
	_villager("hinrich", 3.0, 8.0)

	_fell_a_tree()

	assert_eq(_state.deeds.entries[0]["place"], "by Hinrich's house")


func test_with_no_house_within_20_tiles_the_place_is_the_ground() -> void:
	_villager("antje", 3.0, 25.0)
	var terrain := _state.world.tile_at(_spot).terrain

	_fell_a_tree()

	assert_eq(_state.deeds.entries[0]["place"], _state.deeds.rules.ground_place(terrain))


func test_a_witness_is_told_the_deed_as_a_story() -> void:
	var antje := _villager("antje", 3.0, 4.0)
	_state.clock.day = 5
	_state.clock.minute_of_day = 650

	_fell_a_tree()

	assert_eq(
		antje.stories,
		(
			[
				{
					"day": 5,
					"minute": 650,
					"kind": GossipRules.FELLED,
					"count": 1,
					"place": "by Antje's house",
					"origin": "5|felled|by Antje's house",
					"how": GossipRules.SEEN,
					"told_by": "",
					"seen_by": "Antje Boysen",
					"hops": 0,
					"learned_at": 4 * GameClock.MINUTES_PER_DAY + 650,
					"line": "",
					"is_judged": false,
					"weight": MemoryWeight.HIGH,
					"personal": true,
				}
			]
			as Array[Dictionary]
		)
	)


func test_a_deed_inside_a_house_is_not_seen() -> void:
	_villager("antje", 1.0)
	_state.action_done.emit(ActionOutcome.new(ActionOutcome.BUILD, GameMap.new(), _spot))

	assert_eq(_state.deeds.entries, [] as Array[Dictionary])


func test_the_finished_actions_that_are_deeds() -> void:
	var cases := [
		[ActionOutcome.TILL, &"", {}, GossipRules.TILLED],
		[ActionOutcome.PLANT, WorldObjectTypes.TURNIP, {}, GossipRules.SOWED],
		[ActionOutcome.PLANT, WorldObjectTypes.SAPLING, {}, &""],
		[ActionOutcome.HARVEST, WorldObjectTypes.TURNIP, {}, GossipRules.HARVESTED],
		[ActionOutcome.MOW, &"", {}, GossipRules.MOWED],
		[ActionOutcome.DIG, &"", {ItemTypes.CLAY: 2}, GossipRules.DUG_CLAY],
		[ActionOutcome.DIG, &"", {}, &""],
		[ActionOutcome.DIG, WorldObjectTypes.BERRY_BUSH, {&"berry_bush": 1}, &""],
		[ActionOutcome.BREAK, WorldObjectTypes.OAK, {}, GossipRules.FELLED],
		[ActionOutcome.BREAK, WorldObjectTypes.STONE, {}, &""],
		[ActionOutcome.HIT, WorldObjectTypes.OAK, {}, &""],
		[ActionOutcome.PLACE, WorldObjectTypes.WATTLE_FENCE, {}, GossipRules.FENCED],
		[ActionOutcome.PLACE, WorldObjectTypes.CHEST, {}, &""],
		[ActionOutcome.TAKE_DOWN, WorldObjectTypes.CHEST, {}, &""],
		[ActionOutcome.BUILD, BuildingTypes.KATE, {}, GossipRules.BUILT],
		[ActionOutcome.DEMOLISH, BuildingTypes.KATE, {}, GossipRules.TOOK_DOWN],
		[ActionOutcome.EAT, &"", {}, &""],
	]
	for deed: Array in cases:
		var outcome := ActionOutcome.new(deed[0], _state.world, _spot, deed[1], deed[2])
		assert_eq(DeedLog.kind_of(outcome), deed[3], "%s of %s" % [deed[0], deed[1]])


func test_a_deed_by_their_own_house_or_that_of_family_or_friends_weighs_high() -> void:
	var antje := _villager("antje", 3.0, 20.0)
	var hinrich := _villager("hinrich", 3.0, 2.0)
	var stranger := Npc.create(7, Vector2.ZERO, _state.npcs.rules)
	stranger.position = Vector2(_spot) + Vector2(0.5, 0.5) + Vector2(4.0, 0.0)
	stranger.anchor = Vector2(_spot) + Vector2(0.5, 0.5) + Vector2(500.0, 0.0)
	_state.npcs.add(stranger)

	_fell_a_tree()

	assert_eq(hinrich.stories[0]["weight"], MemoryWeight.HIGH, "their own house")
	assert_true(hinrich.stories[0]["personal"])
	assert_eq(antje.stories[0]["weight"], MemoryWeight.HIGH, "her husband's house")
	assert_eq(stranger.stories[0]["weight"], MemoryWeight.MEDIUM, "someone else's house")
	assert_false(stranger.stories[0]["personal"])


func test_a_deed_on_the_open_ground_weighs_medium() -> void:
	var antje := _villager("antje", 3.0, 25.0)

	_fell_a_tree()

	assert_eq(antje.stories[0]["weight"], MemoryWeight.MEDIUM)


func test_the_gossip_buffer_is_as_long_as_the_setting_and_the_oldest_leaves() -> void:
	var antje := _villager("antje", 5.0, 25.0)
	_state.deeds.stories_kept = 2
	for day in range(1, 5):
		_state.clock.day = day
		_fell_a_tree()

	assert_eq(antje.stories.map(func(story: Dictionary) -> int: return story["day"]), [3, 4])
	assert_eq(antje.memories.size(), 2, "the two that left are remembered, of medium weight")
	assert_eq(antje.memories[0]["day"], 1)
	assert_eq(antje.memories[0]["weight"], MemoryWeight.MEDIUM)
	var ground := _state.deeds.rules.ground_place(_state.world.tile_at(_spot).terrain)
	assert_eq(antje.memories[0]["text"], "On day 1: you saw the newcomer fell a tree %s." % ground)
