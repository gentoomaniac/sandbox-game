class_name DebugStreet
extends RefCounted
## For screenshots (`--street=<x>,<y>`): every building of data/buildings.cfg in a row, in the
## hammer's order from the tile eastwards, a tile apart with their fronts in a line along a
## lane of grass laid over whatever was there. The chunks must be loaded.

## The row of the buildings' fronts: the deepest footprint fits above it.
const FRONT_ROW := 5
## The grass in front of the buildings, in tiles.
const LANE := 3


static func create(state: GameState, origin: Vector2i) -> void:
	var world := state.world
	var width := 0
	for building_type in BuildingTypes.ids():
		width += BuildingTypes.TYPES[building_type]["footprint"].x + 1
	for y in FRONT_ROW + LANE:
		for x in width:
			world.remove_object(origin + Vector2i(x, y))
			world.set_terrain(origin + Vector2i(x, y), Tile.Terrain.GRASS)
	var x := 0
	for building_type in BuildingTypes.ids():
		var footprint: Vector2i = BuildingTypes.TYPES[building_type]["footprint"]
		var at := origin + Vector2i(x, FRONT_ROW - footprint.y)
		if world.place_building(building_type, at) == null:
			push_error("--street: can't place the %s at %s" % [building_type, at])
		x += footprint.x + 1
