extends ConsoleCommand


func name() -> String:
	return "attribute"


func usage() -> String:
	return "attribute <attribute> <level>"


func help() -> String:
	return "Set an attribute's level (strength, agility, stamina or hp) and show what it gives."


func argument_kinds() -> Array[StringName]:
	return [&"attribute", &"number"]


func run(arguments: PackedStringArray) -> Array[String]:
	if arguments.size() != 2 or not arguments[1].is_valid_int():
		return wrong_usage()
	var attributes := context.state.player.attributes
	var attribute := StringName(arguments[0])
	if not attributes.rules.has_attribute(attribute):
		return ["Unknown attribute: %s" % arguments[0]]
	attributes.set_level(attribute, int(arguments[1]))
	return [
		(
			"%s is %d: %d energy, %d health, %.1f kg carried before it tires you"
			% [
				attributes.rules.attribute_name(attribute),
				attributes.level(attribute),
				attributes.max_energy(),
				attributes.max_health(),
				attributes.carry_capacity(),
			]
		)
	]
