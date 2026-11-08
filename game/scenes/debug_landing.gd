class_name DebugLanding
extends RefCounted
## For screenshots (`--landing=<x>,<y>`): the fisherman's landing at the water's edge. The tile is
## the bank, where the jetty starts: it runs west from there over the water, the rowing boat lies
## moored along its south side, the net frame stands two tiles up from the bank and the eel traps
## lie beside the boat. Placed whatever the ground; loads the chunks it covers itself.

const JETTY_LENGTH := 3


static func create(world: World, bank: Vector2i) -> void:
	var objects: Array[WorldObject] = [
		WorldObject.new(WorldObjectTypes.ROWING_BOAT, bank + Vector2i(1 - JETTY_LENGTH, 1)),
		WorldObject.new(WorldObjectTypes.NET_FRAME, bank + Vector2i(0, -2)),
		WorldObject.new(WorldObjectTypes.EEL_TRAPS, bank + Vector2i(1, 1)),
	]
	for x in JETTY_LENGTH:
		objects.append(WorldObject.new(WorldObjectTypes.JETTY, bank - Vector2i(x, 0)))
	var generator := WorldGenerator.new(world.world_seed)
	for object in objects:
		for tile in object.tiles():
			var coords := Chunk.world_to_chunk(tile)
			if not world.is_chunk_loaded(coords):
				world.add_chunk(generator.generate_chunk(coords))
			world.remove_object(tile)
		world.add_object(object)
