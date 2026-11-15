extends ConsoleCommand


func name() -> String:
	return "goto"


func usage() -> String:
	return "goto <villager> <x>,<y>|here"


func help() -> String:
	return (
		"Send a villager to a tile, or to where you stand (here): it finds its way, along lanes,"
		+ " round fences and through gates. On its way means a search is under way: that there is no"
		+ " way comes later, F4 shows its path and whether it is blocked."
	)


func argument_kinds() -> Array[StringName]:
	return [&"villager", &"destination"]


## Sends a villager to a tile of the world, to watch the way they find.
func run(arguments: PackedStringArray) -> Array[String]:
	if arguments.size() != 2:
		return wrong_usage()
	var npc := ConsoleHelper.npc_named(arguments[0], context)
	if npc == null:
		return ConsoleHelper.unknown("villager", arguments[0], self, context)
	var state := context.state
	var tile := state.player.tile()
	if arguments[1] == ConsoleHelper.HERE:
		if state.is_inside():
			return ["Go outside first: villagers walk in the world"]
	else:
		var numbers := arguments[1].split(",")
		if numbers.size() != 2 or not numbers[0].is_valid_int() or not numbers[1].is_valid_int():
			return wrong_usage()
		tile = Vector2i(int(numbers[0]), int(numbers[1]))
	state.npcs.walk_to(npc, tile, state.world)
	return _answer(npc, tile)


## What a villager who has just been sent to `tile` says: it is there, or a search is under way (F4
## says what comes of it).
func _answer(npc: Npc, tile: Vector2i) -> Array[String]:
	if not npc.is_travelling():
		return ["%s is at %s already" % [npc.name, tile]]
	var tiles_between := roundi(npc.position.distance_to(Vector2(tile) + Vector2(0.5, 0.5)))
	return ["%s is on its way to %s, %d tiles off" % [npc.name, tile, tiles_between]]
