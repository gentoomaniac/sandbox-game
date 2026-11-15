extends TravelMaskCase
## TravelView: what a search sees of the tiles, from the masks and a snapshot, and the same as what
## the loaded world says (see design/villagers/travel.md).

const WAY_CAP := 100000

var _rules := NpcRules.default_rules()


func before_each() -> void:
	super()
	for step in [Vector2i.ZERO, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.ONE]:
		load_chunk_and_neighbours(COAST + step)


func _view() -> TravelView:
	var snapshot := TravelSnapshot.of(world, 0)
	return TravelView.new(snapshot, _rules, world.clock.total_minutes())


## The search over the view, with the masks given when it waits for them, on this thread.
func _find_way(view: TravelView, start: Vector2i, goal: Vector2i) -> PathSearch:
	var search := PathSearch.new(
		start, goal, view.is_free, view.cost_of, WAY_CAP, 1.0, view.is_known
	)
	while not search.is_over():
		if search.step(WAY_CAP) == PathSearch.State.WAITING:
			while not view.provide(masks):
				masks.update(true)
	return search


## The same search over the loaded world itself, as the villagers' near search was.
func _find_live_way(start: Vector2i, goal: Vector2i) -> PathSearch:
	var is_free := func(tile: Vector2i) -> bool:
		return Npcs.can_stand_at(world, Vector2(tile) + Vector2(0.5, 0.5))
	var cost_of := func(tile: Vector2i) -> float:
		var object := world.object_at(tile)
		return (
			1.0
			+ (
				_rules.travel("cost_object")
				if object != null and NpcTravel.is_trampled(object)
				else 0.0
			)
		)
	var search := PathSearch.new(start, goal, is_free, cost_of, WAY_CAP, 1.0)
	search.step(WAY_CAP)
	return search


func _unload_everything() -> void:
	for coords in world.loaded_chunk_coords():
		world.remove_chunk(coords)


func _chunks_of(path: Array[Vector2i]) -> Dictionary:
	var chunks := {}
	for tile in path:
		chunks[Chunk.world_to_chunk(tile)] = true
	return chunks


func test_a_way_over_the_masks_is_the_way_over_the_loaded_world() -> void:
	var start := empty_row(COAST, Tile.Terrain.GRASS)
	var goal := empty_row(COAST + Vector2i.ONE, Tile.Terrain.GRASS)
	var wall := empty_row(COAST + Vector2i.RIGHT, Tile.Terrain.GRASS, 8)
	for x in 8:
		world.add_object(WorldObject.new(WorldObjectTypes.PEN_FENCE, wall + Vector2i(x, 0)))
	world.take_off(find_object(COAST, WorldObjectTypes.WILLOW))
	var live := _find_live_way(start, goal)
	assert_eq(live.state, PathSearch.State.FOUND)
	assert_gt(_chunks_of(live.path).size(), 2, "a way across several chunks")
	var over_masks := _find_way(_view(), start, goal)
	assert_eq(over_masks.state, PathSearch.State.FOUND)
	assert_eq(over_masks.path, live.path)
	assert_eq(over_masks.nodes_looked_at, live.nodes_looked_at)
	_unload_everything()
	var unloaded := _find_way(_view(), start, goal)
	assert_eq(unloaded.path, live.path, "loaded or not changes no answer")


func test_a_search_waits_for_the_masks_it_lacks_and_notes_which() -> void:
	var view := _view()
	var start := tile_of(COAST, Vector2i(3, 3))
	var goal := start + Vector2i(40, 0)
	var search := PathSearch.new(
		start, goal, view.is_free, view.cost_of, WAY_CAP, 1.0, view.is_known
	)
	assert_eq(search.state, PathSearch.State.WAITING, "the goal's mask is not given")
	assert_eq(search.nodes_looked_at, 0)
	assert_eq(view.missing.keys(), [Chunk.world_to_chunk(goal)])
	assert_false(view.provide(masks), "asked for, not made yet")
	masks.wait_for_mask(Chunk.world_to_chunk(goal))
	assert_true(view.provide(masks))
	assert_eq(view.missing.size(), 0)
	assert_ne(search.step(WAY_CAP), PathSearch.State.FOUND, "then the first tiles wait")


func test_a_tile_outside_the_world_is_known_and_closed() -> void:
	var view := _view()
	var outside := Vector2i(World.MAX_SIZE_CHUNKS * Chunk.CHUNK_SIZE, 0)
	assert_true(view.is_known(outside))
	assert_false(view.is_free(outside))


func test_costs_and_answers_are_those_of_the_loaded_chunk_whatever_is_on_it() -> void:
	world.clock.day = 45
	var tall_grass := empty_row(COAST, Tile.Terrain.GRASS, 4)
	world.add_object(WorldObject.new(WorldObjectTypes.TALL_GRASS, tall_grass))
	world.add_object(WorldObject.new(WorldObjectTypes.PEN_GATE, tall_grass + Vector2i.RIGHT))
	world.set_wear_days(tall_grass + Vector2i(2, 0), PathRules.default_rules().path_after_days())
	world.set_terrain(tall_grass + Vector2i(3, 0), Tile.Terrain.SOIL)
	var view := _view()
	masks.wait_for_mask(COAST)
	assert_false(view.is_known(tall_grass), "not given yet")
	assert_true(view.provide(masks))
	for y in Chunk.CHUNK_SIZE:
		for x in Chunk.CHUNK_SIZE:
			var tile := tile_of(COAST, Vector2i(x, y))
			var is_live_free := Npcs.can_stand_at(world, Vector2(tile) + Vector2(0.5, 0.5))
			assert_eq(view.is_free(tile), is_live_free, "free %s" % tile)
	assert_eq(view.cost_of(tall_grass), 1.0 + _rules.travel("cost_object"), "the rule itself")
	assert_eq(view.cost_of(tall_grass + Vector2i.RIGHT), 1.0, "nobody spoils a gate")
	assert_eq(view.cost_of(tall_grass + Vector2i(2, 0)), _rules.travel("cost_path"))


func test_a_big_object_whose_chunk_is_not_loaded_closes_the_tiles_it_reaches_for_good() -> void:
	var west := COAST + Vector2i.LEFT
	var ewer := put_down_on_grass(WorldObjectTypes.EWER, tile_of(west, Vector2i(28, 10)))
	var covered: Vector2i = ewer.tiles().back()
	assert_eq(Chunk.world_to_chunk(covered), COAST, "it reaches into the chunk")
	world.remove_chunk(west)
	assert_true(world.is_walkable(covered), "the world alone does not see it: its chunk is gone")
	var search := _find_way(_view(), tile_of(COAST, Vector2i(16, 16)), covered)
	assert_eq(search.state, PathSearch.State.FAILED, "no way to a goal under the ewer")
	world.add_chunk(generator.generate_chunk(west))
	var view := _view()
	view.is_known(covered)
	masks.wait_for_mask(COAST)
	view.provide(masks)
	assert_false(view.is_free(covered), "and it stays closed when the chunk is loaded")


func test_the_time_of_the_view_is_the_tide_and_season_of_the_search_not_the_clock() -> void:
	load_chunk_and_neighbours(MUD)
	var tile := empty_row(MUD, Tile.Terrain.MUD)
	set_low_water()
	var at_high_water := TravelView.new(TravelSnapshot.of(world, 0), _rules, HIGH_WATER_HOUR)
	at_high_water.is_known(tile)
	masks.wait_for_mask(Chunk.world_to_chunk(tile))
	at_high_water.provide(masks)
	assert_false(at_high_water.is_free(tile), "flooded then, whatever the clock")
	var now := _view()
	now.is_known(tile)
	now.provide(masks)
	assert_true(now.is_free(tile), "the clock is at low water")


func test_a_building_is_closed_in_the_snapshot_and_a_later_one_is_not_seen() -> void:
	var building: Building = null
	for y in range(0, Chunk.CHUNK_SIZE, 3):
		for x in range(0, Chunk.CHUNK_SIZE, 3):
			if building == null:
				building = world.place_building(BuildingTypes.SHACK, tile_of(COAST, Vector2i(x, y)))
	assert_not_null(building)
	var door := building.door_tile()
	var view := _view()
	view.is_known(door)
	masks.wait_for_mask(COAST)
	view.provide(masks)
	assert_false(view.is_free(door), "the door too")
	var snapshot := TravelSnapshot.of(world, 5)
	assert_true(snapshot.buildings.has(door))
	assert_true(snapshot.is_current(world, 6, 10))
	assert_false(snapshot.is_current(world, 20, 10), "old")
	world.remove_building(building)
	assert_false(snapshot.is_current(world, 6, 10), "the world has changed since")
