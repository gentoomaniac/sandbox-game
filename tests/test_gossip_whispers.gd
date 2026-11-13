extends GutTest
## A story may change as it is passed on (GossipSpread, "Whispers"): the count grows, the place
## moves to a neighbour's house or the kind turns into a similar one, by seeded dice.

const HEARERS := 40

var _state: GameState
var _spread: GossipSpread
var _teller: Npc
var _hearers: Array[Npc] = []


func before_each() -> void:
	_new_village()


## A new game with the teller and the hearers close together, and dice seeded the same each time.
func _new_village() -> void:
	_state = GameState.new_game(7)
	_state.clock.day = 3
	_spread = GossipSpread.new(_state.npcs, _state.deeds)
	_spread.rng.seed = 11
	_teller = _villager("Moiken", 0.0, 0.0)
	_hearers.clear()
	for index in HEARERS:
		_hearers.append(_villager("Hearer%d" % index, 1.0, 100.0 + index))


## The rules of the data file, where the villagers always tell (the whispers are what is tested)
## and a story changes with `whisper_chance`.
func _use_rules(whisper_chance: float) -> void:
	var values := DataFile.read_sections(GossipRules.DEFAULT_PATH)
	for tie in SpreadRules.TIES:
		values["meetings"]["chance_" + str(tie)] = 1.0
	values["whispers"]["chance"] = whisper_chance
	_spread.rules = SpreadRules.new(values)


func _villager(first_name: String, x: float, anchor_x: float) -> Npc:
	var npc := Npc.new(first_name + " Test", &"female", Appearance.new(), Vector2(x, 0.0))
	npc.anchor = Vector2(anchor_x, 0.0)
	_state.npcs.add(npc)
	return npc


## The teller knows 7 trees felled "here", and tells them to every hearer at once.
func _tell_the_story_of(count := 7) -> void:
	(
		_teller
		. stories
		. append(
			{
				"day": 3,
				"minute": 600,
				"kind": GossipRules.FELLED,
				"count": count,
				"place": "here",
				"origin": "3|felled|here",
				"how": GossipRules.SEEN,
				"told_by": "",
				"seen_by": "Moiken Test",
				"hops": 0,
				"learned_at": 0,
				"line": "",
				"weight": MemoryWeight.HIGH,
				"personal": false,
			}
		)
	)
	_state.clock.minute_of_day = 12 * GameClock.MINUTES_PER_HOUR
	_spread.advance(1, _state.clock)


## What each hearer's version changed, as the names of the facts: count, place, kind.
func _changes(count := 7) -> Array[Array]:
	var changes: Array[Array] = []
	for hearer in _hearers:
		var story := hearer.stories[0]
		var changed := []
		if story["count"] != count:
			changed.append("count")
		if story["place"] != "here":
			changed.append("place")
		if story["kind"] != GossipRules.FELLED:
			changed.append("kind")
		changes.append(changed)
	return changes


func test_a_story_that_is_not_whispered_is_told_as_it_was() -> void:
	_use_rules(0.0)

	_tell_the_story_of()

	for changed in _changes():
		assert_eq(changed, [])


func test_a_whisper_changes_one_thing_and_each_of_the_three_turns_up() -> void:
	_use_rules(1.0)

	_tell_the_story_of()

	var seen := {}
	for changed in _changes():
		assert_eq(changed.size(), 1, "one thing shifts: %s" % [changed])
		seen[changed[0]] = true
	assert_eq(seen.keys().size(), 3, "count, place and kind all shift sometimes")


func test_a_whisper_follows_the_steps_the_neighbours_and_the_kinds_of_the_table() -> void:
	_use_rules(1.0)
	var places := ["here", "by Hearer0's house", "by Hearer1's house", "by Hearer2's house"]

	_tell_the_story_of()

	for hearer in _hearers:
		var story := hearer.stories[0]
		assert_true([7, 10].has(story["count"]), str(story))
		assert_true(places.has(story["place"]), str(story))
		assert_true([GossipRules.FELLED, GossipRules.MOWED].has(story["kind"]), str(story))


func test_a_count_past_the_last_step_does_not_grow() -> void:
	_use_rules(1.0)

	_tell_the_story_of(100)

	assert_false(_changes(100).any(func(changed: Array) -> bool: return changed.has("count")))


func test_a_whisper_keeps_what_names_the_story() -> void:
	_use_rules(1.0)

	_tell_the_story_of()

	for hearer in _hearers:
		assert_eq(hearer.stories[0]["origin"], "3|felled|here")
		assert_eq(hearer.stories[0]["hops"], 1)


func test_the_same_seed_whispers_the_same() -> void:
	_use_rules(1.0)
	_tell_the_story_of()
	var first := _changes()

	_new_village()
	_use_rules(1.0)
	_tell_the_story_of()

	assert_eq(_changes(), first)
