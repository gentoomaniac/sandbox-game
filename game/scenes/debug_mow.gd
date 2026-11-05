class_name DebugMow
extends RefCounted
## For screenshots (`--mow=<x>,<y>` in main.gd): the player stands on that tile with the scythe
## and mows twice, facing right and then down, leaving mown patches and hay. Loads the chunks
## around the tile itself, so it works far from the camp.

const CHUNK_REACH := 1


static func create(state: GameState, tile: Vector2i) -> void:
	var generator := WorldGenerator.new(state.world.world_seed)
	var centre := Chunk.world_to_chunk(tile)
	for y in range(-CHUNK_REACH, CHUNK_REACH + 1):
		for x in range(-CHUNK_REACH, CHUNK_REACH + 1):
			var coords := centre + Vector2i(x, y)
			if not state.world.is_chunk_loaded(coords):
				state.world.add_chunk(generator.generate_chunk(coords))
	state.player.position = Vector2(tile) + Vector2(0.5, 0.5)
	state.player.inventory.add(ItemTypes.SCYTHE, 1)
	for slot in Inventory.HOTBAR_SIZE:
		if state.player.inventory.item_in(slot) == ItemTypes.SCYTHE:
			state.player.inventory.select(slot)
	for facing in [Vector2i.RIGHT, Vector2i.DOWN]:
		state.player.facing = facing
		state.use_facing_tile()
