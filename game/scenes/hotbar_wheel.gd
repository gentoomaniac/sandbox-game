class_name HotbarWheel
extends RefCounted
## What the mouse wheel does to the hotbar (Main keeps the progress): a notch is a slot each way,
## and a touchpad's small turns add up to whole slots.


## Whether `event` turns the mouse wheel without Ctrl (which zooms, see CameraController).
static func is_hotbar_wheel(event: InputEvent) -> bool:
	return (
		event is InputEventMouseButton
		and event.pressed
		and not event.ctrl_pressed
		and event.button_index in [MOUSE_BUTTON_WHEEL_DOWN, MOUSE_BUTTON_WHEEL_UP]
	)


## How far a wheel event turns, in hotbar slots: down towards the next slot, up towards the one
## before. A notch is one; a touchpad sends many small turns (`factor` below 1), which add up in
## the progress Main keeps.
static func turn_of(event: InputEventMouseButton) -> float:
	var turn := event.factor if event.factor > 0.0 else 1.0
	return turn if event.button_index == MOUSE_BUTTON_WHEEL_DOWN else -turn


## The wheel's progress after a `turn`. What is left of turning the other way is dropped
## first, so a notch after some touchpad turning the other way still moves a whole slot.
static func turned(progress: float, turn: float) -> float:
	if progress * turn < 0.0:
		progress = 0.0
	return progress + turn


## The whole slots in `progress`, towards zero; ten turns of 0.1 make one despite rounding.
static func whole_slots(progress: float) -> int:
	return int(snappedf(progress, 0.0001))
