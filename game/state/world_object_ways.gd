class_name WorldObjectWays
extends RefCounted
## The ways the player lays (#62) as data, merged into WorldObjectTypes `TYPES` (see there for the
## entries): a walk of planks and a path of cobbles, a piece a tile. Their atlas rows follow the
## scarecrow's (see tools/art/generate.py). All ways `connect`: a way next to another, of either
## kind, runs on into it with no edge between them, and has an edge where none lies beside it.

const _PLANK_WALK_ROW := 60
const _STONE_PATH_ROW := 61
## The bits of a connection mask (see World `connections`) as the art draws them.
const _NORTH := 1
const _EAST := 2
const _SOUTH := 4
const _WEST := 8

const TYPES := {
	# Boards laid on the ground, a piece a tile: the axe takes them up again (#62). Over mud they
	# make a walk through the flats, a jetty of the land.
	WorldObjectTypes.PLANK_WALK:
	{
		"hp": 2,
		"tool": &"axe",
		"drops": {&"plank_walk": 1},
		"connects": &"way",
		"deck": true,
		"way": true,
		"placed_on":
		[
			Tile.Terrain.GRASS,
			Tile.Terrain.WARFT,
			Tile.Terrain.FLOODPLAIN,
			Tile.Terrain.MUD,
			Tile.Terrain.SALT_MARSH,
		],
		"footprint": Vector2i(1, 1),
		"blocks_walking": false,
		"harvest_level": 1,
		"atlas_row": _PLANK_WALK_ROW,
		"variants": 4,
		"placeable_in": WorldObjectTypes.OUTDOORS,
	},
	# Cobbles set in the earth: the pickaxe levers them up again (#62).
	WorldObjectTypes.STONE_PATH:
	{
		"hp": 3,
		"tool": &"pickaxe",
		"drops": {&"stone_path": 1},
		"connects": &"way",
		"deck": true,
		"way": true,
		"placed_on": [Tile.Terrain.GRASS, Tile.Terrain.WARFT, Tile.Terrain.FLOODPLAIN],
		"footprint": Vector2i(1, 1),
		"blocks_walking": false,
		"harvest_level": 1,
		"atlas_row": _STONE_PATH_ROW,
		"variants": 3,
		"placeable_in": WorldObjectTypes.OUTDOORS,
	},
}


## Whether the boards of a plank walk lie east to west, across a way that runs north to south, and
## not north to south, across one that runs east to west. The way runs along the axis with more
## neighbours on it (`connections` is the mask of its neighbours); with as many on both (a
## corner, a crossing, a tile alone) the boards lie east to west, and so they do at a way's end.
## The art draws the boards of each mask by the same rule (tools/art/ways.py).
static func boards_lie_east_west(connections: int) -> bool:
	var along_north_south := int(connections & _NORTH != 0) + int(connections & _SOUTH != 0)
	var along_east_west := int(connections & _EAST != 0) + int(connections & _WEST != 0)
	return along_east_west <= along_north_south


## The tile that the variant of an object's picture is picked by (see ObjectTileset `atlas_cell`):
## its own, but for the boards of a plank walk, which have the same widths wherever they lie in a
## row of tiles (their variant comes from the row, or the column if they lie north to south), so
## the boards of a road wider than one tile run on from tile to tile.
static func variant_tile(object: WorldObject, connections: int) -> Vector2i:
	if object.type != WorldObjectTypes.PLANK_WALK:
		return object.pos
	if boards_lie_east_west(connections):
		return Vector2i(0, object.pos.y)
	return Vector2i(object.pos.x, 0)
