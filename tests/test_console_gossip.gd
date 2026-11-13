extends GutTest
## The console's `gossip` command lists the stories and the memories of a villager.

var _state: GameState
var _console: Console
var _antje: Npc


func before_each() -> void:
	_state = GameState.new_game(7)
	_console = Console.new(_state)
	_antje = Npc.create_villager("antje", Vector2.ZERO, _state.npcs.villagers)
	_state.npcs.add(_antje)


func test_a_villager_with_nothing_kept_says_so() -> void:
	assert_eq(
		_console.run("gossip antje"),
		[
			"Antje Boysen keeps 0 of 10 stories and 0 of 20 memories",
			"Knows 7 of 7 topics of the village: village, places, people, money, news, calendar, world",
		]
	)


func test_it_lists_the_topics_of_the_village_a_villager_knows() -> void:
	var other := Npc.create(42, Vector2.ZERO, _state.npcs.rules)
	_state.npcs.add(other)
	var first_name := other.name.get_slice(" ", 0).to_lower()

	assert_eq(_console.run("gossip " + first_name)[1], "Knows no topic of the village")

	other.topics.assign(["village", "places"])

	assert_eq(
		_console.run("gossip " + first_name)[1],
		"Knows 2 of 7 topics of the village: village, places"
	)


func test_it_lists_the_stories_and_memories_with_their_weights() -> void:
	_antje.add_memory("On the 1st day: a talk.", 1, MemoryWeight.MEDIUM, 20)
	(
		_antje
		. stories
		. append(
			{
				"day": 4,
				"minute": 600,
				"kind": GossipRules.FELLED,
				"count": 7,
				"place": "by Antje's house",
				"how": GossipRules.SEEN,
				"told_by": "",
				"line": "",
				"weight": MemoryWeight.HIGH,
			}
		)
	)
	(
		_antje
		. stories
		. append(
			{
				"day": 5,
				"minute": 600,
				"kind": GossipRules.TILLED,
				"count": 1,
				"place": "here",
				"how": GossipRules.HEARD,
				"told_by": "Moiken Jessen",
				"line": "",
				"weight": MemoryWeight.LOW,
			}
		)
	)

	assert_eq(
		_console.run("gossip antje"),
		[
			"Antje Boysen keeps 2 of 10 stories and 1 of 20 memories",
			"Knows 7 of 7 topics of the village: village, places, people, money, news, calendar, world",
			"Story, high, seen: On day 4: you saw the newcomer fell 7 trees by Antje's house.",
			(
				"Story, low, heard from Moiken Jessen: On day 5: Moiken told you that the newcomer"
				+ " was seen to till a patch of ground here."
			),
			"Memory, medium, day 1: On the 1st day: a talk.",
		]
	)


func test_a_made_up_villager_is_found_by_first_name() -> void:
	var other := Npc.create(42, Vector2.ZERO, _state.npcs.rules)
	_state.npcs.add(other)
	var first_name := other.name.get_slice(" ", 0).to_lower()

	assert_string_starts_with(_console.run("gossip " + first_name)[0], other.name)


func test_an_unknown_villager_or_no_villager_is_refused() -> void:
	assert_eq(_console.run("gossip nobody")[0], "Unknown villager: nobody")
	assert_eq(_console.run("gossip"), ["Usage: gossip <villager>"])
