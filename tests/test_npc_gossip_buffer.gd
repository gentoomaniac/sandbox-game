extends GutTest
## The gossip buffer of a villager (Npc `stories`): first in, first out. What leaves is forgotten
## if it is light, else its line goes to long-term memory with its weight.

var _npc: Npc


func before_each() -> void:
	_npc = Npc.create(42, Vector2.ZERO, NpcRules.default_rules())


func _story(day: int, weight: int, place := "here") -> Dictionary:
	return {
		"day": day,
		"minute": 600,
		"kind": GossipRules.FELLED,
		"count": 1,
		"place": place,
		"origin": "%d|felled|%s" % [day, place],
		"how": GossipRules.SEEN,
		"told_by": "",
		"seen_by": _npc.name,
		"hops": 0,
		"learned_at": (day - 1) * GameClock.MINUTES_PER_DAY + 600,
		"line": "",
		"weight": weight,
		"personal": false,
	}


func _days() -> Array:
	return _npc.stories.map(func(story: Dictionary) -> int: return story["day"])


func test_the_oldest_story_leaves_when_the_buffer_is_full() -> void:
	for day in 4:
		_npc.add_story(_story(day, MemoryWeight.MEDIUM), 3, 20)
	assert_eq(_days(), [1, 2, 3])


func test_a_story_that_leaves_becomes_a_memory_with_its_day_and_weight() -> void:
	_npc.add_story(_story(2, MemoryWeight.HIGH, "by Antje's house"), 1, 20)
	_npc.add_story(_story(3, MemoryWeight.MEDIUM), 1, 20)
	assert_eq(_npc.memories.size(), 1)
	assert_eq(_npc.memories[0]["day"], 2)
	assert_eq(_npc.memories[0]["weight"], MemoryWeight.HIGH)
	assert_eq(
		_npc.memories[0]["text"], "On day 2: you saw the newcomer fell a tree by Antje's house."
	)


func test_a_low_story_that_leaves_is_forgotten() -> void:
	_npc.add_story(_story(2, MemoryWeight.LOW), 1, 20)
	_npc.add_story(_story(3, MemoryWeight.MEDIUM), 1, 20)
	assert_eq(_days(), [3])
	assert_true(_npc.memories.is_empty())


func test_the_same_deed_of_the_same_day_and_place_is_one_story() -> void:
	_npc.add_story(_story(2, MemoryWeight.MEDIUM), 5, 20)
	_npc.add_story(_story(2, MemoryWeight.MEDIUM), 5, 20)
	assert_eq(_npc.stories.size(), 1)
	assert_eq(_npc.stories[0]["count"], 2)


func test_a_memory_pushed_out_by_a_story_goes_by_weight() -> void:
	_npc.add_memory("heavy", 1, MemoryWeight.HIGH, 1)
	_npc.add_story(_story(5, MemoryWeight.MEDIUM), 1, 1)
	_npc.add_story(_story(6, MemoryWeight.MEDIUM), 1, 1)
	assert_eq(
		_npc.memories.map(func(memory: Dictionary) -> String: return memory["text"]), ["heavy"]
	)


func test_lowering_the_stories_kept_moves_the_surplus_out() -> void:
	for day in 4:
		_npc.add_story(_story(day, MemoryWeight.MEDIUM), 10, 20)
	_npc.keep_stories(1, 20)
	assert_eq(_days(), [3])
	assert_eq(_npc.memories.size(), 3)


func test_a_story_is_saved_whole() -> void:
	var story := _story(4, MemoryWeight.HIGH)
	story["how"] = GossipRules.HEARD
	story["told_by"] = "Hinrich Boysen"
	story["hops"] = 1
	story["line"] = "Hinrich told me."
	story["personal"] = true
	_npc.stories.append(story)

	var loaded := Npc.from_dict(JSON.parse_string(JSON.stringify(_npc.to_dict())))

	assert_eq(loaded.stories, _npc.stories)
