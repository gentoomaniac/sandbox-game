extends ResourceCase
## After an hour of rain the soil's surface is wet: it looks a step wetter than its moisture until
## a dry hour has passed (see SoilWetness).


func before_each() -> void:
	super.before_each()
	_world.set_terrain(_tile, Tile.Terrain.SOIL)


## The user, 2026-11-11 (task 175): the rain should show on the soil within the first hour.
func test_after_an_hour_of_rain_the_soil_looks_a_step_wetter_until_a_dry_hour() -> void:
	var layer := SoilWetness.new()
	add_child_autofree(layer)
	layer.show_world(_world)
	_world.set_moisture(_tile, 0.3)
	var alone := SoilWetness._columns[0]
	assert_eq(layer.get_cell_atlas_coords(_tile), Vector2i(alone, 0), "the first step above dry")
	var chunks: Array[Vector2i] = [Chunk.world_to_chunk(_tile)]
	layer.refresh_looks(chunks, SoilWetness.RAIN_WETS_SURFACE_FROM / 2.0)
	await wait_process_frames(2)
	assert_eq(layer.get_cell_atlas_coords(_tile), Vector2i(alone, 0), "a drizzle doesn't")
	layer.refresh_looks(chunks, 0.5)
	await wait_process_frames(2)
	assert_eq(layer.get_cell_atlas_coords(_tile), Vector2i(alone, 1))
	_world.set_moisture(_tile, 1.0)
	assert_eq(layer.get_cell_atlas_coords(_tile), Vector2i(alone, SoilWetness.LOOKS - 2))
	_world.set_moisture(_tile, 0.3)
	layer.refresh_looks(chunks, 0.0)
	await wait_process_frames(2)
	assert_eq(layer.get_cell_atlas_coords(_tile), Vector2i(alone, 0))
