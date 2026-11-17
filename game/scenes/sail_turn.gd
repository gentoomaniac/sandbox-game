class_name SailTurn
extends RefCounted
## How the sails of a windmill turn: a speed (0 stands still, 1 is the speed a recipe's hours are
## for, see Weather `mill_speed`) makes frames of the strip of turning sails (windmill_sails.png:
## FRAMES pictures, each the sails turned a little further, looping). `step` advances it and
## `frame` says which picture to show.

const FRAMES := 8
## About 6 a second in a light wind and 12 in a strong one, as the art is drawn for.
const FRAMES_PER_SECOND := 6.0

## 0 (still) and up.
var speed := 0.0
var _phase := 0.0


func step(delta: float) -> void:
	_phase = fposmod(_phase + speed * FRAMES_PER_SECOND * delta, FRAMES)


func frame() -> int:
	return int(_phase)


func is_still() -> bool:
	return speed == 0.0
