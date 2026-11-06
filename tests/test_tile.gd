extends GutTest
## Tile: the values derived from each terrain (walkable, buildable, plantable).

const TERRAIN_RULES := {
	Tile.Terrain.GRASS: {"walkable": true, "buildable": true, "plantable": false},
	Tile.Terrain.SOIL: {"walkable": true, "buildable": true, "plantable": true},
	Tile.Terrain.WATER: {"walkable": false, "buildable": false, "plantable": false},
	Tile.Terrain.WETLAND: {"walkable": true, "buildable": false, "plantable": false},
	Tile.Terrain.FLOODPLAIN: {"walkable": true, "buildable": false, "plantable": false},
}


func test_derived_values_per_terrain() -> void:
	for terrain in TERRAIN_RULES:
		var tile := Tile.new()
		tile.terrain = terrain
		var rules: Dictionary = TERRAIN_RULES[terrain]
		var terrain_name: String = Tile.Terrain.keys()[terrain]
		assert_eq(tile.is_walkable(), rules.walkable, "%s walkable" % terrain_name)
		assert_eq(tile.is_buildable(), rules.buildable, "%s buildable" % terrain_name)
		assert_eq(tile.is_plantable(), rules.plantable, "%s plantable" % terrain_name)


func test_frozen_water_is_walkable_but_not_buildable() -> void:
	var tile := Tile.new()
	tile.terrain = Tile.Terrain.WATER
	tile.frozen = true
	assert_true(tile.is_walkable())
	assert_false(tile.is_buildable())
