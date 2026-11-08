class_name Deer
extends Animal
## A deer at the edge of the forest: grazes, looks up and wanders a few steps; looks at the
## player who comes near and bounds away when they come nearer.

const GRAZE := &"graze"
const LOOK := &"look"
const WALK := &"walk"
const ALERT := &"alert"
const BOUND := &"bound"

const WALK_SPEED := 28.0
const BOUND_LENGTH := 60.0
const BOUND_SECONDS := 0.42
const BOUND_HEIGHT := 14.0
## An alert deer goes back to grazing once the player is this many tiles farther than the
## distance that alerted it.
const CALM_EXTRA_TILES := 1.5

var _state_seconds := 1.0
var _walk_direction := Vector2.RIGHT
var _is_dismissed := false


func _init() -> void:
	super(WildlifeRules.DEER)
	shadow_half_width = 8


func _ready() -> void:
	super()
	_graze()


func dismiss() -> void:
	_is_dismissed = true
	if _state != BOUND:
		_start_bounding()


func _update(delta: float) -> void:
	var reaction := _reaction()
	if _state != BOUND and reaction == WildlifeRules.Reaction.FLEE:
		_start_bounding()
	elif _state in [GRAZE, LOOK, WALK] and reaction == WildlifeRules.Reaction.ALERT:
		_enter(ALERT)
		_play(LOOK, 1.5)
		_face(wildlife.world_view.player_feet.x - position.x)
	match _state:
		GRAZE, LOOK:
			if _state_time >= _state_seconds:
				_choose_next()
		WALK:
			if _state_time >= _state_seconds or not _walk(_walk_direction, WALK_SPEED, delta):
				_look()
		ALERT:
			var alert_tiles: float = wildlife.rules.alert_tiles(kind)
			if _player_distance_tiles() > alert_tiles + CALM_EXTRA_TILES:
				_graze()
		BOUND:
			_bound_on(delta)


func _choose_next() -> void:
	var roll := wildlife.rng.randf()
	if _state == GRAZE and roll < 0.6:
		_look()
	elif _state == LOOK and roll < 0.4:
		_graze()
	else:
		_enter(WALK)
		_state_seconds = wildlife.rng.randf_range(1.5, 4.0)
		_walk_direction = Vector2.from_angle(wildlife.rng.randf() * TAU)
		_play(WALK, 5.0)


func _graze() -> void:
	_enter(GRAZE)
	_state_seconds = wildlife.rng.randf_range(4.0, 9.0)
	_play(GRAZE, 1.0)


func _look() -> void:
	_enter(LOOK)
	_state_seconds = wildlife.rng.randf_range(1.5, 3.0)
	_play(LOOK, 1.0)


func _start_bounding() -> void:
	_enter(BOUND)
	_is_hopping = false
	_bound()


## Bounds on: hop after hop away from the player, until out of the view.
func _bound_on(delta: float) -> void:
	if _is_hopping and not _advance_hop(delta):
		return
	if _is_out_of_view():
		is_done = true
	else:
		_bound()


func _bound() -> void:
	var away := _away_from_view_centre() if _is_dismissed else _away_from_player()
	if _try_hop_around(away, BOUND_LENGTH, BOUND_SECONDS, BOUND_HEIGHT, 0.5):
		_play(BOUND, 3.0 / BOUND_SECONDS)
	else:
		_look()
