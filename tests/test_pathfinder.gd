extends GutTest
## Pathfinder: how much of a frame the waiting searches take, and in what order.

const USEC_PER_FRAME := 1000
## The fake clock: each look at it is this much later than the one before.
const USEC_PER_LOOK := 100
const FAR := 100000

var _now := 0


func _clock() -> int:
	var now := _now
	_now += USEC_PER_LOOK
	return now


func _pathfinder(searches_per_frame := 2, usec_per_frame := USEC_PER_FRAME) -> Pathfinder:
	_now = 0
	return Pathfinder.new(searches_per_frame, usec_per_frame, _clock)


## A search over open ground to a goal `distance` tiles away.
func _search(distance: int) -> PathSearch:
	var is_free := func(_tile: Vector2i) -> bool: return true
	var cost_of := func(_tile: Vector2i) -> float: return 1.0
	return PathSearch.new(Vector2i.ZERO, Vector2i(distance, 0), is_free, cost_of, FAR)


func test_a_tick_spends_no_more_than_its_time() -> void:
	var pathfinder := _pathfinder()
	var search := _search(5000)
	pathfinder.queue(search)
	pathfinder.tick()
	# The clock is looked at before each step, and the tick ends at the look that is late.
	var steps_in_a_frame := USEC_PER_FRAME / USEC_PER_LOOK - 1
	assert_eq(search.nodes_looked_at, steps_in_a_frame * Pathfinder.NODES_PER_CHECK)
	assert_eq(search.state, PathSearch.State.RUNNING)


func test_a_search_goes_on_in_the_next_tick_and_is_done_in_the_end() -> void:
	var pathfinder := _pathfinder()
	var search := _search(2000)
	pathfinder.queue(search)
	var ticks := 0
	while pathfinder.waiting() > 0 and ticks < 1000:
		_now = 0
		pathfinder.tick()
		ticks += 1
	assert_eq(search.state, PathSearch.State.FOUND)
	assert_gt(ticks, 2, "spread over frames")


func test_no_more_searches_are_worked_in_a_tick_than_the_limit() -> void:
	var pathfinder := _pathfinder(2)
	var searches: Array[PathSearch] = []
	for _i in 5:
		searches.append(_search(1))
		pathfinder.queue(searches[-1])
	pathfinder.tick()
	var done := searches.filter(
		func(s: PathSearch) -> bool: return s.state != PathSearch.State.RUNNING
	)
	assert_eq(done.size(), 2)
	assert_eq(pathfinder.waiting(), 3)


func test_the_oldest_search_is_worked_first() -> void:
	var pathfinder := _pathfinder()
	var older := _search(5000)
	var newer := _search(5000)
	pathfinder.queue(older)
	pathfinder.queue(newer)
	pathfinder.tick()
	assert_gt(older.nodes_looked_at, 0)
	assert_eq(newer.nodes_looked_at, 0, "the older one takes the whole frame")


func test_a_dropped_search_is_never_looked_at() -> void:
	var pathfinder := _pathfinder()
	var search := _search(50)
	pathfinder.queue(search)
	pathfinder.drop(search)
	pathfinder.tick()
	assert_eq(search.nodes_looked_at, 0)
	assert_eq(pathfinder.waiting(), 0)


func test_a_search_that_is_done_after_the_time_leaves_the_next_one_waiting() -> void:
	var pathfinder := _pathfinder(2, USEC_PER_LOOK + 50)
	var first := _search(5)
	var second := _search(5)
	pathfinder.queue(first)
	pathfinder.queue(second)
	pathfinder.tick()
	assert_eq(first.state, PathSearch.State.FOUND, "one step of 16 tiles finishes it")
	assert_eq(second.nodes_looked_at, 0, "the time is out")
	assert_eq(pathfinder.waiting(), 1)
