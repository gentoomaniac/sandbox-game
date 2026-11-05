class_name Bird
extends Animal
## A sparrow on open ground: pecks, hops and looks around; takes off when the player comes
## near and flies off the screen.

const IDLE := &"idle"
const PECK := &"peck"
const HOP := &"hop"
const FLY := &"fly"

const HOP_LENGTH := Vector2(5.0, 9.0)
const HOP_SECONDS := 0.25
const HOP_HEIGHT := 3.0
const FLY_SPEED := 70.0
## How fast it climbs and how high above the ground it flies.
const CLIMB_SPEED := 30.0
const FLIGHT_HEIGHT := 14.0
## It is gone once it is this far outside the view.
const LEAVE_MARGIN := 12.0

var _state_seconds := 1.0
var _flight_direction := Vector2.RIGHT


func _init() -> void:
	super(WildlifeRules.BIRD)
	shadow_half_width = 2


func _ready() -> void:
	super()
	_start_idle()


func dismiss() -> void:
	if _state != FLY:
		_take_off(_away_from_view_centre())


func _update(delta: float) -> void:
	if _state != FLY and _reaction() == WildlifeRules.Reaction.FLEE:
		_take_off(_away_from_player())
	match _state:
		IDLE, PECK:
			if _state_time >= _state_seconds:
				_choose_next()
		HOP:
			if _advance_hop(delta):
				_start_idle()
		FLY:
			_fly(delta)


func _choose_next() -> void:
	var roll := wildlife.rng.randf()
	if roll < 0.5:
		_enter(PECK)
		_state_seconds = wildlife.rng.randf_range(0.8, 2.0)
		_play(PECK, 4.0)
	elif roll < 0.75:
		_start_idle()
	elif not _try_hop(
		Vector2.from_angle(wildlife.rng.randf() * TAU),
		wildlife.rng.randf_range(HOP_LENGTH.x, HOP_LENGTH.y),
		HOP_SECONDS,
		HOP_HEIGHT
	):
		_start_idle()
	else:
		_enter(HOP)
		_play(HOP, 2.0 / HOP_SECONDS)


func _start_idle() -> void:
	_enter(IDLE)
	_state_seconds = wildlife.rng.randf_range(0.6, 2.0)
	_play(IDLE, 1.5)


func _take_off(away: Vector2) -> void:
	_enter(FLY)
	_is_hopping = false
	_arc = 0.0
	_flight_direction = (away + Vector2(0.0, -0.4)).normalized()
	_face(away.x)
	_play(FLY, 14.0)
	z_index = 1
	shadow_half_width = 0
	queue_redraw()


func _fly(delta: float) -> void:
	position += _flight_direction * FLY_SPEED * delta
	_lift = minf(_lift + CLIMB_SPEED * delta, FLIGHT_HEIGHT)
	if _is_out_of_view(LEAVE_MARGIN):
		is_done = true
