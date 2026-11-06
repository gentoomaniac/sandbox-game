extends GutTest
## Tile: the values derived from each terrain (walkable, buildable, floor).

const TERRAIN_RULES := {
	Tile.Terrain.GRASS: {"walkable": true, "buildable": true},
	Tile.Terrain.SOIL: {"walkable": true, "buildable": true},
	Tile.Terrain.WATER: {"walkable": false, "buildable": false},
	Tile.Terrain.WETLAND: {"walkable": true, "buildable": false},
	Tile.Terrain.FLOODPLAIN: {"walkable": true, "buildable": false},
	Tile.Terrain.FLOOR: {"walkable": true, "buildable": false, "floor": true},
	Tile.Terrain.CLAY_FLOOR: {"walkable": true, "buildable": false, "floor": true},
	Tile.Terrain.WALL: {"walkable": false, "buildable": false},
}


func test_derived_values_per_terrain() -> void:
	for terrain in TERRAIN_RULES:
		var tile := Tile.new()
		tile.terrain = terrain
		var rules: Dictionary = TERRAIN_RULES[terrain]
		var terrain_name: String = Tile.Terrain.keys()[terrain]
		assert_eq(tile.is_walkable(), rules.walkable, "%s walkable" % terrain_name)
		assert_eq(tile.is_buildable(), rules.buildable, "%s buildable" % terrain_name)
		assert_eq(tile.is_floor(), rules.get("floor", false), "%s floor" % terrain_name)


func test_frozen_water_is_walkable_but_not_buildable() -> void:
	var tile := Tile.new()
	tile.terrain = Tile.Terrain.WATER
	tile.frozen = true
	assert_true(tile.is_walkable())
	assert_false(tile.is_buildable())
