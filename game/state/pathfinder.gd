class_name Pathfinder
extends RefCounted
## The searches that are waiting for their turn (PathSearch), and how much of a frame they may
## take: each `tick` works on the oldest ones, at most `searches_per_frame` of them, and stops
## when `search_usec_per_frame` microseconds are spent, so many villagers on their way never make
## the game stutter. A search that is not done goes on in the next tick. Whoever queued a search
## reads its state; the Pathfinder only works it.
##
## Far searches (over ground that is not loaded, so they may wait for a mask) have a queue of their
## own: the oldest of them takes one of the frame's searches and at most half of its time, so
## neither holds up the other. A search that is waiting is passed over and costs nothing.

## A search looks at this many tiles between two looks at the clock.
const NODES_PER_CHECK := 16

## What one tick may do: how many searches it works on, and for how many microseconds. Npcs
## changes them with its rules.
var searches_per_frame: int
var usec_per_frame: int
## Gives the time in microseconds; the tests of the limits give their own.
var _clock: Callable
var _near_queue: Array[PathSearch] = []
var _far_queue: Array[PathSearch] = []


func _init(searches: int, usec: int, clock := Callable(Time, "get_ticks_usec")) -> void:
	searches_per_frame = searches
	usec_per_frame = usec
	_clock = clock


func queue(search: PathSearch, is_far := false) -> void:
	(_far_queue if is_far else _near_queue).append(search)


## Takes a search out of the queue, whether it is done or not: it is never looked at again.
func drop(search: PathSearch) -> void:
	_near_queue.erase(search)
	_far_queue.erase(search)


## How many searches are waiting (a finished search is gone at once).
func waiting() -> int:
	return _near_queue.size() + _far_queue.size()


## Works the queues for one frame.
func tick() -> void:
	var started: int = _clock.call()
	var far_worked := _work(_far_queue, 1, started + usec_per_frame / 2)
	# One near search always gets its turn, however small the limit.
	_work(_near_queue, maxi(searches_per_frame - far_worked, 1), started + usec_per_frame)


## Works the searches of `queue`, the oldest first, until `searches` of them have been given time
## or the clock shows `deadline`. Returns how many it gave time to. A search that waits for a tile
## is passed over, and stays in the queue.
func _work(queue: Array[PathSearch], searches: int, deadline: int) -> int:
	var searches_worked := 0
	var index := 0
	while searches_worked < searches and index < queue.size():
		var search := queue[index]
		var looked_at_before := search.nodes_looked_at
		while not search.is_over():
			if _clock.call() >= deadline:
				return searches_worked
			search.step(NODES_PER_CHECK)
			if search.state == PathSearch.State.WAITING:
				break
		if search.nodes_looked_at > looked_at_before:
			searches_worked += 1
		if search.is_over():
			queue.remove_at(index)
		else:
			index += 1
	return searches_worked
