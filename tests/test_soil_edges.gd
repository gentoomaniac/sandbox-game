extends ResourceCase
## The edges of wet patches of tilled soil (see SoilWetness): where they are drawn, and that they
## go with the wetter tile, its tilling and under snow.


func before_each() -> void:
	super.before_each()
	_world.set_terrain(_tile, Tile.Terrain.SOIL)


func test_wet_soil_is_a_patch_drawn_over_it_and_its_drier_tilled_neighbours() -> void:
	var east := _tile + Vector2i.RIGHT
	var south_east := _tile + Vector2i(1, 1)
	for pos in [east, _tile + Vector2i.DOWN, south_east]:
		_world.set_terrain(pos, Tile.Terrain.SOIL)
		_world.set_moisture(pos, 0.0)
	_world.set_moisture(_tile, 0.0)
	var layer := SoilWetness.new()
	add_child_autofree(layer)
	layer.show_world(_world)
	var none := SoilWetness.NO_TILE
	assert_eq(layer.edge_at(east, SoilWetness.WEST), none, "dry beside dry")
	_world.set_moisture(_tile, 1.0)
	assert_ne(layer.edge_at(east, SoilWetness.WEST), none, "the wet brown bulges east")
	assert_ne(layer.edge_at(_tile, SoilWetness.EAST), none, "and the dry bites back")
	assert_ne(layer.edge_at(_tile, SoilWetness.SOUTH_EAST), none, "the patch's corner is round")
	assert_eq(layer.edge_at(south_east, SoilWetness.NORTH_WEST), none)
	assert_eq(layer.edge_at(_tile, SoilWetness.WEST), none, "not into the grass")
	_world.set_moisture(east, 1.0)
	assert_eq(layer.edge_at(east, SoilWetness.WEST), none, "as wet: no edge")
	_world.set_moisture(_tile, 0.0)
	assert_ne(layer.edge_at(_tile, SoilWetness.EAST), none)


## A tilled tile east of the test tile, dry, beside the test tile soaked, and a layer showing them.
func _wet_beside_dry(is_covered := func(_pos: Vector2i) -> bool: return false) -> SoilWetness:
	_world.set_terrain(_tile + Vector2i.RIGHT, Tile.Terrain.SOIL)
	_world.set_moisture(_tile + Vector2i.RIGHT, 0.0)
	_world.set_moisture(_tile, 1.0)
	var layer := SoilWetness.new()
	add_child_autofree(layer)
	layer.show_world(_world, is_covered)
	assert_ne(layer.edge_at(_tile + Vector2i.RIGHT, SoilWetness.WEST), SoilWetness.NO_TILE)
	return layer


func test_an_edge_goes_when_the_wetter_tile_grows_back_to_grass() -> void:
	var layer := _wet_beside_dry()
	_world.set_terrain(_tile, Tile.Terrain.GRASS)
	assert_eq(layer.edge_at(_tile + Vector2i.RIGHT, SoilWetness.WEST), SoilWetness.NO_TILE)


func test_snow_on_either_tile_clears_the_edge() -> void:
	var snowed := {}
	var layer := _wet_beside_dry(func(pos: Vector2i) -> bool: return snowed.has(pos))
	var east := _tile + Vector2i.RIGHT
	for covered: Vector2i in [_tile, east]:
		snowed[covered] = true
		layer.redraw_tile(covered)
		assert_eq(layer.edge_at(east, SoilWetness.WEST), SoilWetness.NO_TILE, str(covered))
		snowed.erase(covered)
		layer.redraw_tile(covered)
		assert_ne(layer.edge_at(east, SoilWetness.WEST), SoilWetness.NO_TILE, "thawed")
