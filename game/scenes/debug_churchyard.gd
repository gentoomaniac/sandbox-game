class_name DebugChurchyard
extends RefCounted
## For screenshots (`--churchyard=<x>,<y>`): the church with its bell frame beside it and a
## few graves, in a fieldstone wall with a gap in front of the church door, the wall's top left
## corner on the tile, on grass laid over whatever was there. The chunks must be loaded.

const SIZE := Vector2i(14, 11)
## The top left tile of each building in the yard.
const BUILDINGS := {BuildingTypes.CHURCH: Vector2i(2, 2), BuildingTypes.BELL_FRAME: Vector2i(10, 2)}
const GATE := Vector2i(4, 10)
const GRAVES: Array[Vector2i] = [
	Vector2i(2, 8),
	Vector2i(7, 7),
	Vector2i(8, 8),
	Vector2i(10, 7),
	Vector2i(11, 8),
	Vector2i(12, 6)
]


static func create(state: GameState, origin: Vector2i) -> void:
	var world := state.world
	for y in SIZE.y:
		for x in SIZE.x:
			world.remove_object(origin + Vector2i(x, y))
			world.set_terrain(origin + Vector2i(x, y), Tile.Terrain.GRASS)
	for building_type: StringName in BUILDINGS:
		var at: Vector2i = origin + BUILDINGS[building_type]
		if world.place_building(building_type, at) == null:
			push_error("--churchyard: can't place the %s at %s" % [building_type, at])
	for y in SIZE.y:
		for x in SIZE.x:
			var tile := Vector2i(x, y)
			var is_on_the_wall := x in [0, SIZE.x - 1] or y in [0, SIZE.y - 1]
			if is_on_the_wall and tile != GATE:
				world.add_object(WorldObject.new(WorldObjectTypes.STONE_WALL, origin + tile))
	for grave in GRAVES:
		world.add_object(WorldObject.new(WorldObjectTypes.GRAVE, origin + grave))
