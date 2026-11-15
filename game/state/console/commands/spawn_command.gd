extends ConsoleCommand


func name() -> String:
	return "spawn"


func usage() -> String:
	return "spawn <kind> [count]"


func help() -> String:
	return (
		"Put animals or villagers (npc, or the id of one written by hand, such as antje) near"
		+ " you; farm animals and villagers stay."
	)


func argument_kinds() -> Array[StringName]:
	return [&"animal", &"number"]


func argument_kinds_for(arguments: PackedStringArray) -> Array[StringName]:
	if not arguments.is_empty() and arguments[0] == ConsoleHelper.NPC:
		return ConsoleHelper.NPC_ARGUMENTS
	return argument_kinds()


func takes_villager_ids() -> bool:
	return true


func run(arguments: PackedStringArray) -> Array[String]:
	if arguments.is_empty():
		return ConsoleHelper.candidates_text(self, context)
	if (
		arguments.size() == 2
		and arguments[0] == ConsoleHelper.NPC
		and not arguments[1].is_valid_int()
	):
		return _spawn_villager(arguments[1])
	if arguments.size() == 1 and context.state.npcs.villagers.has(arguments[0]):
		return _spawn_villager(arguments[0])
	return _spawn_animals(arguments)


func _spawn_animals(arguments: PackedStringArray) -> Array[String]:
	var state := context.state
	var is_count_valid := (
		arguments.size() < 2 or (arguments[1].is_valid_int() and int(arguments[1]) > 0)
	)
	if arguments.size() > 2 or not is_count_valid:
		return wrong_usage()
	var word := arguments[0]
	var count := 1 if arguments.size() < 2 else int(arguments[1])
	# Farm animals and villagers stay in the world: they are part of the state.
	if (
		word == ConsoleHelper.NPC
		or word == ConsoleHelper.ROOSTER
		or LivestockRules.SPECIES.has(StringName(word))
	):
		if state.is_inside():
			return ["No %s here" % ("villagers" if word == ConsoleHelper.NPC else "animals")]
		var near := state.player.position
		var spawned := 0
		if word == ConsoleHelper.NPC:
			spawned = state.npcs.spawn(count, near, state.world)
		elif word == ConsoleHelper.ROOSTER:
			spawned = state.livestock.spawn(
				LivestockRules.CHICKEN, count, near, state.world, LivestockRules.ROOSTER_LOOK
			)
		else:
			spawned = state.livestock.spawn(StringName(word), count, near, state.world)
		return ["Spawned %d of %d %s" % [spawned, count, word]]
	if not WildlifeRules.KINDS.has(ConsoleHelper.wildlife_kind(word)):
		return ConsoleHelper.unknown("animal", word, self, context)
	if state.is_inside() or not context.wildlife_spawner.is_valid():
		return ["No animals here"]
	var placed: int = context.wildlife_spawner.call(ConsoleHelper.wildlife_kind(word), count)
	return ["Spawned %d of %d %s" % [placed, count, word]]


func _spawn_villager(villager_id: String) -> Array[String]:
	var state := context.state
	var npcs := state.npcs
	if not npcs.villagers.has(villager_id):
		return ConsoleHelper.unknown("villager", villager_id, self, context)
	var here := npcs.find(villager_id)
	if here != null:
		return ["%s is already here" % here.name]
	if state.is_inside():
		return ["No villagers here"]
	var npc := npcs.spawn_villager(villager_id, state.player.position, state.world)
	if npc == null:
		return ["No room for %s here" % villager_id]
	return ["Spawned %s" % npc.name]
