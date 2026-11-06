class_name Tile
extends RefCounted
## A snapshot of one tile's state. Changing the world goes through Chunk's setters, not here.

## Inside a building, FLOOR is the laid brick floor of the living rooms and CLAY_FLOOR the
## beaten clay of the work rooms. MUD is the tidal flats of the coast, walked on at any tide.
enum Terrain { GRASS, SOIL, WATER, WETLAND, FLOODPLAIN, FLOOR, WALL, CLAY_FLOOR, MUD }

var terrain: Terrain = Terrain.GRASS
## Nothing sets it yet: the hook for frozen rivers, which can be walked across.
var frozen := false


## Water blocks movement unless it is frozen (a frozen river can be crossed), and so does a
## wall.
func is_walkable() -> bool:
	return (terrain != Terrain.WATER or frozen) and terrain != Terrain.WALL


## Only grass (ordinary, lush or dry) and the floodplain wear to a desire path where they are
## walked often (see World.wear_tile).
func wears() -> bool:
	return terrain == Terrain.GRASS or terrain == Terrain.FLOODPLAIN


func is_floor() -> bool:
	return terrain == Terrain.FLOOR or terrain == Terrain.CLAY_FLOOR


## Only dry open ground. Anything that can flood or is under water is off limits, and
## interiors are not built on.
func is_buildable() -> bool:
	return terrain == Terrain.GRASS or terrain == Terrain.SOIL
