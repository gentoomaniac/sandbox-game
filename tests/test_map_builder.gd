extends GutTest
## The pictures of the chunks for the world map: built a chunk at a time within a time budget, from
## the world's loaded chunks or generated for the map only, with the fog mixed in.

const NO_LIMIT := 1_000_000_000

var _state: GameState
var _builder: MapBuilder


func before_each() -> void:
	_state = GameState.new_game(7)
	_builder = MapBuilder.new(_state.world, _state.explored)


func _loaded_chunk() -> Vector2i:
	return Chunk.world_to_chunk(_state.player.tile())


func _pixel(coords: Vector2i, local: Vector2i) -> Color:
	return _builder.image_of(coords).get_pixelv(local)


func test_a_loaded_chunk_is_painted_from_the_world() -> void:
	var coords := _loaded_chunk()

	var is_done := _builder.update([coords], NO_LIMIT)

	assert_true(is_done)
	assert_not_null(_builder.texture_of(coords))
	var local := Chunk.local_pos(_state.player.tile())
	var chunk := _state.world.chunk_at(coords)
	assert_eq(_pixel(coords, local), MapColors.of_tile(_state.world, chunk, local))


func test_a_chunk_the_world_has_not_loaded_is_generated_for_the_map_only() -> void:
	var far := Vector2i(20, 20)
	assert_false(_state.world.is_chunk_loaded(far))

	await wait_until(
		func() -> bool: return _builder.update([far], NO_LIMIT), 10.0, "the chunk is built"
	)

	assert_not_null(_builder.texture_of(far))
	assert_false(_state.world.is_chunk_loaded(far), "the world loaded nothing")
	assert_false(_builder.is_generating())


func test_a_chunk_outside_the_world_is_left_out() -> void:
	var outside := Vector2i(World.MAX_SIZE_CHUNKS, 0)

	assert_true(_builder.update([outside], NO_LIMIT))
	assert_null(_builder.texture_of(outside))


func test_an_update_within_a_spent_budget_paints_one_chunk() -> void:
	var chunks := _state.world.loaded_chunk_coords().slice(0, 2)
	assert_eq(chunks.size(), 2)

	var is_done := _builder.update(chunks, 0)

	assert_false(is_done, "one chunk is left")
	assert_eq(_builder.built_count(), 1)
	assert_true(_builder.update(chunks, 0))
	assert_eq(_builder.built_count(), 2)


## A tile of a loaded chunk that is explored, or is not.
func _tile_in(coords: Vector2i, is_explored: bool) -> Vector2i:
	for index in Exploration.TILES_PER_CHUNK:
		var tile := Chunk.to_world(
			coords, Vector2i(index % Chunk.CHUNK_SIZE, index / Chunk.CHUNK_SIZE)
		)
		if _state.explored.is_explored(tile) == is_explored:
			return tile
	fail_test("no such tile in the chunk")
	return Vector2i.ZERO


func test_unexplored_land_is_fogged_and_explored_land_is_clear() -> void:
	var coords := _loaded_chunk()
	_builder.update([coords], NO_LIMIT)
	var chunk := _state.world.chunk_at(coords)
	var seen := Chunk.local_pos(_state.player.tile())
	var unseen := Chunk.local_pos(_tile_in(coords, false))

	assert_eq(_pixel(coords, seen), MapColors.of_tile(_state.world, chunk, seen))
	var fogged := MapFog.foggy(MapColors.image_of_chunk(_state.world, chunk))
	assert_eq(_pixel(coords, unseen), fogged.get_pixelv(unseen))
	assert_ne(_pixel(coords, unseen), MapColors.of_tile(_state.world, chunk, unseen))


func test_the_fog_clears_where_the_player_walks_on() -> void:
	var coords := _loaded_chunk()
	var unseen := _tile_in(coords, false)
	var local := Chunk.local_pos(unseen)
	_builder.update([coords], NO_LIMIT)
	var fogged := _pixel(coords, local)

	_state.teleport_to(unseen)
	_builder.update([coords], NO_LIMIT)

	var chunk := _state.world.chunk_at(coords)
	assert_ne(_pixel(coords, local), fogged)
	assert_eq(_pixel(coords, local), MapColors.of_tile(_state.world, chunk, local))


func test_a_refreshed_map_shows_what_was_built_since() -> void:
	var coords := _loaded_chunk()
	_builder.update([coords], NO_LIMIT)
	var house := _build_near_player()
	var local := Chunk.local_pos(house.origin)
	assert_eq(Chunk.world_to_chunk(house.origin), coords, "in the chunk of the map")

	_builder.update([coords], NO_LIMIT)
	assert_ne(_pixel(coords, local), MapColors.BUILDING, "not before the refresh")
	_builder.refresh()
	_builder.update([coords], NO_LIMIT)

	assert_eq(_pixel(coords, local), MapColors.BUILDING)


## A building on the first free land in the player's chunk and in their sight.
func _build_near_player() -> Building:
	var around := _state.player.tile()
	for y in range(-4, 5):
		for x in range(-4, 5):
			var origin := around + Vector2i(x, y)
			if Chunk.world_to_chunk(origin) == _loaded_chunk():
				var building := _state.world.place_building(BuildingTypes.SHACK, origin)
				if building != null:
					return building
	fail_test("no room for a building")
	return null
