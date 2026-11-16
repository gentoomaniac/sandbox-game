class_name WorldObjectLanding
extends RefCounted
## The fisherman landing as data, loaded into WorldObjectTypes `TYPES` (see there for the entries):
## the ewer, the jetty, the rowing boat, the net frame and the eel traps.

const _EWER_ROW := 45
const _JETTY_ROW := 47
const _ROWING_BOAT_ROW := 48
const _NET_FRAME_ROW := 49
const _EEL_TRAPS_ROW := 50

const TYPES := {
	&"ewer":
	{
		"footprint": Vector2i(7, 1),
		"blocks_walking": true,
		"harvest_level": 0,
		"atlas_row": _EWER_ROW,
		"variants": 1,
		"cells_wide": 3,
	},
	&"jetty":
	{
		"hp": 3,
		"tool": &"axe",
		"drops": {&"jetty": 1},
		"connects": &"jetty",
		"deck": true,
		"placed_on":
		[Tile.Terrain.WATER, Tile.Terrain.SEA, Tile.Terrain.MUD, Tile.Terrain.SALT_MARSH],
		"footprint": Vector2i(1, 1),
		"blocks_walking": false,
		"harvest_level": 1,
		"atlas_row": _JETTY_ROW,
		"variants": 1,
		"placeable_in": WorldObjectTypes.OUTDOORS,
	},
	&"rowing_boat":
	{
		"hp": 3,
		"tool": &"axe",
		"drops": {&"rowing_boat": 1},
		"placed_on":
		[Tile.Terrain.WATER, Tile.Terrain.SEA, Tile.Terrain.MUD, Tile.Terrain.SALT_MARSH],
		"footprint": Vector2i(2, 1),
		"blocks_walking": true,
		"harvest_level": 1,
		"atlas_row": _ROWING_BOAT_ROW,
		"variants": 1,
		"placeable_in": WorldObjectTypes.OUTDOORS,
	},
	&"net_frame":
	{
		"hp": 2,
		"tool": &"axe",
		"drops": {&"net_frame": 1},
		"footprint": Vector2i(2, 1),
		"blocks_walking": true,
		"harvest_level": 1,
		"atlas_row": _NET_FRAME_ROW,
		"variants": 1,
		"placeable_in": WorldObjectTypes.OUTDOORS,
	},
	&"eel_traps":
	{
		"drops": {&"eel_traps": 1},
		"footprint": Vector2i(1, 1),
		"blocks_walking": true,
		"harvest_level": 0,
		"atlas_row": _EEL_TRAPS_ROW,
		"variants": 1,
		"placeable_in": WorldObjectTypes.OUTDOORS,
	},
}
