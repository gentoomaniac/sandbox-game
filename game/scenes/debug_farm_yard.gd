class_name DebugFarmYard
extends RefCounted
## For screenshots (part of `--yard=<x>,<y>`, east of what DebugYard puts there): the farm yard of
## task 122 on a patch of grass. From the tile: the chicken coop (2x2) with three hens in front of
## its door and the draw well beside it; below them a row of four troughs and a row of four hay
## racks, each stocked as empty, low, half and full; a cow at the full trough and a sheep at the
## full rack. Loads the chunks it covers itself.

const SIZE := Vector2i(14, 10)
## How full each of the four troughs and four racks is: empty, low, half, full.
const STOCKS := [0, 20, 50, 100]


static func create(state: GameState, origin: Vector2i) -> void:
	var world := state.world
	var generator := WorldGenerator.new(world.world_seed)
	for y in range(-1, SIZE.y):
		for x in range(-1, SIZE.x):
			var tile := origin + Vector2i(x, y)
			if not world.is_chunk_loaded(Chunk.world_to_chunk(tile)):
				world.add_chunk(generator.generate_chunk(Chunk.world_to_chunk(tile)))
			world.remove_object(tile)
			world.set_terrain(tile, Tile.Terrain.GRASS)
	world.place_building(BuildingTypes.CHICKEN_COOP, origin)
	world.add_object(WorldObject.new(WorldObjectTypes.DRAW_WELL, origin + Vector2i(5, 1)))
	for index in STOCKS.size():
		for row in [[WorldObjectTypes.TROUGH, 5], [WorldObjectTypes.HAY_RACK, 8]]:
			var stocked := WorldObject.new(row[0], origin + Vector2i(3 * index, row[1]))
			ObjectStock.add(stocked, STOCKS[index])
			world.add_object(stocked)
	for index in 3:
		var feet := Vector2(origin) + Vector2(0.4 + 1.1 * index, 3.2)
		var hen := FarmAnimal.new(
			LivestockRules.CHICKEN, [&"brown", &"white", &"rooster"][index], feet
		)
		state.livestock.add(hen)
	var cow := FarmAnimal.new(LivestockRules.COW, &"angler", Vector2(origin) + Vector2(10.5, 5.0))
	state.livestock.add(cow)
	var sheep := FarmAnimal.new(
		LivestockRules.SHEEP, &"white", Vector2(origin) + Vector2(10.5, 8.0)
	)
	state.livestock.add(sheep)
