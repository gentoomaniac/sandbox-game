extends GutTest
## Stories pass between villagers who meet (GossipSpread): who meets, what is told, when, and the
## chances by how the two are tied.

const NOON := 12 * GameClock.MINUTES_PER_HOUR
const TWO_HOURS := 120

var _state: GameState
var _spread: GossipSpread


func before_each() -> void:
	_state = GameState.new_game(7)
	_state.clock.day = 3
	_state.clock.minute_of_day = NOON
	_spread = GossipSpread.new(_state.npcs, _state.deeds)
	_spread.rng.seed = 1
	_spread.rules = _rules({})


## The rules of the data file with every chance of telling 1.0, except what `meetings` changes, and
## no whispers (see test_gossip_whispers.gd).
func _rules(meetings: Dictionary) -> SpreadRules:
	var values := DataFile.read_sections(GossipRules.DEFAULT_PATH)
	for tie in SpreadRules.TIES:
		values["meetings"]["chance_" + str(tie)] = 1.0
	values["meetings"].merge(meetings, true)
	values["whispers"]["chance"] = 0.0
	return SpreadRules.new(values)


## A villager at `x` tiles east of the origin, whose anchor is at `anchor_x`.
func _villager(first_name: String, x: float, anchor_x := 0.0) -> Npc:
	var npc := Npc.new(first_name + " Test", &"female", Appearance.new(), Vector2(x, 0.0))
	npc.anchor = Vector2(anchor_x, 0.0)
	_state.npcs.add(npc)
	return npc


## A story of felled trees, as the villager `seer` saw it on `day`, that the one who has it learned
## `age` minutes ago.
func _story(day: int, weight: int, age := TWO_HOURS, hops := 0, place := "here") -> Dictionary:
	return {
		"day": day,
		"minute": 600,
		"kind": GossipRules.FELLED,
		"count": 7,
		"place": place,
		"origin": "%d|felled|%s" % [day, place],
		"how": GossipRules.SEEN if hops == 0 else GossipRules.HEARD,
		"told_by": "" if hops == 0 else "Someone Else",
		"seen_by": "Seer Test",
		"hops": hops,
		"learned_at": _state.clock.total_minutes() - age,
		"line": "",
		"is_judged": true,
		"weight": weight,
		"personal": false,
	}


func _meet_now() -> void:
	_spread.advance(1, _state.clock)


func _origins(npc: Npc) -> Array:
	return npc.stories.map(func(story: Dictionary) -> String: return story["origin"])


func test_a_story_known_for_two_hours_is_heard_by_a_villager_close_by() -> void:
	var teller := _villager("Moiken", 0.0)
	var hearer := _villager("Antje", 2.5)
	teller.stories.append(_story(3, MemoryWeight.HIGH))

	_meet_now()

	assert_eq(hearer.stories.size(), 1)
	var heard := hearer.stories[0]
	assert_eq(heard["how"], GossipRules.HEARD)
	assert_eq(heard["told_by"], "Moiken Test")
	assert_eq(heard["seen_by"], "Seer Test")
	assert_eq(heard["hops"], 1)
	assert_eq(heard["learned_at"], _state.clock.total_minutes())
	assert_eq(heard["weight"], MemoryWeight.LOW)
	assert_false(heard["is_judged"], "the hearer has still to judge it")
	assert_eq([heard["day"], heard["kind"], heard["count"]], [3, GossipRules.FELLED, 7])
	assert_eq(teller.stories.size(), 1, "the teller keeps theirs")


func test_a_story_known_for_less_than_two_hours_is_not_told_yet() -> void:
	var teller := _villager("Moiken", 0.0)
	var hearer := _villager("Antje", 1.0)
	teller.stories.append(_story(3, MemoryWeight.HIGH, TWO_HOURS - 1))

	_meet_now()

	assert_eq(hearer.stories, [] as Array[Dictionary])


func test_villagers_beyond_three_tiles_do_not_meet() -> void:
	var teller := _villager("Moiken", 0.0)
	var hearer := _villager("Antje", 3.5)
	teller.stories.append(_story(3, MemoryWeight.HIGH))

	_meet_now()

	assert_eq(hearer.stories, [] as Array[Dictionary])


func test_villagers_close_across_the_edge_of_a_grid_cell_meet() -> void:
	var teller := _villager("Moiken", 2.9)
	var hearer := _villager("Antje", 3.1)
	teller.stories.append(_story(3, MemoryWeight.HIGH))

	_meet_now()

	assert_eq(_origins(hearer), _origins(teller))


func test_in_a_large_village_only_those_standing_close_meet() -> void:
	var far: Array[Npc] = []
	for index in 150:
		far.append(_villager("Far%d" % index, 100.0 + index * 4.0))
	var teller := _villager("Moiken", -1.0)
	var hearer := _villager("Antje", 1.0)
	teller.stories.append(_story(3, MemoryWeight.HIGH))
	far[0].stories.append(_story(2, MemoryWeight.HIGH))

	_meet_now()

	assert_eq(_origins(hearer), _origins(teller))
	for npc in far.slice(1):
		assert_eq(npc.stories, [] as Array[Dictionary], "4 tiles apart is too far")


func test_both_may_tell_at_one_meeting() -> void:
	var first := _villager("Moiken", 0.0)
	var second := _villager("Antje", 1.0)
	first.stories.append(_story(2, MemoryWeight.MEDIUM))
	second.stories.append(_story(3, MemoryWeight.MEDIUM))

	_meet_now()

	assert_eq(_origins(first), ["2|felled|here", "3|felled|here"])
	assert_eq(_origins(second), ["3|felled|here", "2|felled|here"])


func test_a_pair_meets_at_most_once_an_hour() -> void:
	var teller := _villager("Moiken", 0.0)
	var hearer := _villager("Antje", 1.0)
	teller.stories.append(_story(3, MemoryWeight.MEDIUM, 500, 0, "here"))
	_meet_now()
	teller.stories.append(_story(3, MemoryWeight.MEDIUM, 500, 0, "there"))

	_state.clock.advance(59)
	_meet_now()
	assert_eq(_origins(hearer), ["3|felled|here"])

	_state.clock.advance(1)
	_meet_now()
	assert_eq(_origins(hearer), ["3|felled|here", "3|felled|there"])


func test_one_story_is_passed_the_weightiest_then_the_newest() -> void:
	var teller := _villager("Moiken", 0.0)
	var hearer := _villager("Antje", 1.0)
	teller.stories.append(_story(2, MemoryWeight.HIGH, TWO_HOURS, 0, "old and heavy"))
	teller.stories.append(_story(3, MemoryWeight.MEDIUM, TWO_HOURS, 0, "light"))
	teller.stories.append(_story(3, MemoryWeight.HIGH, TWO_HOURS, 0, "new and heavy"))

	_meet_now()

	assert_eq(_origins(hearer), ["3|felled|new and heavy"])


func test_a_story_the_hearer_already_knows_is_not_told_again_nor_one_that_changed() -> void:
	var teller := _villager("Moiken", 0.0)
	var hearer := _villager("Antje", 1.0)
	var known := _story(3, MemoryWeight.HIGH)
	teller.stories.append(known)
	var as_heard := known.duplicate()
	as_heard["place"] = "somewhere else"
	hearer.stories.append(as_heard)
	teller.stories.append(_story(2, MemoryWeight.LOW, TWO_HOURS, 0, "another"))

	_meet_now()

	assert_eq(_origins(hearer), ["3|felled|here", "2|felled|another"])
	assert_eq(hearer.stories[0]["place"], "somewhere else", "left as the hearer had it")


func test_a_story_stops_after_three_hops() -> void:
	var teller := _villager("Moiken", 0.0)
	var hearer := _villager("Antje", 1.0)
	teller.stories.append(_story(3, MemoryWeight.HIGH, TWO_HOURS, 3))
	teller.stories.append(_story(2, MemoryWeight.LOW, TWO_HOURS, 2, "second hand"))

	_meet_now()

	assert_eq(_origins(hearer), ["2|felled|second hand"])
	assert_eq(hearer.stories[0]["hops"], 3)


func test_a_deed_of_seven_days_ago_is_not_told() -> void:
	var teller := _villager("Moiken", 0.0)
	var hearer := _villager("Antje", 1.0)
	teller.stories.append(_story(-4, MemoryWeight.HIGH))
	teller.stories.append(_story(-3, MemoryWeight.LOW, TWO_HOURS, 0, "six days old"))

	_meet_now()

	assert_eq(_origins(hearer), ["-3|felled|six days old"])


func test_the_chance_to_tell_follows_how_the_two_are_tied() -> void:
	var teller := _villager("Moiken", 0.0, 0.0)
	teller.id = "moiken"
	var friend := _villager("Friend", 1.0, 100.0)
	teller.people = {"friend": ["friend", ""]}
	friend.id = "friend"
	var neighbour := _villager("Neighbour", 1.0, 1.0)
	var stranger := _villager("Stranger", 1.0, 50.0)
	for near in 3:
		_villager("Near" + str(near), 40.0 + near, 2.0 + near)
	teller.stories.append(_story(3, MemoryWeight.HIGH))
	_spread.rules = _rules(
		{"chance_family": 1.0, "chance_neighbour": 0.0, "chance_anyone": 0.0, "neighbours": 3}
	)

	_meet_now()

	assert_eq(friend.stories.size(), 1, "family and friends")
	assert_eq(neighbour.stories.size(), 0, "a neighbour, but the chance is 0")
	assert_eq(stranger.stories.size(), 0)

	_spread.rules = _rules(
		{"chance_family": 0.0, "chance_neighbour": 1.0, "chance_anyone": 0.0, "neighbours": 3}
	)
	_state.clock.advance(60)
	_meet_now()
	assert_eq(neighbour.stories.size(), 1, "one of the three nearest anchors")
	assert_eq(stranger.stories.size(), 0, "a stranger, the chance is 0")

	_spread.rules = _rules(
		{"chance_family": 0.0, "chance_neighbour": 0.0, "chance_anyone": 1.0, "neighbours": 3}
	)
	_state.clock.advance(60)
	_meet_now()
	assert_eq(stranger.stories.size(), 1)


func test_the_dice_decide_a_middling_chance_and_the_same_seed_decides_the_same() -> void:
	var told: Array[int] = []
	for _run in 2:
		_state = GameState.new_game(7)
		_state.clock.day = 3
		_state.clock.minute_of_day = NOON
		_spread = GossipSpread.new(_state.npcs, _state.deeds)
		_spread.rng.seed = 5
		_spread.rules = _rules({"chance_anyone": 0.5})
		var teller := _villager("Moiken", 0.0)
		var heard := 0
		for index in 20:
			var hearer := _villager("Hearer" + str(index), 1.0, 500.0 + index)
			teller.stories.append(_story(3, MemoryWeight.HIGH))
			_meet_now()
			heard += hearer.stories.size()
			teller.stories.clear()
		told.append(heard)
	assert_between(told[0], 3, 17)
	assert_eq(told[0], told[1])


func test_villagers_far_from_the_player_meet_too() -> void:
	var teller := _villager("Moiken", 5000.0)
	var hearer := _villager("Antje", 5001.0)
	teller.stories.append(_story(3, MemoryWeight.HIGH))

	_meet_now()

	assert_eq(hearer.stories.size(), 1)


func test_the_simulation_lets_villagers_meet_as_time_passes() -> void:
	var teller := _villager("Moiken", 0.0)
	var hearer := _villager("Antje", 1.0)
	teller.id = "moiken"
	teller.people = {"antje": ["friend", ""]}
	hearer.id = "antje"
	teller.stories.append(_story(3, MemoryWeight.HIGH))

	# The chance between friends is 0.8 in the file and the game's dice are not seeded: a day of
	# hourly meetings is sure enough.
	_state.simulation.advance(GameClock.MINUTES_PER_DAY)

	assert_eq(hearer.stories.size(), 1)
