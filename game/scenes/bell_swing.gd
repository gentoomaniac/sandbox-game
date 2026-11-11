class_name BellSwing
extends RefCounted
## How a bell swings in its frame: a pendulum that dies away. `ring` kicks it, `step` advances it
## and `frame` says which picture of the swing strip to show (the middle one hangs straight).
## Ringing while it still swings keeps the bell where it is and sends it on at full strength
## from there, so the bell never jumps.

const FRAMES := 11
@warning_ignore("integer_division") const MIDDLE := FRAMES / 2
## One swing there and back, and how long a swing takes to fade to a twentieth of its width.
const PERIOD_SECONDS := 1.1
const FADE_SECONDS := 4.0
const _OMEGA := TAU / PERIOD_SECONDS
const _DAMPING := 2.0 * log(20.0) / FADE_SECONDS
## A kick is a little stronger than a swing needs, as the first half swing already fades.
const _KICK := 1.35

## -1 (leaning fully one way) to 1 (the other); 0 hangs straight.
var angle := 0.0
var _velocity := 0.0


func ring() -> void:
	# The speed that, from this angle, makes a swing as wide as the widest.
	var direction := -1.0 if _velocity < 0.0 else 1.0
	_velocity = direction * _OMEGA * _KICK * sqrt(1.0 - angle * angle)


func step(delta: float) -> void:
	_velocity += (-_OMEGA * _OMEGA * angle - _DAMPING * _velocity) * delta
	angle = clampf(angle + _velocity * delta, -1.0, 1.0)
	if not is_swinging():
		angle = 0.0
		_velocity = 0.0


## Whether it still moves visibly: a swing is over once it no longer reaches the next picture.
func is_swinging() -> bool:
	var amplitude := sqrt(angle * angle + pow(_velocity / _OMEGA, 2))
	return amplitude * MIDDLE >= 0.5


func frame() -> int:
	return MIDDLE + roundi(angle * MIDDLE)
