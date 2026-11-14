class_name PathSearch
extends RefCounted
## One search for a way over tiles from `start` to `goal` (A*, four directions, tile centre to
## tile centre), for a walker who can step only on the tiles `is_free` accepts. It asks the tiles
## as it goes and keeps only those it has seen, so nothing of the world is copied, and it goes on
## where it left off: `step` looks at some more tiles and says how far it is, so that a long
## search can be spread over frames (see Pathfinder). The start is not asked: someone who stands
## where they should not (in a doorway, on mud) must be able to leave it.
##
## A tile may be not known yet (`is_known`: a far tile whose mask is not made, see TravelView). The
## search then waits, and goes on when `step` is called again.

## RUNNING: not done. WAITING: not done, and a tile it needs is not known yet; `step` looks again.
## FOUND: `path` leads to the goal. LEG: the search looked at `max_nodes` tiles without finding the
## goal, and `path` leads to the tile it saw nearest to it; the walker goes there and searches
## again from it. FAILED: there is no way, or no leg that gets nearer.
enum State { RUNNING, WAITING, FOUND, LEG, FAILED }

const STEPS: Array[Vector2i] = [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP]
## What a tile's cost so far is cut by in the queue: among ways that look equally good, the one that
## has come further is looked at first.
const TIE_BREAK := 0.001
## The node number of a tile that is not free, and of one not looked at yet.
const BLOCKED := -1
const UNSEEN := -2

var state := State.RUNNING
## The tiles to walk after the start, in order (empty when the start is the goal), once the state
## is FOUND or LEG.
var path: Array[Vector2i] = []
## How many tiles it has looked at (taken from the queue and its neighbours asked).
var nodes_looked_at := 0

var _goal: Vector2i
var _is_free: Callable
var _is_known: Callable
var _is_goal_checked := false
var _cost_of: Callable
var _max_nodes: int
var _heuristic_weight: float

# What it knows of each tile it has looked at: its node number (the start is node 0), or
# BLOCKED. The rest are by node number.
var _node_of_tile: Dictionary[Vector2i, int] = {}
var _tiles: Array[Vector2i] = []
var _cost_to_reach := PackedFloat64Array()
var _step_cost := PackedFloat64Array()
var _came_from := PackedInt32Array()
var _is_closed := PackedByteArray()
# The nodes to look at, a binary heap: the least cost to reach it and to go on, then the one that
# has come furthest. A node may be in it twice, if a better way to it was found.
var _heap := PackedInt32Array()
var _heap_priority := PackedFloat64Array()
var _nearest_node := 0
var _nearest_distance: int


## `is_free(tile) -> bool` says whether the walker may stand on a tile; `cost_of(tile) -> float`
## what it costs to step onto it (above 0, 1.0 on ordinary ground). The guess at what is left is the
## distance in tiles times `heuristic_weight`: 1.0 is a little more than lanes of 0.6 allow, so a
## way up to 1.67 times longer than the best may be taken, and a plain field is not searched all
## over (0.6 would be exact). After `max_nodes` tiles it settles for a leg. A goal that is not free
## is no way at once. `is_known(tile) -> bool` says whether `is_free` and `cost_of` can answer for a
## tile yet; by default they always can.
func _init(
	start: Vector2i,
	goal: Vector2i,
	is_free: Callable,
	cost_of: Callable,
	max_nodes: int,
	heuristic_weight := 1.0,
	is_known := Callable()
) -> void:
	_goal = goal
	_is_free = is_free
	_is_known = is_known
	_cost_of = cost_of
	_max_nodes = max_nodes
	_heuristic_weight = heuristic_weight
	_nearest_distance = _distance_to_goal(start)
	_add_node(start, 0.0, 0.0, -1)
	_check_goal()


## Looks at up to `node_count` more tiles; returns the state.
func step(node_count: int) -> State:
	if state == State.WAITING:
		state = State.RUNNING
	_check_goal()
	var looked_at_now := 0
	while state == State.RUNNING and looked_at_now < node_count:
		if _heap.is_empty():
			state = State.FAILED
			break
		var node := _pop()
		if _is_closed[node] == 1:
			continue
		var tile := _tiles[node]
		if tile != _goal and not _are_neighbours_known(tile):
			# Nothing of it is done yet, so it is looked at from the start when it is known.
			_push(node)
			state = State.WAITING
			break
		_is_closed[node] = 1
		looked_at_now += 1
		nodes_looked_at += 1
		if tile == _goal:
			path = _path_to(node)
			state = State.FOUND
			break
		var distance := _distance_to_goal(tile)
		if distance < _nearest_distance:
			_nearest_distance = distance
			_nearest_node = node
		for direction in STEPS:
			_reach(tile + direction, node)
		if nodes_looked_at >= _max_nodes and state == State.RUNNING:
			_settle_for_leg()
	return state


## Whether the search is over: it has a way, a leg or none.
func is_over() -> bool:
	return state != State.RUNNING and state != State.WAITING


## A goal that is not free is no way: said once it is known.
func _check_goal() -> void:
	if _is_goal_checked or state != State.RUNNING:
		return
	if _is_known.is_valid() and not _is_known.call(_goal):
		state = State.WAITING
		return
	_is_goal_checked = true
	if _tiles[0] != _goal and not _is_free.call(_goal):
		state = State.FAILED


func _are_neighbours_known(tile: Vector2i) -> bool:
	if not _is_known.is_valid():
		return true
	# All four are asked, not only the first that is not known: whoever makes them known may do so
	# in parallel.
	var are_known := true
	for direction in STEPS:
		var neighbour := tile + direction
		if not _node_of_tile.has(neighbour) and not _is_known.call(neighbour):
			are_known = false
	return are_known


## Finds the tile `neighbour` from `node`, if it is free and the way is better than any before.
func _reach(neighbour: Vector2i, node: int) -> void:
	var known: int = _node_of_tile.get(neighbour, UNSEEN)
	if known == BLOCKED:
		return
	if known == UNSEEN:
		# The goal was asked in `_init`, and a search with a goal that is not free never runs.
		if neighbour != _goal and not _is_free.call(neighbour):
			_node_of_tile[neighbour] = BLOCKED
			return
		var step_cost: float = _cost_of.call(neighbour)
		_add_node(neighbour, _cost_to_reach[node] + step_cost, step_cost, node)
	elif (
		_is_closed[known] == 0 and _cost_to_reach[node] + _step_cost[known] < _cost_to_reach[known]
	):
		_cost_to_reach[known] = _cost_to_reach[node] + _step_cost[known]
		_came_from[known] = node
		_push(known)


func _add_node(tile: Vector2i, cost_so_far: float, step_cost: float, came_from: int) -> void:
	var node := _tiles.size()
	_node_of_tile[tile] = node
	_tiles.append(tile)
	_cost_to_reach.append(cost_so_far)
	_step_cost.append(step_cost)
	_came_from.append(came_from)
	_is_closed.append(0)
	_push(node)


## The leg that leads to the tile nearest the goal, or no way if that is the start: a leg that
## gets no nearer would only be searched again, to the same end.
func _settle_for_leg() -> void:
	if _nearest_node == 0:
		state = State.FAILED
		return
	path = _path_to(_nearest_node)
	state = State.LEG


func _path_to(node: int) -> Array[Vector2i]:
	var way: Array[Vector2i] = []
	while _came_from[node] != -1:
		way.append(_tiles[node])
		node = _came_from[node]
	way.reverse()
	return way


func _distance_to_goal(tile: Vector2i) -> int:
	var apart := (_goal - tile).abs()
	return apart.x + apart.y


# --- The heap ---


func _push(node: int) -> void:
	# Lower is better: the cost so far plus the guess to the goal, and among equals the node with
	# the larger cost so far, which is the one nearer the goal (else a plain field is searched
	# all over).
	var priority := (
		_cost_to_reach[node] * (1.0 - TIE_BREAK)
		+ _distance_to_goal(_tiles[node]) * _heuristic_weight
	)
	# The node falls into place from the end: those above it that are worse move down.
	_heap.append(node)
	_heap_priority.append(priority)
	var hole := _heap.size() - 1
	while hole > 0:
		var parent := (hole - 1) >> 1
		if _heap_priority[parent] <= priority:
			break
		_heap[hole] = _heap[parent]
		_heap_priority[hole] = _heap_priority[parent]
		hole = parent
	_heap[hole] = node
	_heap_priority[hole] = priority


func _pop() -> int:
	var top := _heap[0]
	var last := _heap.size() - 1
	var node := _heap[last]
	var priority := _heap_priority[last]
	_heap.resize(last)
	_heap_priority.resize(last)
	if last == 0:
		return top
	# The last node is let fall from the top: the better of the two below it moves up.
	var hole := 0
	while true:
		var child := hole * 2 + 1
		if child >= last:
			break
		if child + 1 < last and _heap_priority[child + 1] < _heap_priority[child]:
			child += 1
		if priority <= _heap_priority[child]:
			break
		_heap[hole] = _heap[child]
		_heap_priority[hole] = _heap_priority[child]
		hole = child
	_heap[hole] = node
	_heap_priority[hole] = priority
	return top
