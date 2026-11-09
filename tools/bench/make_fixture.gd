extends SceneTree
## Writes a heavy save for `make bench`: seed 7, the 13x13 chunks round the camp loaded, about
## 30,000 tilled tiles, the objects on up to 20,000 random tiles removed, about 10,000 item piles
## away from the player and 12 at their feet, and about 155 villagers.
## godot --headless --path . -s tools/bench/make_fixture.gd -- <save file>

func _init() -> void:
	var out: String = OS.get_cmdline_user_args()[0]
	var state := GameState.new_game(7)
	var world := state.world
	var gen := WorldGenerator.new(7)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var camp := Vector2i(state.player.position.floor())
	var cc := Chunk.world_to_chunk(camp)
	for y in range(cc.y - 6, cc.y + 7):
		for x in range(cc.x - 6, cc.x + 7):
			var c := Vector2i(x, y)
			if World.is_chunk_in_bounds(c) and not world.is_chunk_loaded(c):
				world.add_chunk(gen.generate_chunk(c))
	var lo := Chunk.to_world(cc - Vector2i(6, 6), Vector2i.ZERO)
	var span := 13 * Chunk.CHUNK_SIZE
	for i in 30000:
		var p := lo + Vector2i(rng.randi() % span, rng.randi() % span)
		world.set_terrain(p, Tile.Terrain.SOIL)
	var removed := 0
	for i in 20000:
		var p := lo + Vector2i(rng.randi() % span, rng.randi() % span)
		if world.object_at(p) != null:
			world.remove_object(p)
			removed += 1
	var items: Array = [ItemTypes.LOGS, ItemTypes.STONE, ItemTypes.TURNIP]
	for i in 10000:
		var p := Vector2(camp) + Vector2(rng.randf_range(-1500, 1500), rng.randf_range(-1500, 1500))
		if p.distance_to(state.player.position) > 150:
			world.ground_items.add(GroundItem.new(items[i % 3], 1 + i % 5, p))
	for i in 12:
		world.ground_items.add(GroundItem.new(items[i % 3], 2, state.player.position + Vector2(rng.randf_range(-8, 8), rng.randf_range(-8, 8))))
	var placed := state.npcs.spawn(5, state.player.position, world)
	for i in 150:
		var near := Vector2(lo) + Vector2(rng.randf_range(0, span), rng.randf_range(0, span))
		placed += state.npcs.spawn(1, near, world)
	print("piles ", world.ground_items.all().size(), " npcs ", state.npcs.all().size(), " tilled ", world.tilled_tiles().size(), " object removals ", removed)
	print("saved ", SaveFile.write(state, out))
	quit()
