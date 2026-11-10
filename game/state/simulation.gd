class_name Simulation
extends RefCounted
## The one owner of the game's time: whatever moves the clock (the frames of play, a night's
## sleep, passing out, the console's `skip`) calls `advance`, and everything that changes with
## time follows from it. The clock is cut at every full hour, so a span of any length passes as
## the same hours played one after the other.

## Time passed without being played, and the systems have made up for it (see `skip`): what shows
## the world follows.
signal skipped(minutes: int)

## A skip plays this many minutes through, 2 seconds of play, before it makes up for the rest.
const WALKED_MINUTES := 3

## How long a part of `skip_over_frames` works in one frame, in microseconds: a frame of this and
## the rest of the game stays under 33 ms.
const DEFAULT_FRAME_BUDGET_USEC := 8000

## The budget in use. Only the tests change it, to 0, to have every step in a frame of its own.
static var frame_budget_usec := DEFAULT_FRAME_BUDGET_USEC

var clock: GameClock
## In the order they run after each span: a system may rely on those before it.
var _systems: Array[SimulationSystem] = []


func _init(game_clock: GameClock) -> void:
	clock = game_clock


func add_system(system: SimulationSystem) -> void:
	_systems.append(system)


## Lets `minutes` game minutes pass without the player living through them (sleep, passing out,
## the console's `skip`): what changes with time follows as in `advance`. The first WALKED_MINUTES
## are played through minute by minute for what the frames of play move (see SimulationSystem
## `walked_minute`) and the rest is made up for in one go (`skipped`).
func skip(minutes: int) -> void:
	var rest := _walk_through(minutes)
	if rest > 0:
		advance(rest)
		for system in _systems:
			system.skipped(rest, clock)
	skipped.emit(minutes)


## The same as `skip`, spread over frames so that none is long: `await` it, and keep whatever moves
## the world still meanwhile, as the world ends the same only then. `next_frame` is a Callable
## that gives the signal of the next frame.
func skip_over_frames(minutes: int, next_frame: Callable) -> void:
	var rest := _walk_through(minutes)
	await next_frame.call()
	if rest > 0:
		advance(rest)
		for system in _systems:
			await system.skipped_over_frames(rest, clock, next_frame)
	# What shows the world follows (`skipped`) in a frame of its own, and what the caller does
	# after it in the next.
	await next_frame.call()
	skipped.emit(minutes)
	await next_frame.call()


## Plays the first WALKED_MINUTES of a skip through; returns the minutes left to make up for.
func _walk_through(minutes: int) -> int:
	var walked := mini(minutes, WALKED_MINUTES)
	for _minute in walked:
		advance(1)
		for system in _systems:
			system.walked_minute(clock)
	return minutes - walked


## Lets `minutes` game minutes of play pass, in whole-hour steps.
func advance(minutes: int) -> void:
	assert(minutes >= 0, "Time only moves forward")
	var left := minutes
	while left > 0:
		var to_full_hour := (
			GameClock.MINUTES_PER_HOUR - clock.minute_of_day % GameClock.MINUTES_PER_HOUR
		)
		var span := mini(left, to_full_hour)
		clock.advance(span)
		left -= span
		for system in _systems:
			system.advance(span, clock)
