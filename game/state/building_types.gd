class_name BuildingTypes
extends RefCounted
## The kinds of building, as data. Keyed by type name; each entry has:
## - footprint: tiles covered, width x height;
## - door_offset: the walkable tile of the footprint, relative to its top left tile;
## - interior_map: the Tiled map of the inside (see InteriorLoader);
## - sprite: its picture, made by tools/art/generate.py. It is as wide as the footprint
##   and its bottom edge is the footprint's bottom edge; the roof rises above that;
## - sprite_lit: the same with lit windows, shown at night;
## - window_lights: the centre of each lit window, in pixels from the sprite's top left;
## - window_light: what each of them shines, like a world object's `light` (see
##   WorldObjectTypes).

const SMALL_HOUSE := &"small_house"

const TYPES := {
	SMALL_HOUSE:
	{
		"footprint": Vector2i(5, 3),
		"door_offset": Vector2i(2, 2),
		"interior_map": "res://maps/interiors/small_house.tmx",
		"sprite": "res://assets/buildings/small_house.png",
		"sprite_lit": "res://assets/buildings/small_house_lit.png",
		"window_lights": [Vector2i(15, 75), Vector2i(65, 75)],
		"window_light": {"color": Color(1.0, 0.62, 0.28), "energy": 0.9, "radius_tiles": 2.5},
	},
}
