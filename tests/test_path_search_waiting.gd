extends GutTest
## PathSearch where a tile may not be known yet: it waits, goes on when the tile is known and loses
## no neighbour by it.

const BIG_CAP := 100000
## Tiles with x at or above this are not known.
var _known_before_x := 0
var _asked_unknown: Array[Vector2i] = []


func _is_free(tile: Vector2i) -> bool:
	if tile.x >= _known_before_x:
		_asked_unknown.append(tile)
	# Pillars on a grid, so that the way winds and a neighbour lost would change it.
	return tile.y >= -3 and tile.y <= 3 and not (tile.x % 3 == 0 and tile.y % 2 == 0 and tile.x > 0)


func _is_known(tile: Vector2i) -> bool:
	return tile.x < _known_before_x


func _cost_of(_tile: Vector2i) -> float:
	return 1.0


func _search(goal: Vector2i, is_known := Callable()) -> PathSearch:
	return PathSearch.new(Vector2i.ZERO, goal, _is_free, _cost_of, BIG_CAP, 1.0, is_known)


func test_a_search_waits_for_a_tile_and_goes_on_with_nothing_lost() -> void:
	var goal := Vector2i(20, 1)
	_known_before_x = 1000
	var all_known := _search(goal)
	all_known.step(BIG_CAP)
	assert_eq(all_known.state, PathSearch.State.FOUND)
	_known_before_x = 4
	var waiting := _search(goal, _is_known)
	var waits := 0
	while waiting.state != PathSearch.State.FOUND and waits < 100:
		waiting.step(BIG_CAP)
		if waiting.state == PathSearch.State.WAITING:
			waits += 1
			_known_before_x += 3
	assert_gt(waits, 3, "it waited as the tiles came")
	assert_eq(waiting.path, all_known.path)
	assert_eq(waiting.nodes_looked_at, all_known.nodes_looked_at, "and looked at the same tiles")
	assert_eq(_asked_unknown, [] as Array[Vector2i], "nothing is asked before it is known")


func test_a_waiting_search_does_nothing_until_asked_again() -> void:
	_known_before_x = 2
	var search := _search(Vector2i(10, 0), _is_known)
	search.step(BIG_CAP)
	assert_eq(search.state, PathSearch.State.WAITING)
	var looked_at := search.nodes_looked_at
	assert_eq(search.step(BIG_CAP), PathSearch.State.WAITING, "nothing is known more")
	assert_eq(search.nodes_looked_at, looked_at)
	assert_false(search.is_over())


func test_a_goal_that_is_not_known_waits_and_one_that_is_not_free_then_fails() -> void:
	_known_before_x = 5
	var goal := Vector2i(6, 0)
	var search := _search(goal, _is_known)
	assert_eq(search.state, PathSearch.State.WAITING)
	assert_eq(search.nodes_looked_at, 0)
	_known_before_x = 10
	assert_eq(search.step(BIG_CAP), PathSearch.State.FAILED, "a pillar stands on it")
	assert_true(search.is_over())


func test_a_search_with_all_tiles_known_never_waits() -> void:
	_known_before_x = 1000
	var search := _search(Vector2i(20, 1))
	search.step(BIG_CAP)
	assert_eq(search.state, PathSearch.State.FOUND)
