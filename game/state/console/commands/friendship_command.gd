extends ConsoleCommand

## How far (in tiles) `friendship` looks for an animal.
const SEARCH_RADIUS := 3.0


func name() -> String:
	return "friendship"


func usage() -> String:
	return "friendship [0..100]"


func help() -> String:
	return "Show the friendship of the animal nearest to you, or set it."


func run(arguments: PackedStringArray) -> Array[String]:
	var state := context.state
	var livestock := state.livestock
	var maximum := livestock.rules.friendship("max")
	var is_value_valid := (
		arguments.size() == 1 and arguments[0].is_valid_int() and int(arguments[0]) >= 0
	)
	if arguments.size() > 1 or (arguments.size() == 1 and not is_value_valid):
		return wrong_usage()
	var animal := (
		null
		if state.is_inside()
		else livestock.nearest_pettable(state.player.position, SEARCH_RADIUS)
	)
	if animal == null:
		return ["No animal that can be petted near you"]
	if is_value_valid:
		animal.friendship = mini(int(arguments[0]), maximum)
	var petted := "never" if animal.last_petted_day == 0 else "day %d" % animal.last_petted_day
	return [
		(
			"%s: friendship %d of %d, last petted %s"
			% [animal.species, animal.friendship, maximum, petted]
		)
	]
