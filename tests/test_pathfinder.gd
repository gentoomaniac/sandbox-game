extends GutTest
## Pathfinder: searches run on worker threads, at most as many at once as the limit, and their
## results come back on the main thread; a search that waits for a tile is parked; a dropped one
## is never looked at.

const FAR := 100000
## A flag the waiting search's tiles are known by, and what the Pathfinder's provide Callable
## says; the tests change them to order what happens.
var _is_known := false
var _entered := Semaphore.new()
var _gate := Semaphore.new()


func _search(distance: int, is_known := Callable()) -> PathSearch:
	var is_free := func(_tile: Vector2i) -> bool: return true
	var cost_of := func(_tile: Vector2i) -> float: return 1.0
	return PathSearch.new(
		Vector2i.ZERO, Vector2i(distance, 0), is_free, cost_of, FAR, 1.0, is_known
	)


## A search whose first question on a worker waits for `_gate`, after it has said so on `_entered`:
## it is provably running until the test lets it go.
func _blocking_search(distance: int) -> PathSearch:
	var is_holding := [true]
	var is_free := func(_tile: Vector2i) -> bool:
		if is_holding[0]:
			is_holding[0] = false
			_entered.post()
			_gate.wait()
		return true
	var cost_of := func(_tile: Vector2i) -> float: return 1.0
	# The goal is asked on this thread, by the constructor: it must not hold.
	is_holding[0] = false
	var search := PathSearch.new(Vector2i.ZERO, Vector2i(distance, 0), is_free, cost_of, FAR)
	is_holding[0] = true
	return search


func _wait_until_finished(pathfinder: Pathfinder, search: PathSearch) -> bool:
	for _i in 3000:
		pathfinder.tick()
		if pathfinder.is_finished(search):
			return true
		OS.delay_msec(1)
	return false


func test_a_search_runs_on_a_worker_and_is_finished_on_the_main_thread() -> void:
	var pathfinder := Pathfinder.new(2)
	var search := _search(50)
	pathfinder.queue(search)
	assert_false(pathfinder.is_finished(search))
	assert_true(_wait_until_finished(pathfinder, search))
	assert_eq(search.state, PathSearch.State.FOUND)
	assert_eq(search.path.size(), 50)
	pathfinder.take(search)
	assert_false(pathfinder.is_finished(search))
	assert_eq(pathfinder.waiting(), 0)


func test_no_more_searches_run_at_once_than_the_limit() -> void:
	var pathfinder := Pathfinder.new(2)
	var searches: Array[PathSearch] = []
	for _i in 3:
		searches.append(_blocking_search(20))
		pathfinder.queue(searches[-1])
	pathfinder.tick()
	_entered.wait()
	_entered.wait()
	assert_eq(pathfinder.running(), 2)
	assert_eq(pathfinder.waiting(), 3)
	pathfinder.tick()
	assert_false(_entered.try_wait(), "the third has not started: both workers are held")
	for _i in 3:
		_gate.post()
	for search in searches:
		assert_true(_wait_until_finished(pathfinder, search))
	assert_eq(pathfinder.waiting(), 0)


func test_a_search_that_waits_is_parked_and_run_again_when_it_is_given_what_it_waits_for() -> void:
	var pathfinder := Pathfinder.new(1)
	_is_known = false
	var search := _search(10, func(_tile: Vector2i) -> bool: return _is_known)
	var provided := func() -> bool: return _is_known
	pathfinder.queue(search, provided)
	assert_eq(search.state, PathSearch.State.WAITING, "its goal is not known")
	for _i in 20:
		pathfinder.tick()
		OS.delay_msec(1)
	assert_false(pathfinder.is_finished(search))
	assert_eq(pathfinder.running(), 0, "it is parked, and takes no worker")
	_is_known = true
	assert_true(_wait_until_finished(pathfinder, search))
	assert_eq(search.state, PathSearch.State.FOUND)


func test_a_search_waiting_with_every_worker_busy_does_not_block_them() -> void:
	var pathfinder := Pathfinder.new(1)
	_is_known = false
	var waiting := _search(10, func(_tile: Vector2i) -> bool: return _is_known)
	var other := _search(30)
	pathfinder.queue(waiting, func() -> bool: return _is_known)
	pathfinder.queue(other)
	assert_true(_wait_until_finished(pathfinder, other), "the one worker is free for another")
	assert_false(pathfinder.is_finished(waiting))


func test_a_queued_search_that_is_dropped_is_never_run() -> void:
	var pathfinder := Pathfinder.new(1)
	var first := _search(20000)
	var second := _search(50)
	pathfinder.queue(first)
	pathfinder.queue(second)
	pathfinder.tick()
	pathfinder.drop(second)
	assert_true(_wait_until_finished(pathfinder, first))
	pathfinder.tick()
	assert_eq(second.nodes_looked_at, 0)
	assert_false(pathfinder.is_finished(second))
	assert_eq(pathfinder.waiting(), 0)


func test_the_result_of_a_search_dropped_while_it_runs_is_dropped() -> void:
	var pathfinder := Pathfinder.new(1)
	var search := _blocking_search(20)
	pathfinder.queue(search)
	pathfinder.tick()
	_entered.wait()
	pathfinder.drop(search)
	assert_eq(pathfinder.waiting(), 0, "it is not counted")
	pathfinder.tick()
	assert_eq(pathfinder.running(), 1, "its task is held, and not reaped before it ends")
	_gate.post()
	for _i in 3000:
		pathfinder.tick()
		if pathfinder.running() == 0:
			break
		OS.delay_msec(1)
	assert_eq(pathfinder.running(), 0, "its task is reaped")
	assert_false(pathfinder.is_finished(search))


func test_a_pathfinder_freed_while_searches_run_waits_for_them() -> void:
	var pathfinder := Pathfinder.new(2)
	var search := _search(30000)
	pathfinder.queue(search)
	pathfinder.queue(_search(30000))
	pathfinder.tick()
	pathfinder = null
	assert_eq(search.state, PathSearch.State.FOUND, "the task was done when it was freed")
