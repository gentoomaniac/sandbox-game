class_name Mouse
extends Animal
## A mouse by the fields, the Knicks, the walls and the houses: it crouches and sniffs, and
## scurries a short way now and then; when the player comes near (or it is sent away, or a cat
## pounces on it and misses) it dashes off and is gone into the grass. It takes no notice of a cat
## creeping up on it.
##
## It tells the cats of Livestock where it is (`prey`) and shows what their hunt makes of it: it
## dashes off when a cat pounces and misses, and is gone when it is caught.

const SIT := &"sit"
const SCURRY := &"scurry"
const FLEE := &"flee"

const SCURRY_SPEED := 60.0
const FLEE_SPEED := 140.0
## A dash lasts this long before the mouse is gone into cover, sooner if its way is blocked.
const FLEE_SECONDS := 0.6

## What the cats hunt: it is kept up to date from `_update`, and ends with the mouse.
var prey := Prey.new()
var _state_seconds := 1.0
var _direction := Vector2.RIGHT


func _init() -> void:
	super(WildlifeRules.MOUSE)
	shadow_half_width = 4


func _ready() -> void:
	super()
	_sit()


## Freed with its view (a clear, or far from the view): nothing calls `sync_prey` any more, so
## the cats are told here that it is gone.
func _exit_tree() -> void:
	prey.is_about = false


## Tells the cats where it is and whether it is still about. Run after the mouse has moved, so
## that a cat's landing is judged by where it is, and by whether it is done (see `_update`).
func sync_prey() -> void:
	prey.position = position / WildlifeRules.TILE_SIZE
	if is_done:
		prey.is_about = false


func dismiss() -> void:
	if _state != FLEE:
		_dash(_away_from_view_centre())


## Dashes off into cover away from `point`, as from a cat that pounces on it and misses.
func flee_from(point: Vector2) -> void:
	if _state != FLEE:
		var away := position - point
		_dash(away.normalized() if away.length() >= 1.0 else _away_from_view_centre())


func _update(delta: float) -> void:
	match prey.fate:
		Prey.Fate.CAUGHT:
			is_done = true
		Prey.Fate.SCARED:
			flee_from(prey.scare_point * WildlifeRules.TILE_SIZE)
	prey.fate = Prey.Fate.NONE
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
	sync_prey()


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
