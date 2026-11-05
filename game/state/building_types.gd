class_name BuildingTypes
extends RefCounted
## The kinds of building, as data. Keyed by type name; each entry has:
## - footprint: tiles covered, width x height;
## - door_offset: the walkable tile of the footprint, relative to its top left tile;
## - interior_map: the Tiled map of the inside (see InteriorLoader);
## - sprite: its picture, made by tools/art/generate.py. It is as wide as the footprint
##   and its bottom edge is the footprint's bottom edge; the roof rises above that.

const SMALL_HOUSE := &"small_house"

const TYPES := {
	SMALL_HOUSE:
	{
		"footprint": Vector2i(4, 3),
		"door_offset": Vector2i(1, 2),
		"interior_map": "res://maps/interiors/small_house.tmx",
		"sprite": "res://assets/buildings/small_house.png",
	},
}
