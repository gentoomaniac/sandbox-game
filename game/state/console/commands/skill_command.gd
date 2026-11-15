extends ConsoleCommand


func name() -> String:
	return "skill"


func usage() -> String:
	return "skill <skill> <points>"


func help() -> String:
	return "Set a skill's points (0 to 100)."


func argument_kinds() -> Array[StringName]:
	return [&"skill", &"number"]


func run(arguments: PackedStringArray) -> Array[String]:
	if arguments.size() != 2 or not arguments[1].is_valid_float():
		return wrong_usage()
	var skills := context.state.player.skills
	var skill := StringName(arguments[0])
	if not skills.rules.has_skill(skill):
		return ["Unknown skill: %s" % arguments[0]]
	skills.set_points(skill, float(arguments[1]))
	return ["%s is %s" % [skills.rules.skill_name(skill), skills.points(skill)]]
