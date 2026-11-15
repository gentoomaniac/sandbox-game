extends ConsoleCommand


func name() -> String:
	return "deeds"


func usage() -> String:
	return "deeds"


func help() -> String:
	return "List what you did within sight of villagers, and who saw it."


func run(_arguments: PackedStringArray) -> Array[String]:
	var lines: Array[String] = []
	var deeds := context.state.deeds
	deeds.forget_old()
	for entry in deeds.entries:
		(
			lines
			. append(
				(
					"Day %d, %s: %s %s, seen by %s"
					% [
						entry["day"],
						Sun.time_text(entry["minute"]),
						deeds.rules.deed_words(entry["kind"], entry["count"]),
						entry["place"],
						", ".join(entry["witnesses"]),
					]
				)
			)
		)
	if lines.is_empty():
		lines.append("No deeds seen yet")
	return lines
