class_name Tile
extends RefCounted
## A snapshot of one tile's state. Changing the world goes through Chunk's setters, not here.

enum Terrain { GRASS, SOIL, WATER, WETLAND, FLOODPLAIN }

var terrain: Terrain = Terrain.GRASS
## Unused for now; will be driven by weather.
var water_level := 0.0
var frozen := false
var snow_depth := 0.0


## Water blocks movement unless it is frozen (a frozen river can be crossed).
func is_walkable() -> bool:
	return terrain != Terrain.WATER or frozen


## Anything that can flood or is under water is off limits for building.
func is_buildable() -> bool:
	return terrain != Terrain.WATER and terrain != Terrain.WETLAND and terrain != Terrain.FLOODPLAIN


## Only grass can be tilled. Floodplain, the most fertile land, needs a "tilled" property
## that keeps its flood behaviour first (see TASKS.md, Later).
func is_tillable() -> bool:
	return terrain == Terrain.GRASS


## Only soil: grass becomes soil through a player action (tilling).
func is_plantable() -> bool:
	return terrain == Terrain.SOIL
