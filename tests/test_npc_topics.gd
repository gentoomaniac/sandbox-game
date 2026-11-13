extends GutTest
## The topics of the village a villager knows (Npc `topics`): a villager written by hand knows
## them all, a made-up one none, and what they know they never forget.


func test_a_villager_written_by_hand_knows_every_topic() -> void:
	var antje := Npc.create_villager("antje", Vector2.ZERO, VillagerRules.default_rules())

	assert_eq(antje.topics, VillageSheet.default_sheet().topic_names())


func test_a_made_up_villager_knows_none() -> void:
	assert_eq(Npc.create(7, Vector2.ZERO, NpcRules.default_rules()).topics, [] as Array[String])


func test_forgetting_everything_leaves_the_topics() -> void:
	var npc := Npc.create(7, Vector2.ZERO, NpcRules.default_rules())
	npc.topics.assign(["village", "money"])
	npc.add_memory("On day 1: a talk.", 1, MemoryWeight.MEDIUM, 20)

	npc.forget_all_but_knowledge()

	assert_true(npc.memories.is_empty())
	assert_eq(npc.topics, ["village", "money"] as Array[String])
