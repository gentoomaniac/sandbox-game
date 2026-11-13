extends GutTest
## The long-term memories of a villager: each has a day, a text and a weight, and when there are
## too many the lightest is forgotten, between equal weights the oldest.

var _npc: Npc


func before_each() -> void:
	_npc = Npc.create(42, Vector2.ZERO, NpcRules.default_rules())


func _texts() -> Array:
	return _npc.memories.map(func(memory: Dictionary) -> String: return memory["text"])


func test_a_memory_has_its_day_text_and_weight() -> void:
	_npc.add_memory("one", 3, MemoryWeight.HIGH, 5)
	assert_eq(_npc.memories, [{"day": 3, "text": "one", "weight": MemoryWeight.HIGH}])


func test_a_full_memory_forgets_the_lightest() -> void:
	_npc.add_memory("heavy", 1, MemoryWeight.HIGH, 3)
	_npc.add_memory("light", 5, MemoryWeight.LOW, 3)
	_npc.add_memory("middle", 2, MemoryWeight.MEDIUM, 3)
	_npc.add_memory("new", 6, MemoryWeight.MEDIUM, 3)
	assert_eq(_texts(), ["heavy", "middle", "new"])


func test_between_equal_weights_the_oldest_is_forgotten() -> void:
	_npc.add_memory("day 4", 4, MemoryWeight.MEDIUM, 3)
	_npc.add_memory("day 2", 2, MemoryWeight.MEDIUM, 3)
	_npc.add_memory("day 3", 3, MemoryWeight.MEDIUM, 3)
	_npc.add_memory("day 5", 5, MemoryWeight.MEDIUM, 3)
	assert_eq(_texts(), ["day 4", "day 3", "day 5"])


func test_a_new_light_memory_may_be_the_one_forgotten() -> void:
	_npc.add_memory("heavy", 1, MemoryWeight.HIGH, 1)
	_npc.add_memory("light", 9, MemoryWeight.LOW, 1)
	assert_eq(_texts(), ["heavy"])


func test_lowering_the_memories_kept_forgets_the_surplus() -> void:
	for index in 5:
		_npc.add_memory("day %d" % index, index, MemoryWeight.MEDIUM, 5)
	_npc.keep_memories(2)
	assert_eq(_texts(), ["day 3", "day 4"])
