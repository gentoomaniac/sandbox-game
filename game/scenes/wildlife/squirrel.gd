class_name Squirrel
extends Animal
## A squirrel in the woods: sits up and flicks its tail, darts from tree to tree; flees to the
## nearest tree and vanishes behind it (or runs off if there is none).

const SIT := &"sit"
const DART := &"dart"
const FLEE := &"flee"
const HIDING := &"hiding"

const DART_SPEED := 120.0
const FLEE_SPEED := 160.0
## How far it looks for a tree to dart to, and to flee to, in tiles.
const DART_REACH_TILES := 6
const FLEE_REACH_TILES := 8
## It reaches a spot when this near, in pixels.
const ARRIVED := 4.0
## It hides behind a tree by standing this high up on the trunk's tile, which is in front of
## it in the draw order.
const BEHIND_TRUNK := 6.0
const HIDE_SECONDS := 0.2
## Where a squirrel with no tree to flee to runs: far, until it is out of the view.
const RUN_OFF_DISTANCE := 1200.0

var _state_seconds := 1.0
var _target := Vector2.ZERO
var _is_dismissed := false


func _init() -> void:
	super(WildlifeRules.SQUIRREL)
	shadow_half_width = 6


func _ready() -> void:
	super()
	_sit()


func dismiss() -> void:
	_is_dismissed = true
	if _state != FLEE:
		_start_fleeing()


func _update(delta: float) -> void:
	if _state != FLEE and _state != HIDING and _reaction() == WildlifeRules.Reaction.FLEE:
		_start_fleeing()
	match _state:
		SIT:
			if _state_time >= _state_seconds:
				_start_dart()
		DART:
			if not _run_to_target(DART_SPEED, delta, true):
				_sit()
		FLEE:
			if not _run_to_target(FLEE_SPEED, delta, false):
				_enter(HIDING)
		HIDING:
			if _state_time >= HIDE_SECONDS:
				is_done = true


func _sit() -> void:
	_enter(SIT)
	_state_seconds = wildlife.rng.randf_range(1.5, 4.0)
	_play(SIT, 2.0)


## Darts to the foot of a tree other than the one it is at, if there is one.
func _start_dart() -> void:
	var trees := wildlife.trees_near(position, DART_REACH_TILES)
	var farther := trees.filter(
		func(tree: Vector2i) -> bool: return _tree_foot(tree).distance_to(position) > 2.0 * ARRIVED
	)
	if farther.is_empty():
		_sit()
		return
	_target = _tree_foot(farther[wildlife.rng.randi() % farther.size()])
	_enter(DART)
	_play(DART, 10.0)


func _start_fleeing() -> void:
	var trees: Array[Vector2i] = []
	if not _is_dismissed:
		trees = wildlife.trees_near(position, FLEE_REACH_TILES)
	if trees.is_empty():
		var away := _away_from_view_centre() if _is_dismissed else _away_from_threat()
		_target = position + away * RUN_OFF_DISTANCE
	else:
		_target = _tree_behind(trees[0])
	_enter(FLEE)
	_play(DART, 14.0)


## Runs to the target in a straight line. A darting squirrel stops at ground it can't stand
## on; a fleeing one runs over anything. Returns false once it has arrived or must stop.
func _run_to_target(speed: float, delta: float, is_careful: bool) -> bool:
	var to_target := _target - position
	if to_target.length() <= ARRIVED:
		return false
	var direction := to_target.normalized()
	if is_careful:
		return _walk(direction, speed, delta)
	position += direction * speed * delta
	_face(direction.x)
	if _is_out_of_view():
		is_done = true
	return true


## The ground beside a tree to dart to: the tile below it.
func _tree_foot(tree: Vector2i) -> Vector2:
	return (Vector2(tree) + Vector2(0.5, 1.5)) * WildlifeRules.TILE_SIZE


## A spot hidden by a tree: on its trunk's tile, a little above the middle.
func _tree_behind(tree: Vector2i) -> Vector2:
	return TerrainTileset.tile_centre(tree) - Vector2(0, BEHIND_TRUNK)
