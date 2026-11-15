class_name WorldObjectWays
extends RefCounted
## The ways the player lays (#62) as data, merged into WorldObjectTypes `TYPES` (see there for the
## entries): a walk of planks and a path of cobbles, a piece a tile. Their atlas rows follow the
## scarecrow's (see tools/art/generate.py).

const _PLANK_WALK_ROW := 60
const _STONE_PATH_ROW := 61

const TYPES := {
	# Boards laid on the ground, a piece a tile: the axe takes them up again (#62). Over mud they
	# make a walk through the flats, a jetty of the land.
	WorldObjectTypes.PLANK_WALK:
	{
		"hp": 2,
		"tool": &"axe",
		"drops": {&"plank_walk": 1},
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
		"variants": 2,
		"placeable_in": WorldObjectTypes.OUTDOORS,
	},
	# Cobbles set in the earth: the pickaxe levers them up again (#62).
	WorldObjectTypes.STONE_PATH:
	{
		"hp": 3,
		"tool": &"pickaxe",
		"drops": {&"stone_path": 1},
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
