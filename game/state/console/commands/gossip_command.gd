extends ConsoleCommand


func name() -> String:
	return "gossip"


func usage() -> String:
	return "gossip <villager>"


func help() -> String:
	return (
		"List the stories and the long-term memories a villager keeps, with their weights (the"
		+ " id of a villager written by hand, such as antje, or a first name)."
	)


func argument_kinds() -> Array[StringName]:
	return [&"villager"]


## The stories of a villager's gossip buffer and their long-term memories, oldest first, each with
## its weight, and the topics of the village they know.
func run(arguments: PackedStringArray) -> Array[String]:
	if arguments.size() != 1:
		return wrong_usage()
	var npc := ConsoleHelper.npc_named(arguments[0], context)
	if npc == null:
		return ConsoleHelper.unknown("villager", arguments[0], self, context)
	var deeds := context.state.deeds
	var lines: Array[String] = [
		(
			"%s keeps %d of %d stories and %d of %d memories"
			% [
				npc.name,
				npc.stories.size(),
				deeds.stories_kept,
				npc.memories.size(),
				deeds.memories_kept,
			]
		)
	]
	(
		lines
		. append(
			(
				(
					"Knows %d of %d topics of the village: %s"
					% [
						npc.topics.size(),
						VillageSheet.default_sheet().topic_names().size(),
						", ".join(npc.topics),
					]
				)
				if not npc.topics.is_empty()
				else "Knows no topic of the village"
			)
		)
	)
	for story in npc.stories:
		var told := (
			"seen" if story["how"] == GossipRules.SEEN else "heard from %s" % story["told_by"]
		)
		lines.append(
			(
				"Story, %s, %s: %s"
				% [MemoryWeight.to_word(story["weight"]), told, deeds.rules.memory_line(story)]
			)
		)
	for memory in npc.memories:
		lines.append(
			(
				"Memory, %s, day %d: %s"
				% [MemoryWeight.to_word(memory["weight"]), memory["day"], memory["text"]]
			)
		)
	return lines
