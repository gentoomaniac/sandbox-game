extends ConsoleCommand

## The tiles next to a villager that `tp <villager>` tries, the four sides before the corners.
const BESIDE: Array[Vector2i] = [
	Vector2i.DOWN,
	Vector2i.RIGHT,
	Vector2i.LEFT,
	Vector2i.UP,
	Vector2i(1, 1),
	Vector2i(-1, 1),
	Vector2i(1, -1),
	Vector2i(-1, -1),
]


func name() -> String:
	return "tp"


func usage() -> String:
	return "tp <x> <y> | tp <villager>"


func help() -> String:
	return (
		"Teleport to a world tile, or to a free tile next to a villager (an id such as antje, or a"
		+ " first name); from inside a house you step out there."
	)


func argument_kinds() -> Array[StringName]:
	return [&"number", &"number"]


## A first word that is no number is a villager.
func argument_kinds_for(arguments: PackedStringArray) -> Array[StringName]:
	if arguments.is_empty() or not arguments[0].is_valid_int():
		return [&"villager"]
	return argument_kinds()


func run(arguments: PackedStringArray) -> Array[String]:
	if arguments.size() == 1 and not arguments[0].is_valid_int():
		return _to_villager(arguments[0])
	if arguments.size() != 2 or not arguments[0].is_valid_int() or not arguments[1].is_valid_int():
		return wrong_usage()
	var tile := Vector2i(int(arguments[0]), int(arguments[1]))
	if not World.is_in_bounds(tile):
		return ["Tile %d, %d is outside the world" % [tile.x, tile.y]]
	if context.state.world.building_at(tile) != null:
		return ["Tile %d, %d is covered by a building" % [tile.x, tile.y]]
	if not _is_walkable_even_if_unloaded(tile):
		return ["Can't walk on tile %d, %d" % [tile.x, tile.y]]
	PlayerRest.teleport_to(context.state, tile)
	return ["Teleported to %d, %d" % [tile.x, tile.y]]


## Teleports next to the villager this word names, on the first free tile beside them.
func _to_villager(word: String) -> Array[String]:
	var npc := ConsoleHelper.npc_named(word, context)
	if npc == null:
		return ["No villager %s" % word]
	var at := npc.tile()
	for offset in BESIDE:
		var tile := at + offset
		if _is_free(tile):
			PlayerRest.teleport_to(context.state, tile)
			return ["Teleported next to %s, at %d, %d" % [npc.name, tile.x, tile.y]]
	return ["No free tile next to %s, at %d, %d" % [npc.name, at.x, at.y]]


## Whether the player can stand on a tile: in the world, walkable, under no building and with
## no villager on it.
func _is_free(tile: Vector2i) -> bool:
	if not World.is_in_bounds(tile) or context.state.world.building_at(tile) != null:
		return false
	for npc in context.state.npcs.all():
		if npc.tile() == tile:
			return false
	return _is_walkable_even_if_unloaded(tile)


## Whether a tile of the world is walkable, also when its chunk is not loaded: that chunk is
## generated for the look and dropped again, as the world view draws only the chunks it loads.
func _is_walkable_even_if_unloaded(tile: Vector2i) -> bool:
	var world := context.state.world
	var coords := Chunk.world_to_chunk(tile)
	var was_loaded := world.is_chunk_loaded(coords)
	if not was_loaded:
		world.add_chunk(WorldGenerator.new(world.world_seed).generate_chunk(coords))
	var is_walkable := world.is_walkable(tile)
	if not was_loaded:
		world.remove_chunk(coords)
	return is_walkable
