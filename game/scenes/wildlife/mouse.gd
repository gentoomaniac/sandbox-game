class_name Mouse
extends Animal
## A mouse by the fields, the Knicks, the walls and the houses: it crouches and sniffs, and
## scurries a short way now and then; when the player comes near (or it is sent away, or a cat
## pounces on it and misses) it dashes off and is gone into the grass. It takes no notice of a cat
## creeping up on it.

const SIT := &"sit"
const SCURRY := &"scurry"
const FLEE := &"flee"

const SCURRY_SPEED := 60.0
const FLEE_SPEED := 140.0
## A dash lasts this long before the mouse is gone into cover, sooner if its way is blocked.
const FLEE_SECONDS := 0.6

var _state_seconds := 1.0
var _direction := Vector2.RIGHT


func _init() -> void:
	super(WildlifeRules.MOUSE)
	shadow_half_width = 2


func _ready() -> void:
	super()
	_sit()


func dismiss() -> void:
	if _state != FLEE:
		_dash(_away_from_view_centre())


## Dashes off into cover away from `point`, as from a cat that pounces on it and misses.
func flee_from(point: Vector2) -> void:
	if _state != FLEE:
		var away := position - point
		_dash(away.normalized() if away.length() >= 1.0 else _away_from_view_centre())


func _update(delta: float) -> void:
	if _state != FLEE and _reaction() == WildlifeRules.Reaction.FLEE:
		_dash(_away_from_player())
	match _state:
		SIT:
			if _state_time >= _state_seconds:
				_scurry()
		SCURRY:
			if _state_time >= _state_seconds or not _walk(_direction, SCURRY_SPEED, delta):
				_sit()
		FLEE:
			if not _walk(_direction, FLEE_SPEED, delta) or _state_time >= FLEE_SECONDS:
				is_done = true


func _sit() -> void:
	_enter(SIT)
	_state_seconds = wildlife.rng.randf_range(1.0, 4.0)
	_play(SIT, 1.5)


func _scurry() -> void:
	_enter(SCURRY)
	_state_seconds = wildlife.rng.randf_range(0.2, 0.6)
	_direction = Vector2.from_angle(wildlife.rng.randf() * TAU)
	_play(SCURRY, 10.0)


func _dash(direction: Vector2) -> void:
	_enter(FLEE)
	_direction = direction
	_play(SCURRY, 14.0)
