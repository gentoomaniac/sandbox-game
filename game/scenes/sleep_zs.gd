class_name SleepZs
extends Node2D
## "z"s rising from a sleeping figure while `is_sleeping`: one every Z_INTERVAL seconds, each
## drifting up and a little sideways as it fades. Its position is where they start; a small
## animal's "z"s rise less far than the player's.

const Z_PATH := "res://assets/effects/sleep_z.png"
const Z_INTERVAL := 0.6
const RISE_SECONDS := 1.6
## How far a "z" drifts sideways, in art pixels.
const DRIFT := 10.0

var is_sleeping := false:
	set(value):
		is_sleeping = value
		if not is_sleeping:
			_until_next = 0.0

## How far a "z" rises, in art pixels.
var rise := 28.0

var _until_next := 0.0
## Every other "z" drifts the other way.
var _drift_sign := 1.0


func _process(delta: float) -> void:
	if not is_sleeping:
		return
	_until_next -= delta
	if _until_next > 0.0:
		return
	_until_next = Z_INTERVAL
	var z := Sprite2D.new()
	z.texture = load(ArtSet.path(Z_PATH))
	add_child(z)
	var drift := create_tween().set_parallel()
	drift.tween_property(z, "position", Vector2(DRIFT * _drift_sign, -rise), RISE_SECONDS)
	drift.tween_property(z, "modulate:a", 0.0, RISE_SECONDS).set_ease(Tween.EASE_IN)
	drift.chain().tween_callback(z.queue_free)
	_drift_sign = -_drift_sign


## Stops, and takes the "z"s that are still rising away at once.
func clear() -> void:
	is_sleeping = false
	for z in get_children():
		z.queue_free()
