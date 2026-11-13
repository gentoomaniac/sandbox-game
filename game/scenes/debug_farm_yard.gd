class_name DebugFarmYard
extends RefCounted
## For screenshots (part of `--yard=<x>,<y>`, east of what DebugYard puts there): the farm yard of
## task 122 on a patch of grass. From the tile: the chicken coop (2x2) with four hens and the
## rooster among them in front of its door and the draw well beside it; below them a row of four
## troughs and a row of four hay racks, each stocked as empty, low, half and full; a cow at the
## full trough and a sheep at the full rack. Below them the pig pen of task 165: a ring of fence
## with its gate shut in the bottom side, the pigs' shelter, a trough and a feeding trough in it,
## and a pig of each look. Loads the chunks it covers itself.

const SIZE := Vector2i(14, 18)
## The pen's fence runs round this rectangle (its top left from the tile), and its gate is on this
## tile of it, in the middle of its bottom side.
const PEN := Rect2i(1, 11, 9, 6)
const PEN_GATE := Vector2i(4, 5)
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
	var chickens := [&"brown", &"white", &"rooster", &"brown", &"white"]
	for index in chickens.size():
		var feet := Vector2(origin) + Vector2(0.4 + 1.1 * index, 3.2)
		var hen := FarmAnimal.new(LivestockRules.CHICKEN, chickens[index], feet)
		state.livestock.add(hen)
	var cow := FarmAnimal.new(LivestockRules.COW, &"angler", Vector2(origin) + Vector2(10.5, 5.0))
	state.livestock.add(cow)
	var sheep := FarmAnimal.new(
		LivestockRules.SHEEP, &"white", Vector2(origin) + Vector2(10.5, 8.0)
	)
	state.livestock.add(sheep)
	_add_pig_pen(state, origin + PEN.position)


static func _add_pig_pen(state: GameState, corner: Vector2i) -> void:
	var world := state.world
	var gate := corner + PEN_GATE
	for y in PEN.size.y:
		for x in PEN.size.x:
			var tile := corner + Vector2i(x, y)
			var is_ring := x in [0, PEN.size.x - 1] or y in [0, PEN.size.y - 1]
			if is_ring:
				var type := (
					WorldObjectTypes.PEN_GATE if tile == gate else WorldObjectTypes.PEN_FENCE
				)
				world.add_object(WorldObject.new(type, tile))
	world.add_object(WorldObject.new(WorldObjectTypes.PIG_SHELTER, corner + Vector2i(1, 1)))
	for row in [[WorldObjectTypes.TROUGH, 5], [WorldObjectTypes.FEED_TROUGH, 3]]:
		var trough := WorldObject.new(row[0], corner + Vector2i(row[1], 1))
		ObjectStock.add(trough, 80)
		world.add_object(trough)
	var looks := state.livestock.rules.looks(LivestockRules.PIG)
	for index in looks.size():
		var feet := Vector2(corner) + Vector2(1.6 + 1.8 * index, 3.4 + 0.6 * (index % 2))
		state.livestock.add(FarmAnimal.new(LivestockRules.PIG, looks[index], feet))
