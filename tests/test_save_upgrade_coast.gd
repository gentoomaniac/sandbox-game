extends SaveUpgradeCase
## Saves of version 17 and before, made before the coast: a home on what is now the foreshore
## stays dry land, and a home away from the coast is left as it was.


## A tile of the coast near the river's mouth for which `is_wanted` is true.
func _find_coast_tile(is_wanted: Callable) -> Vector2i:
	for y in range(-100, 100):
		for x in range(-420, -200):
			if is_wanted.call(Vector2i(x, y)):
				return Vector2i(x, y)
	fail_test("no tile found")
	return Vector2i.ZERO


func test_a_version_17_home_on_the_mud_stays_dry_land() -> void:
	var game := _current_game()
	var generator := WorldGenerator.new(int(game["world"]["seed"]))
	var mud := _find_coast_tile(
		func(pos: Vector2i) -> bool:
			return (
				generator.terrain_at(pos) == Tile.Terrain.MUD
				and generator.terrain_at(pos + Vector2i(0, 4)) == Tile.Terrain.SEA
			)
	)
	var shack := {"type": "shack", "origin": SaveCodec.vector_to_json(mud), "interior": null}
	game["world"]["buildings"].append(shack)
	# The player stands in what is now a tideway.
	game["player"]["position"] = [mud.x + 0.5, mud.y + 4.9]
	_write_save(17, game)

	var restored := SaveFile.read(SAVE_PATH)

	var world := restored.world
	for tile: Vector2i in [mud, mud + Vector2i(0, 4)]:
		world.add_chunk(generator.generate_chunk(Chunk.world_to_chunk(tile)))
	assert_eq(world.tile_at(mud).terrain, Tile.Terrain.GRASS, "under the shack")
	assert_eq(world.tile_at(mud + Vector2i(0, 4)).terrain, Tile.Terrain.GRASS, "under the player")
	assert_true(PlayerState.can_stand_at(world, restored.player.position))


func test_a_version_17_home_away_from_the_coast_is_left_as_it_was() -> void:
	var game := _current_game()
	var shack := {"type": "shack", "origin": [4, 4], "interior": null}
	game["world"]["buildings"].append(shack)
	var terrain_edits: int = game["world"]["terrain_edits"].size()
	var object_edits: int = game["world"]["object_edits"].size()
	_write_save(17, game)

	var world := SaveFile.read(SAVE_PATH).world

	assert_eq(world.to_dict()["terrain_edits"].size(), terrain_edits)
	assert_eq(world.to_dict()["object_edits"].size(), object_edits)
