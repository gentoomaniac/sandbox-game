class_name CameraRig
extends RefCounted
## What the camera is doing: where it looks (in art pixels, fractional) and how far it is
## zoomed. It follows a target, or plays a sequence of moves, zooms and waits, e.g. for a
## cutscene. Plain state moved by `advance`, so it can be tested; CameraController applies it.

## Emitted when the last step of a sequence is done.
signal sequence_finished

## How fast the zoom catches up with the mouse wheel (1/s of the remaining distance, roughly).
const WHEEL_ZOOM_SMOOTHING := 14.0

var position := Vector2.ZERO
var zoom := 1.0

var _zoom_goal := 1.0
var _follow := Callable()
var _steps: Array[Step] = []
var _step_elapsed := 0.0
var _step_from_position := Vector2.ZERO
var _step_from_zoom := 1.0
var _is_step_started := false


## One part of a sequence. Moves and zooms ease in and out.
class Step:
	enum Kind { MOVE, ZOOM, WAIT }
	var kind: Kind
	var value: Variant
	var duration: float

	static func move(to: Vector2, seconds: float) -> Step:
		return _make(Kind.MOVE, to, seconds)

	static func zoom_to(to: float, seconds: float) -> Step:
		return _make(Kind.ZOOM, to, seconds)

	static func wait(seconds: float) -> Step:
		return _make(Kind.WAIT, null, seconds)

	static func _make(step_kind: Kind, step_value: Variant, seconds: float) -> Step:
		var step := Step.new()
		step.kind = step_kind
		step.value = step_value
		step.duration = seconds
		return step


## Stays on the position `target` returns (a Callable returning a Vector2), from now on.
## Jumps there at once.
func follow(target: Callable) -> void:
	_follow = target
	position = target.call()


func move_to(to: Vector2, duration: float) -> void:
	play_sequence([Step.move(to, duration)])


func zoom_to(value: float, duration: float) -> void:
	play_sequence([Step.zoom_to(value, duration)])


## Runs the steps one after the other, replacing a running sequence. A move stops following.
func play_sequence(steps: Array[Step]) -> void:
	_steps = steps.duplicate()
	_step_elapsed = 0.0
	_is_step_started = false


func is_playing() -> bool:
	return not _steps.is_empty()


## Zooms at once to `value`, clamped to the allowed range.
func set_zoom_clamped(value: float) -> void:
	zoom = ViewMath.clamp_zoom(value)
	_zoom_goal = zoom


## The part of the world a window of `window_size` pixels shows, in art pixels of the world.
func view_rect(window_size: Vector2) -> Rect2:
	var size := ViewMath.visible_size(window_size, zoom)
	return Rect2(position - size / 2.0, size)


## The mouse wheel: the zoom glides to the new value over the next frames.
func zoom_by_wheel(notches: float) -> void:
	_zoom_goal = ViewMath.zoom_after_wheel(_zoom_goal, notches)


func advance(delta: float) -> void:
	var remaining := delta
	while is_playing():
		var step := _steps[0]
		if not _is_step_started:
			_begin(step)
		var used := minf(remaining, step.duration - _step_elapsed)
		_step_elapsed += used
		remaining -= used
		_apply(step)
		if _step_elapsed < step.duration:
			return
		_steps.pop_front()
		_step_elapsed = 0.0
		_is_step_started = false
		if _steps.is_empty():
			sequence_finished.emit()
	if _follow.is_valid():
		position = _follow.call()
	zoom *= pow(_zoom_goal / zoom, 1.0 - exp(-WHEEL_ZOOM_SMOOTHING * delta))


func _begin(step: Step) -> void:
	_is_step_started = true
	_step_from_position = position
	_step_from_zoom = zoom
	if step.kind == Step.Kind.MOVE:
		_follow = Callable()


func _apply(step: Step) -> void:
	var progress := 1.0 if step.duration <= 0.0 else _step_elapsed / step.duration
	var eased := smoothstep(0.0, 1.0, progress)
	match step.kind:
		Step.Kind.MOVE:
			position = _step_from_position.lerp(step.value, eased)
		Step.Kind.ZOOM:
			# Geometric, so the picture grows at a steady rate.
			var to := ViewMath.clamp_zoom(step.value)
			zoom = _step_from_zoom * pow(to / _step_from_zoom, eased)
			_zoom_goal = zoom
