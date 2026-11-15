extends ConsoleCommand


func name() -> String:
	return "opinion"


func usage() -> String:
	return "opinion <villager> [points]"


func help() -> String:
	return (
		"Show what a villager thinks of you, as a level and in points, or set it in points (-100"
		+ " to 1000)."
	)


func argument_kinds() -> Array[StringName]:
	return [&"villager", &"number"]


## What a villager thinks of the player, as a level and in points; with `points` it sets them.
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
	var friendship := FriendshipRules.default_rules()
	var level := friendship.level_of(npc.opinion)
	return [
		(
			"%s: %s, level %d (%d points)"
			% [npc.name, friendship.level_name(level), level, npc.opinion]
		)
	]
