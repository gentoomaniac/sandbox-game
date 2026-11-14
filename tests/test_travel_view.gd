extends TravelMaskCase
## TravelView: what a search sees of the tiles, live where the chunks are loaded and by the masks
## where they are not, and the same either way (see design/villagers/travel.md).

const WAY_CAP := 100000

var _rules := NpcRules.default_rules()


func before_each() -> void:
	super()
	for step in [Vector2i.ZERO, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.ONE]:
		load_chunk_and_neighbours(COAST + step)


func _view() -> TravelView:
	return TravelView.new(world, masks, _rules, world.clock.total_minutes())


func _unload_everything() -> void:
	for coords in world.loaded_chunk_coords():
		world.remove_chunk(coords)


## The search for a way over the view, with the masks made when it waits for them.
func _find_way(view: TravelView, start: Vector2i, goal: Vector2i) -> PathSearch:
	var search := PathSearch.new(
		start, goal, view.is_free, view.cost_of, WAY_CAP, 1.0, view.is_known
	)
	while not search.is_over():
		if search.step(WAY_CAP) == PathSearch.State.WAITING:
			masks.update(true)
	return search


func _chunks_of(path: Array[Vector2i]) -> Dictionary:
	var chunks := {}
	for tile in path:
		chunks[Chunk.world_to_chunk(tile)] = true
	return chunks


func test_a_far_way_is_the_way_found_with_the_same_chunks_loaded() -> void:
	var start := empty_row(COAST, Tile.Terrain.GRASS)
	var goal := empty_row(COAST + Vector2i.ONE, Tile.Terrain.GRASS)
	# Something in the way, taken off and put down, which the far view must follow too.
	var wall := empty_row(COAST + Vector2i.RIGHT, Tile.Terrain.GRASS, 8)
	for x in 8:
		world.add_object(WorldObject.new(WorldObjectTypes.PEN_FENCE, wall + Vector2i(x, 0)))
	world.take_off(find_object(COAST, WorldObjectTypes.WILLOW))
	var near := _find_way(_view(), start, goal)
	assert_eq(near.state, PathSearch.State.FOUND)
	assert_gt(_chunks_of(near.path).size(), 2, "a way across several chunks")
	_unload_everything()
	var far := _find_way(_view(), start, goal)
	assert_eq(far.state, PathSearch.State.FOUND)
	assert_eq(far.path, near.path)
	assert_eq(far.nodes_looked_at, near.nodes_looked_at)


func test_a_search_over_masks_not_made_yet_waits_for_them() -> void:
	_unload_everything()
	var start := tile_of(COAST, Vector2i(3, 3))
	var view := _view()
	var search := PathSearch.new(
		start, start + Vector2i(40, 0), view.is_free, view.cost_of, WAY_CAP, 1.0, view.is_known
	)
	assert_eq(search.state, PathSearch.State.WAITING, "the goal's mask is asked for")
	assert_eq(search.nodes_looked_at, 0)
	assert_eq(masks.mask_coords().size(), 0)
	masks.wait_for_mask(Chunk.world_to_chunk(start + Vector2i(40, 0)))
	assert_ne(search.step(WAY_CAP), PathSearch.State.FOUND, "the first tiles still wait")


func test_a_tile_is_known_when_live_or_its_mask_is_made_and_outside_the_world_always() -> void:
	var view := _view()
	var tile := tile_of(COAST, Vector2i(10, 10))
	assert_true(view.is_live(tile))
	assert_true(view.is_known(tile))
	_unload_everything()
	assert_false(view.is_live(tile))
	assert_false(view.is_known(tile), "its mask is asked for")
	masks.wait_for_mask(COAST)
	assert_true(view.is_known(tile))
	var outside := Vector2i(World.MAX_SIZE_CHUNKS * Chunk.CHUNK_SIZE, 0)
	assert_true(view.is_known(outside))
	assert_false(view.is_free(outside))


func test_far_costs_and_answers_are_those_of_the_loaded_chunk_whatever_is_on_it() -> void:
	world.clock.day = 45
	var tall_grass := empty_row(COAST, Tile.Terrain.GRASS, 4)
	world.add_object(WorldObject.new(WorldObjectTypes.TALL_GRASS, tall_grass))
	world.add_object(WorldObject.new(WorldObjectTypes.PEN_GATE, tall_grass + Vector2i.RIGHT))
	world.wear_tile(tall_grass + Vector2i(2, 0), 1000.0)
	world.set_terrain(tall_grass + Vector2i(3, 0), Tile.Terrain.SOIL)
	var view := _view()
	var near_free := {}
	var near_cost := {}
	for y in Chunk.CHUNK_SIZE:
		for x in Chunk.CHUNK_SIZE:
			var tile := tile_of(COAST, Vector2i(x, y))
			near_free[tile] = view.is_free(tile)
			near_cost[tile] = view.cost_of(tile)
	assert_eq(near_cost[tall_grass], 1.0 + _rules.travel("cost_object"), "the rule itself")
	assert_eq(near_cost[tall_grass + Vector2i.RIGHT], 1.0, "nobody spoils a gate")
	assert_eq(near_cost[tall_grass + Vector2i(2, 0)], _rules.travel("cost_path"))
	_unload_everything()
	masks.wait_for_mask(COAST)
	assert_false(view.is_live(tall_grass))
	for tile: Vector2i in near_free:
		assert_eq(view.is_free(tile), near_free[tile], "free %s" % tile)
		assert_eq(view.cost_of(tile), near_cost[tile], "cost %s" % tile)


func test_a_big_object_whose_chunk_is_not_loaded_closes_the_tiles_it_reaches_for_good() -> void:
	var west := COAST + Vector2i.LEFT
	var ewer := put_down_on_grass(WorldObjectTypes.EWER, tile_of(west, Vector2i(28, 10)))
	var covered: Vector2i = ewer.tiles().back()
	assert_eq(Chunk.world_to_chunk(covered), COAST, "it reaches into the chunk")
	world.remove_chunk(west)
	var view := _view()
	assert_true(world.is_chunk_loaded(COAST))
	assert_true(world.is_walkable(covered), "the world alone does not see it: its chunk is gone")
	assert_false(view.is_live(covered), "so the rim is the mask's")
	var search := _find_way(view, tile_of(COAST, Vector2i(16, 16)), covered)
	assert_eq(search.state, PathSearch.State.FAILED, "no way to a goal under the ewer")
	assert_false(view.is_free(covered))
	world.add_chunk(generator.generate_chunk(west))
	assert_true(view.is_live(covered))
	assert_false(view.is_free(covered), "and it stays closed when the chunk is loaded")


func test_the_time_of_the_view_is_the_tide_and_season_of_the_search_not_the_clock() -> void:
	load_chunk_and_neighbours(MUD)
	var tile := empty_row(MUD, Tile.Terrain.MUD)
	set_low_water()
	var at_high_water := TravelView.new(world, masks, _rules, HIGH_WATER_HOUR)
	assert_false(at_high_water.is_free(tile), "live: flooded then, whatever the clock")
	_unload_everything()
	masks.wait_for_mask(Chunk.world_to_chunk(tile))
	assert_false(at_high_water.is_free(tile), "far: the same")
	assert_true(_view().is_free(tile), "the clock is at low water")


func test_a_building_is_closed_live_and_far() -> void:
	var building: Building = null
	for y in range(0, Chunk.CHUNK_SIZE, 3):
		for x in range(0, Chunk.CHUNK_SIZE, 3):
			if building == null:
				building = world.place_building(BuildingTypes.SHACK, tile_of(COAST, Vector2i(x, y)))
	assert_not_null(building)
	var door := building.door_tile()
	var view := _view()
	assert_false(view.is_free(door))
	_unload_everything()
	masks.wait_for_mask(COAST)
	assert_false(view.is_free(door))
