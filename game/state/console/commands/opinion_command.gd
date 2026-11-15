extends ConsoleCommand


func name() -> String:
	return "opinion"


func usage() -> String:
	return "opinion <villager> [points]"


func help() -> String:
	return (
		"Show what a villager thinks of you, or set it in points (-100 to 1000; below -20 is"
		+ " cold, from 20 warm)."
	)


func argument_kinds() -> Array[StringName]:
	return [&"villager", &"number"]


## What a villager thinks of the player, in a word and in points; with `points` it sets them.
func run(arguments: PackedStringArray) -> Array[String]:
	var is_setting := arguments.size() == 2
	var is_usage_wrong := arguments.is_empty() or arguments.size() > 2
	if is_usage_wrong or (is_setting and not arguments[1].is_valid_int()):
		return wrong_usage()
	var npc := ConsoleHelper.npc_named(arguments[0], context)
	if npc == null:
		return ConsoleHelper.unknown("villager", arguments[0], self, context)
	var rules := context.state.deeds.rules
	if is_setting:
		npc.opinion = clampi(int(arguments[1]), rules.opinion_min(), rules.opinion_max())
	return ["%s: %s (%d points)" % [npc.name, rules.opinion_word(npc.opinion), npc.opinion]]
