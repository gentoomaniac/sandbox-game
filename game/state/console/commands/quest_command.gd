extends ConsoleCommand


func name() -> String:
	return "quest"


func usage() -> String:
	return "quest [post <id> [villager] | done <id> | clear]"


func help() -> String:
	return (
		"List the quests that are posted or taken; post puts one up now with a giver (any quest, any"
		+ " time), done marks one done, clear takes them all off the list."
	)


func argument_kinds() -> Array[StringName]:
	return [&"quest_action", &"quest", &"villager"]


func run(arguments: PackedStringArray) -> Array[String]:
	var quests := context.state.quests
	if arguments.is_empty():
		return _list(quests)
	var is_post := arguments[0] == "post" and arguments.size() in [2, 3]
	var is_done := arguments[0] == "done" and arguments.size() == 2
	if is_post:
		var problem := quests.post(arguments[1], arguments[2] if arguments.size() == 3 else "")
		return [problem] if problem != "" else ["Posted %s" % arguments[1]]
	if is_done:
		return (
			["Done %s" % arguments[1]]
			if quests.finish(arguments[1])
			else ["%s is not open" % arguments[1]]
		)
	if arguments[0] == "clear" and arguments.size() == 1:
		quests.clear()
		return ["No quests are open now"]
	return wrong_usage()


func _list(quests: Quests) -> Array[String]:
	var lines: Array[String] = []
	for entry in quests.open_entries():
		var giver := context.state.npcs.find(entry["giver"])
		(
			lines
			. append(
				(
					"%s: %s, posted day %d, to day %d, %s"
					% [
						entry["id"],
						entry["giver"] if giver == null else giver.name,
						entry["posted_day"],
						quests.last_day_of(entry),
						"taken" if entry["is_taken"] else "not taken",
					]
				)
			)
		)
	if lines.is_empty():
		lines.append("No quests are open")
	return lines
