class_name ItemHop
extends RefCounted
## The hop of a pile of items from where it came off (the middle of its source tile) to where it
## lies: an arc, then a smaller bounce on landing. Pure logic, in world pixels and seconds; see
## GroundItemView for the drawing. It waits `delay` seconds first (to stagger several piles).

const SECONDS := 0.42
## How high the arc and the bounce lift the pile, in world pixels.
const HEIGHT := 14.0
const BOUNCE_HEIGHT := 4.0
## The last share of the hop that is the bounce.
const BOUNCE_SHARE := 0.25

var source: Vector2i
var delay: float
var elapsed := 0.0
## True until the first `advance`: the pile was dropped this frame.
var just_dropped := true
var _start: Vector2
var _landing: Vector2


## `landing` is in world pixels, exactly where the pile lies.
func _init(source_tile: Vector2i, landing_spot: Vector2, wait: float) -> void:
	source = source_tile
	_start = TerrainTileset.tile_centre(source_tile)
	_landing = landing_spot
	delay = wait


## Moves the hop on by `delta` seconds; from then on it is no longer `just_dropped`.
func advance(delta: float) -> void:
	elapsed += delta
	just_dropped = false


func landing() -> Vector2:
	return _landing


func is_waiting() -> bool:
	return elapsed < delay


func is_done() -> bool:
	return elapsed >= delay + SECONDS


## Where the pile is on the ground now, without the lift.
func ground_position() -> Vector2:
	return _start.lerp(_landing, _arc_progress())


## How far above the ground the pile is now.
func lift() -> float:
	var progress := _progress()
	var arc_share := 1.0 - BOUNCE_SHARE
	if progress < arc_share:
		return HEIGHT * _parabola(progress / arc_share)
	return BOUNCE_HEIGHT * _parabola((progress - arc_share) / BOUNCE_SHARE)


## 0 to 1 over the hop.
func _progress() -> float:
	return clampf((elapsed - delay) / SECONDS, 0.0, 1.0)


func _arc_progress() -> float:
	return minf(_progress() / (1.0 - BOUNCE_SHARE), 1.0)


## 0 at both ends of 0 to 1, 1 in the middle.
func _parabola(progress: float) -> float:
	return 4.0 * progress * (1.0 - progress)
