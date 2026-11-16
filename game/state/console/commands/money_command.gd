extends ConsoleCommand


func name() -> String:
	return "money"


func usage() -> String:
	return "money [<Schilling>|+<Schilling>|-<Schilling>]"


func help() -> String:
	return "Show the purse, set it to a number of Schilling, or add (+) or take (-) some."


func argument_kinds() -> Array[StringName]:
	return [&"number"]


func run(arguments: PackedStringArray) -> Array[String]:
	var purse := context.state.player.purse
	if arguments.size() > 1 or (arguments.size() == 1 and not arguments[0].is_valid_int()):
		return wrong_usage()
	if arguments.size() == 1:
		var amount := int(arguments[0])
		var is_change := arguments[0].begins_with("+") or arguments[0].begins_with("-")
		purse.schilling = maxi(purse.schilling + amount if is_change else amount, 0)
	return ["Purse: %d Schilling" % purse.schilling]
