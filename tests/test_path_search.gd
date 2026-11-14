extends GutTest
## PathSearch: the way over tiles for a villager, round and through what is in it, kept to
## cheap ground, in legs when it is long, and in pieces when it is spread over frames.

const OPEN_FIELD := 200
const BIG_CAP := 100000


## A room of FLOOR tiles `size` wide, with a wall column at `wall_x` from the top down to
## `gap_y` (none if `gap_y` is the height), and a gate in the wall at `gate`.
func _room(size: Vector2i, wall_x := -1, gap_y := 0, gate := Vector2i(-1, -1)) -> Interior:
	var room := Interior.new()
	room.size = size
	for y in size.y:
		for x in size.x:
			var is_wall := x == wall_x and y != gap_y
			room.set_terrain(Vector2i(x, y), Tile.Terrain.WALL if is_wall else Tile.Terrain.FLOOR)
	if gate != Vector2i(-1, -1):
		room.set_terrain(gate, Tile.Terrain.FLOOR)
		room.add_object(WorldObject.new(WorldObjectTypes.PEN_GATE, gate))
	return room


func _search_in(room: GameMap, start: Vector2i, goal: Vector2i, weight := 1.0) -> PathSearch:
	var is_free := func(tile: Vector2i) -> bool: return room.is_walkable(tile)
	return PathSearch.new(
		start, goal, is_free, func(_tile: Vector2i) -> float: return 1.0, BIG_CAP, weight
	)


func _is_walked_tile_by_tile(start: Vector2i, path: Array[Vector2i]) -> bool:
	var from := start
	for tile in path:
		if (tile - from).abs().x + (tile - from).abs().y != 1:
			return false
		from = tile
	return true


func test_a_way_round_a_wall_goes_through_its_gap() -> void:
	var room := _room(Vector2i(7, 7), 3, 6)
	var search := _search_in(room, Vector2i(1, 3), Vector2i(5, 3))
	assert_eq(search.step(BIG_CAP), PathSearch.State.FOUND)
	assert_true(_is_walked_tile_by_tile(Vector2i(1, 3), search.path))
	assert_eq(search.path.back(), Vector2i(5, 3))
	assert_has(search.path, Vector2i(3, 6), "the gap")
	for tile in search.path:
		assert_true(room.is_walkable(tile), str(tile))


func test_a_way_goes_through_a_gate() -> void:
	var room := _room(Vector2i(7, 7), 3, 7, Vector2i(3, 2))
	var search := _search_in(room, Vector2i(1, 3), Vector2i(5, 3))
	assert_eq(search.step(BIG_CAP), PathSearch.State.FOUND)
	assert_has(search.path, Vector2i(3, 2), "the gate, shut as it is")


func test_there_is_no_way_into_a_closed_in_place() -> void:
	var room := _room(Vector2i(7, 7), 3, 7)
	var search := _search_in(room, Vector2i(1, 3), Vector2i(5, 3))
	assert_eq(search.step(BIG_CAP), PathSearch.State.FAILED)
	assert_lt(search.nodes_looked_at, 7 * 7, "it looked where it could, once")
	assert_eq(search.path, [] as Array[Vector2i])


func test_a_goal_that_cannot_be_stood_on_is_no_way_at_once() -> void:
	var room := _room(Vector2i(7, 7), 3, 7)
	var search := _search_in(room, Vector2i(1, 3), Vector2i(3, 3))
	assert_eq(search.state, PathSearch.State.FAILED)
	assert_eq(search.nodes_looked_at, 0)


func test_the_start_is_the_goal() -> void:
	var search := _search_in(_room(Vector2i(3, 3)), Vector2i(1, 1), Vector2i(1, 1))
	assert_eq(search.step(10), PathSearch.State.FOUND)
	assert_eq(search.path, [] as Array[Vector2i])


func test_someone_who_stands_where_they_may_not_can_leave() -> void:
	var room := _room(Vector2i(7, 7), 3, 7)
	var start := Vector2i(3, 3)
	assert_false(room.is_walkable(start), "in the wall")
	var search := _search_in(room, start, Vector2i(5, 5))
	assert_eq(search.step(BIG_CAP), PathSearch.State.FOUND)
	assert_eq(search.path.back(), Vector2i(5, 5))


func test_a_lane_is_preferred_to_the_grass_beside_it() -> void:
	var room := _room(Vector2i(9, 4))
	var lane := 1
	var is_free := func(tile: Vector2i) -> bool: return room.is_walkable(tile)
	var cost_of := func(tile: Vector2i) -> float: return 0.3 if tile.y == lane else 1.0
	# 0.3 is the cheapest tile, the guess that never takes a longer way than the best.
	var search := PathSearch.new(Vector2i(0, 2), Vector2i(8, 2), is_free, cost_of, BIG_CAP, 0.3)
	assert_eq(search.step(BIG_CAP), PathSearch.State.FOUND)
	assert_has(search.path, Vector2i(4, lane), "along the lane, not the straight line on grass")


func test_an_open_diagonal_is_not_searched_all_over() -> void:
	var is_free := func(_tile: Vector2i) -> bool: return true
	var cost_of := func(_tile: Vector2i) -> float: return 1.0
	var search := PathSearch.new(Vector2i.ZERO, Vector2i(100, 100), is_free, cost_of, BIG_CAP)
	assert_eq(search.step(BIG_CAP), PathSearch.State.FOUND)
	assert_eq(search.path.size(), 200)
	assert_lt(search.nodes_looked_at, 600, "a bounding box would be 10,000")


func test_a_search_that_reaches_its_cap_walks_a_leg_to_the_tile_nearest_the_goal() -> void:
	var is_free := func(tile: Vector2i) -> bool: return tile.abs().x < OPEN_FIELD
	var cost_of := func(_tile: Vector2i) -> float: return 1.0
	var goal := Vector2i(150, 0)
	var search := PathSearch.new(Vector2i.ZERO, goal, is_free, cost_of, 50)
	assert_eq(search.step(BIG_CAP), PathSearch.State.LEG)
	assert_eq(search.nodes_looked_at, 50)
	assert_lt((goal - search.path.back()).length(), goal.length())
	assert_true(_is_walked_tile_by_tile(Vector2i.ZERO, search.path))


func test_a_goal_behind_a_wall_longer_than_the_cap_is_given_up_within_two_legs() -> void:
	var is_free := func(tile: Vector2i) -> bool: return tile.x != 20 or absi(tile.y) > 30
	var cost_of := func(_tile: Vector2i) -> float: return 1.0
	var start := Vector2i(10, 0)
	var states: Array[PathSearch.State] = []
	for leg in 3:
		var search := PathSearch.new(start, Vector2i(30, 0), is_free, cost_of, 300)
		states.append(search.step(BIG_CAP))
		if search.state != PathSearch.State.LEG:
			break
		start = search.path.back()
	assert_eq(states, [PathSearch.State.LEG, PathSearch.State.FAILED] as Array[PathSearch.State])


func test_a_search_in_pieces_finds_the_way_of_one_in_a_go() -> void:
	var room := _room(Vector2i(20, 20), 10, 17)
	var in_a_go := _search_in(room, Vector2i(2, 3), Vector2i(17, 4))
	in_a_go.step(BIG_CAP)
	var in_pieces := _search_in(room, Vector2i(2, 3), Vector2i(17, 4))
	var pieces := 0
	while in_pieces.step(7) == PathSearch.State.RUNNING:
		pieces += 1
	assert_gt(pieces, 3)
	assert_eq(in_pieces.state, PathSearch.State.FOUND)
	assert_eq(in_pieces.path, in_a_go.path)


func test_a_strip_of_tiles_that_cannot_be_stood_on_is_gone_round() -> void:
	# As the edge of the loaded chunks is: what is not there is not free.
	var is_strip := func(tile: Vector2i) -> bool:
		return tile.x in range(10, 15) and absi(tile.y) <= 5
	var is_free := func(tile: Vector2i) -> bool: return not is_strip.call(tile)
	var cost_of := func(_tile: Vector2i) -> float: return 1.0
	var search := PathSearch.new(Vector2i.ZERO, Vector2i(20, 0), is_free, cost_of, BIG_CAP)
	assert_eq(search.step(BIG_CAP), PathSearch.State.FOUND)
	assert_gt(search.path.size(), 20, "round the strip, not over it")
	for tile in search.path:
		assert_false(is_strip.call(tile), str(tile))


func test_a_strip_across_the_whole_way_is_no_way() -> void:
	var is_free := func(tile: Vector2i) -> bool:
		return tile.x not in range(10, 15) and absi(tile.x) <= 30 and absi(tile.y) <= 8
	var cost_of := func(_tile: Vector2i) -> float: return 1.0
	var search := PathSearch.new(Vector2i.ZERO, Vector2i(20, 0), is_free, cost_of, BIG_CAP)
	assert_eq(search.step(BIG_CAP), PathSearch.State.FAILED)


func test_the_travel_numbers_of_the_data_file_have_no_problems() -> void:
	var rules := NpcRules.default_rules()
	var problems := rules.problems().filter(
		func(text: String) -> bool: return text.begins_with("[travel]")
	)
	assert_eq(problems, [])
	for key in NpcRules.TRAVEL_KEYS:
		assert_gt(rules.travel(key), 0.0, key)


func test_a_travel_number_that_is_not_above_zero_is_reported() -> void:
	var values := DataFile.read_sections(NpcRules.DEFAULT_PATH)
	values["travel"]["max_nodes"] = 0
	assert_has(NpcRules.new(values).problems(), "[travel] max_nodes must be above 0")


func test_each_tile_is_asked_once() -> void:
	var asked := {}
	var is_free := func(tile: Vector2i) -> bool:
		asked[tile] = asked.get(tile, 0) + 1
		return tile.abs().x < 8 and tile.abs().y < 8
	var cost_of := func(_tile: Vector2i) -> float: return 1.0
	var search := PathSearch.new(Vector2i.ZERO, Vector2i(7, 0), is_free, cost_of, BIG_CAP)
	search.step(BIG_CAP)
	for tile: Vector2i in asked:
		assert_eq(asked[tile], 1, str(tile))
