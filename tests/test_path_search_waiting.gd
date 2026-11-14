extends GutTest
## PathSearch where a tile may not be known yet: it waits, goes on when the tile is known and loses
## no neighbour by it. And the Pathfinder's far queue, whose searches may wait.

const BIG_CAP := 100000
const USEC_PER_FRAME := 1000
const USEC_PER_LOOK := 100
const FAR := 100000

var _now := 0
## Tiles with x at or above this are not known.
var _known_before_x := 0
var _asked_unknown: Array[Vector2i] = []


func _clock() -> int:
	var now := _now
	_now += USEC_PER_LOOK
	return now


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


func _pathfinder(searches_per_frame := 2) -> Pathfinder:
	_now = 0
	return Pathfinder.new(searches_per_frame, USEC_PER_FRAME, _clock)


func _open_search(distance: int, is_known := Callable()) -> PathSearch:
	var is_free := func(_tile: Vector2i) -> bool: return true
	return PathSearch.new(
		Vector2i.ZERO, Vector2i(distance, 0), is_free, _cost_of, FAR, 1.0, is_known
	)


func test_a_far_search_runs_while_near_ones_are_queued_and_does_not_hold_them_up() -> void:
	var pathfinder := _pathfinder()
	var near := _open_search(5000)
	var far := _open_search(5000)
	pathfinder.queue(near)
	pathfinder.queue(far, true)
	pathfinder.tick()
	assert_gt(far.nodes_looked_at, 0)
	assert_gt(near.nodes_looked_at, 0, "the far one takes at most half of the time")
	assert_lt(far.nodes_looked_at, near.nodes_looked_at + Pathfinder.NODES_PER_CHECK * 2)


func test_a_far_search_is_not_starved_by_many_near_ones() -> void:
	var pathfinder := _pathfinder()
	for _i in 4:
		pathfinder.queue(_open_search(5000))
	var far := _open_search(5000)
	pathfinder.queue(far, true)
	pathfinder.tick()
	assert_gt(far.nodes_looked_at, 0)


func test_a_waiting_search_is_passed_over_and_takes_no_slot() -> void:
	var pathfinder := _pathfinder(1)
	_known_before_x = 0
	var waiting := _search(Vector2i(10, 0), _is_known)
	var far := _open_search(5000)
	var near := _open_search(5000)
	pathfinder.queue(waiting, true)
	pathfinder.queue(far, true)
	pathfinder.queue(near)
	pathfinder.tick()
	assert_eq(waiting.state, PathSearch.State.WAITING)
	assert_gt(far.nodes_looked_at, 0, "the one behind it is worked")
	assert_gt(near.nodes_looked_at, 0)
	assert_eq(pathfinder.waiting(), 3, "and the waiting one stays")
	_known_before_x = 1000
	_now = 0
	pathfinder.tick()
	assert_true(waiting.is_over(), "it goes on once its tiles are known")
	assert_eq(pathfinder.waiting(), 2)


func test_a_dropped_far_search_is_never_looked_at() -> void:
	var pathfinder := _pathfinder()
	var far := _open_search(50)
	pathfinder.queue(far, true)
	pathfinder.drop(far)
	pathfinder.tick()
	assert_eq(far.nodes_looked_at, 0)
	assert_eq(pathfinder.waiting(), 0)


func test_the_far_queue_is_worked_in_one_tick_of_the_number_given() -> void:
	var pathfinder := _pathfinder()
	pathfinder.far_every_ticks = 3
	var far := _open_search(50000)
	pathfinder.queue(far, true)
	var looked_at: Array[int] = []
	for _tick in 6:
		_now = 0
		pathfinder.tick()
		looked_at.append(far.nodes_looked_at)
	assert_eq(looked_at[0], 0)
	assert_eq(looked_at[1], 0)
	assert_gt(looked_at[2], 0, "the third tick")
	assert_eq(looked_at[3], looked_at[2])
	assert_eq(looked_at[4], looked_at[2])
	assert_gt(looked_at[5], looked_at[2], "the sixth")
