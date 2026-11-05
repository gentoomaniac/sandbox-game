class_name Tile
extends RefCounted
## A snapshot of one tile's state. Changing the world goes through Chunk's setters, not here.

enum Terrain { GRASS, SOIL, WATER, WETLAND, FLOODPLAIN, FLOOR, WALL }

var terrain: Terrain = Terrain.GRASS
## Unused for now; will be driven by weather.
var water_level := 0.0
var frozen := false
var snow_depth := 0.0


## Water blocks movement unless it is frozen (a frozen river can be crossed), and so does a
## wall.
func is_walkable() -> bool:
	return (terrain != Terrain.WATER or frozen) and terrain != Terrain.WALL


## Only dry open ground. Anything that can flood or is under water is off limits, and
## interiors are not built on.
func is_buildable() -> bool:
	return terrain == Terrain.GRASS or terrain == Terrain.SOIL


## Only grass can be tilled. Floodplain, the most fertile land, needs a "tilled" property
## that keeps its flood behaviour first (see TASKS.md, Later).
func is_tillable() -> bool:
	return terrain == Terrain.GRASS


## Only soil: grass becomes soil through a player action (tilling).
func is_plantable() -> bool:
	return terrain == Terrain.SOIL
