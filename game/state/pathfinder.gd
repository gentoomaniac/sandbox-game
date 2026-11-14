class_name Pathfinder
extends RefCounted
## The searches that are waiting for their turn (PathSearch), and how much of a frame they may
## take: each `tick` works on the oldest ones, at most `searches_per_frame` of them, and stops
## when `search_usec_per_frame` microseconds are spent, so many villagers on their way never make
## the game stutter. A search that is not done goes on in the next tick. Whoever queued a search
## reads its state; the Pathfinder only works it.

## A search looks at this many tiles between two looks at the clock.
const NODES_PER_CHECK := 16

var _searches_per_frame: int
var _usec_per_frame: int
## Gives the time in microseconds; the tests of the limits give their own.
var _clock: Callable
var _queue: Array[PathSearch] = []


func _init(
	searches_per_frame: int, usec_per_frame: int, clock := Callable(Time, "get_ticks_usec")
) -> void:
	_searches_per_frame = searches_per_frame
	_usec_per_frame = usec_per_frame
	_clock = clock


func queue(search: PathSearch) -> void:
	_queue.append(search)


## Takes a search out of the queue, whether it is done or not: it is never looked at again.
func drop(search: PathSearch) -> void:
	_queue.erase(search)


## How many searches are waiting (a finished search is gone at once).
func waiting() -> int:
	return _queue.size()


## Works the queue for one frame.
func tick() -> void:
	var started: int = _clock.call()
	var searches_worked := 0
	while searches_worked < _searches_per_frame and not _queue.is_empty():
		var search := _queue[0]
		searches_worked += 1
		while search.state == PathSearch.State.RUNNING:
			if _clock.call() - started >= _usec_per_frame:
				return
			search.step(NODES_PER_CHECK)
		_queue.pop_front()
