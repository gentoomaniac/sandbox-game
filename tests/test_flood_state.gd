extends GutTest
## The flood behind the dykes (FloodState, #103): the breach rule, the fill with its budget and
## volume, the drain.

## Higher than any dyke the generator lays.
const STRONGEST_LEVEL := 3.4
const NOW := 1000

var _world: World
var _flood: FloodState


func before_each() -> void:
	_world = CoastWorld.make()
	_flood = _world.flood


func _wet_tiles() -> Array[Vector2i]:
	var tiles: Array[Vector2i] = []
	for coords in _world.loaded_chunk_coords():
		tiles.append_array(_flood.wet_in_chunk(coords))
	return tiles


func test_a_level_under_every_dyke_breaks_none() -> void:
	var heights: Array[float] = []
	for dyke in CoastWorld.sea_dykes(_world):
		heights.append(_world.dykes.height_of(dyke))
	_flood.begin(_world, heights.min() - 0.6, NOW, 1)
	_flood.settle(_world)
	assert_eq(_flood.wet_count(), 0)


func test_a_dyke_lower_than_the_sea_breaks_down_and_the_water_comes_through() -> void:
	watch_signals(_flood)
	_flood.begin(_world, STRONGEST_LEVEL, NOW, 1)
	assert_signal_emitted(_flood, "breached")
	for dyke in CoastWorld.sea_dykes(_world):
		assert_almost_eq(_world.dykes.height_of(dyke), 0.3, 0.001, "every dyke is under 3.4 m")
	_flood.settle(_world)
	assert_gt(_flood.wet_count(), 100)
	assert_eq(_flood.phase, FloodState.Phase.STANDING)


func test_a_weak_dyke_that_holds_is_damaged_and_a_strong_one_is_not() -> void:
	var dykes := CoastWorld.sea_dykes(_world)
	_world.dykes.change(_world, dykes[0], 2.0, 0.0)
	_world.dykes.change(_world, dykes[1], 2.0, 1.0)
	_flood.begin(_world, 1.8, NOW, 1)
	assert_almost_eq(_world.dykes.height_of(dykes[0]), 1.7, 0.001, "damaged by its weakness")
	assert_almost_eq(_world.dykes.height_of(dykes[1]), 2.0, 0.001, "left alone")


func test_the_water_stays_on_land_lower_than_its_level_and_off_the_warften_and_the_foreshore(
) -> void:
	_flood.begin(_world, STRONGEST_LEVEL, NOW, 1)
	_flood.settle(_world)
	for tile in _wet_tiles():
		var terrain := _world.tile_at(tile).terrain
		assert_true(FloodState.FLOODABLE_TERRAINS.has(terrain), "%s is %s" % [tile, terrain])
		assert_gt(_flood.depth_at(tile), 0.0)
		assert_lt(_flood.depth_at(tile), STRONGEST_LEVEL)


func test_the_fill_stops_at_its_volume() -> void:
	_flood.begin(_world, STRONGEST_LEVEL, NOW, 1)
	_flood.settle(_world)
	var breaches := CoastWorld.sea_dykes(_world).size()
	var volume := 0.0
	for tile in _wet_tiles():
		volume += _flood.depth_at(tile)
	var per_breach: float = LandscapeRules.default_rules().value("surge", "volume_per_breach")
	assert_lte(volume, breaches * per_breach + STRONGEST_LEVEL)


func test_a_step_fills_no_more_tiles_than_its_budget() -> void:
	_flood.begin(_world, STRONGEST_LEVEL, NOW, 1)
	_flood.step_tiles(_world, 10)
	assert_eq(_flood.wet_count(), 10)
	assert_eq(_flood.phase, FloodState.Phase.FILLING)


func test_water_deeper_than_a_wade_is_not_walkable_and_a_shallow_one_is() -> void:
	_flood.begin(_world, STRONGEST_LEVEL, NOW, 1)
	_flood.settle(_world)
	var deep := Vector2i.ZERO
	var shallow := Vector2i.ZERO
	for tile in _wet_tiles():
		if _flood.depth_at(tile) > 0.5:
			deep = tile
		elif _flood.depth_at(tile) < 0.3:
			shallow = tile
	assert_ne(deep, Vector2i.ZERO)
	assert_true(_world.is_flooded(deep))
	assert_false(_world.is_ground_walkable(deep))
	if shallow != Vector2i.ZERO:
		assert_false(_world.is_flooded(shallow))


func test_the_water_stays_a_day_or_two_then_drains_shallowest_first() -> void:
	_flood.begin(_world, STRONGEST_LEVEL, NOW, 1)
	_flood.settle(_world)
	assert_between(_flood.drain_minute - NOW, (30 - 12) * 60, (30 + 12) * 60)
	_flood.advance(_world, _flood.drain_minute - 1, false)
	assert_eq(_flood.phase, FloodState.Phase.STANDING)
	var depths_before := {}
	for tile in _wet_tiles():
		depths_before[tile] = _flood.depth_at(tile)
	_flood.advance(_world, _flood.drain_minute, false)
	assert_eq(_flood.phase, FloodState.Phase.DRAINING)

	_flood.step_tiles(_world, depths_before.size() / 2)

	var deepest_dried := 0.0
	var shallowest_wet := INF
	for tile: Vector2i in depths_before:
		if _flood.depth_at(tile) == 0.0:
			deepest_dried = maxf(deepest_dried, depths_before[tile])
		else:
			shallowest_wet = minf(shallowest_wet, depths_before[tile])
	assert_lte(deepest_dried, shallowest_wet)
	_flood.settle(_world)
	assert_eq(_flood.wet_count(), 0)
	assert_eq(_flood.phase, FloodState.Phase.IDLE)


func test_a_damaged_dyke_is_mended_after_the_repair_days() -> void:
	var dyke := CoastWorld.sea_dykes(_world)[0]
	var generated := _world.dykes.height_at(dyke.pos)
	_flood.begin(_world, STRONGEST_LEVEL, NOW, 1)
	_flood.mend(_world, NOW + 5 * GameClock.MINUTES_PER_DAY)
	assert_almost_eq(_world.dykes.height_of(dyke), 0.3, 0.001, "not yet")
	_flood.mend(_world, NOW + 6 * GameClock.MINUTES_PER_DAY)
	assert_almost_eq(_world.dykes.height_of(dyke), generated, 0.001)


func test_the_view_draws_a_damaged_dyke_torn_until_it_is_mended() -> void:
	var view := WorldView.new()
	add_child_autofree(view)
	view.show_world(ChunkResidency.new(_world))
	var dyke := CoastWorld.sea_dykes(_world)[0]
	var rows: Dictionary = WorldObjectTypes.TYPES[WorldObjectTypes.DYKE]["look_rows"]
	assert_ne(view._objects.get_cell_atlas_coords(dyke.pos).y, rows[DykeProfile.TORN])
	_flood.begin(_world, STRONGEST_LEVEL, NOW, 1)
	assert_true(_flood.is_torn(dyke.pos))
	assert_eq(view._objects.get_cell_atlas_coords(dyke.pos).y, rows[DykeProfile.TORN])
	_flood.mend(_world, NOW + 6 * GameClock.MINUTES_PER_DAY)
	assert_false(_flood.is_torn(dyke.pos))
	assert_ne(view._objects.get_cell_atlas_coords(dyke.pos).y, rows[DykeProfile.TORN])
