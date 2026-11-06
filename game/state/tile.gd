class_name Tile
extends RefCounted
## A snapshot of one tile's state. Changing the world goes through Chunk's setters, not here.

enum Terrain { GRASS, SOIL, WATER, WETLAND, FLOODPLAIN, FLOOR, WALL }

var terrain: Terrain = Terrain.GRASS
## Nothing sets it yet: the hook for frozen rivers, which can be walked across.
var frozen := false


## Water blocks movement unless it is frozen (a frozen river can be crossed), and so does a
## wall.
func is_walkable() -> bool:
	return (terrain != Terrain.WATER or frozen) and terrain != Terrain.WALL


## Only dry open ground. Anything that can flood or is under water is off limits, and
## interiors are not built on.
func is_buildable() -> bool:
	return terrain == Terrain.GRASS or terrain == Terrain.SOIL
