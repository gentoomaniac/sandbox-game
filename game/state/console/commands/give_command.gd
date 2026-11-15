extends ConsoleCommand


func name() -> String:
	return "give"


func usage() -> String:
	return "give <item> [count]"


func help() -> String:
	return "Put items in the inventory."


func argument_kinds() -> Array[StringName]:
	return [&"item", &"number"]


func run(arguments: PackedStringArray) -> Array[String]:
	var is_count_valid := (
		arguments.size() < 2 or (arguments[1].is_valid_int() and int(arguments[1]) > 0)
	)
	if arguments.is_empty() or arguments.size() > 2 or not is_count_valid:
		return wrong_usage()
	var item := StringName(arguments[0])
	if not ItemTypes.TYPES.has(item):
		return ConsoleHelper.unknown_item(arguments[0])
	var count := 1 if arguments.size() < 2 else int(arguments[1])
	var left := context.state.player.inventory.add(item, count)
	var lines: Array[String] = []
	if left < count:
		lines.append("Gave %d %s" % [count - left, ItemTypes.TYPES[item]["name"]])
	if left > 0:
		lines.append("Inventory full: %d not added" % left)
	return lines
