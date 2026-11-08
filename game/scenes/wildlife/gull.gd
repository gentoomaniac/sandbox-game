class_name Gull
extends Animal
## A herring gull of the coast. On the mud and the salt marsh it walks, pecks and stands, now and
## then with its head thrown up to call; on the sea, and on the mud while the tide is in (see
## WildlifeView.is_water), it swims, bobbing and drifting. It takes off when the player comes near
## (or it is sent away) and flies off with a few beats of its long wings between long glides.

const STAND := &"stand"
const WALK := &"walk"
const PECK := &"peck"
const SWIM := &"swim"
const FLY := &"fly"

const WALK_SPEED := 16.0
const DRIFT_SPEED := 4.0
const FLY_SPEED := 72.0
const CLIMB_SPEED := 28.0
const FLIGHT_HEIGHT := 64.0
## A wingbeat is the three frames of `fly` and back; between a few beats it glides.
const WINGBEAT_FRAMES_PER_SECOND := 6.0
const FLAP_SECONDS := 1.0
const GLIDE_SECONDS := 2.0
const GLIDE_FRAME := 1
## Half the width of its contact shadow on the ground; on the water it has none.
const SHADOW_HALF_WIDTH := 4
## It is gone once it is this far outside the view: far enough for its height and its wings.
const LEAVE_MARGIN := 128.0

var _state_seconds := 1.0
## Where it walks, drifts or flies.
var _direction := Vector2.RIGHT
var _shadow: GroundShadows


func _init() -> void:
	super(WildlifeRules.GULL)
	shadow_half_width = SHADOW_HALF_WIDTH


func _ready() -> void:
	super()
	_shadow = GroundShadows.new(1, 3)
	_shadow.hide()
	wildlife.ground.add_child(_shadow)
	_choose_next()


func _exit_tree() -> void:
	_shadow.queue_free()


func dismiss() -> void:
	if _state != FLY:
		_take_off(_away_from_view_centre())


func _update(delta: float) -> void:
	if _state != FLY and _reaction() == WildlifeRules.Reaction.FLEE:
		_take_off(_away_from_player())
	elif _state in [STAND, WALK, PECK] and wildlife.is_water(position):
		# The tide came in under it.
		_swim()
	match _state:
		STAND, PECK:
			if _state_time >= _state_seconds:
				_choose_next()
		WALK:
			if _state_time >= _state_seconds or not _walk(_direction, WALK_SPEED, delta):
				_choose_next()
		SWIM:
			_drift(delta)
		FLY:
			_fly(delta)


## Swims on the water; on the ground it pecks, walks or stands.
func _choose_next() -> void:
	if wildlife.is_water(position):
		_swim()
		return
	_show_contact_shadow(true)
	var roll := wildlife.rng.randf()
	if roll < 0.4:
		_enter(PECK)
		_state_seconds = wildlife.rng.randf_range(1.0, 3.0)
		_play(PECK, 3.0)
	elif roll < 0.7:
		_enter(WALK)
		_state_seconds = wildlife.rng.randf_range(1.5, 4.0)
		_direction = Vector2.from_angle(wildlife.rng.randf() * TAU)
		_play(WALK, 4.0)
	else:
		_enter(STAND)
		_state_seconds = wildlife.rng.randf_range(1.5, 4.0)
		# Mostly the first frame, head level; it calls on the second.
		_play(STAND, 0.3)


func _swim() -> void:
	_enter(SWIM)
	_state_seconds = wildlife.rng.randf_range(3.0, 8.0)
	_direction = Vector2.from_angle(wildlife.rng.randf() * TAU)
	_face(_direction.x)
	_show_contact_shadow(false)
	_play(SWIM, 1.2)


## Drifts slowly on the water, turning at the shore; walks off once the water has gone from
## under it.
func _drift(delta: float) -> void:
	if not wildlife.is_water(position):
		_choose_next()
		return
	if _state_time >= _state_seconds:
		_swim()
		return
	var next := position + _direction * DRIFT_SPEED * delta
	if wildlife.is_water(next):
		position = next
	else:
		_direction = -_direction
		_face(_direction.x)


func _show_contact_shadow(is_shown: bool) -> void:
	shadow_half_width = SHADOW_HALF_WIDTH if is_shown else 0
	queue_redraw()


func _take_off(away: Vector2) -> void:
	_enter(FLY)
	_direction = (away + Vector2(0.0, -0.3)).normalized()
	_face(_direction.x)
	_play(FLY, WINGBEAT_FRAMES_PER_SECOND)
	_is_ping_pong = true
	z_index = 1
	_show_contact_shadow(false)
	_shadow.show()


func _fly(delta: float) -> void:
	position += _direction * FLY_SPEED * delta
	_lift = minf(_lift + CLIMB_SPEED * delta, FLIGHT_HEIGHT)
	if fmod(_state_time, FLAP_SECONDS + GLIDE_SECONDS) > FLAP_SECONDS:
		# Held on the frame with the wings level (the middle of the step).
		_action_time = (GLIDE_FRAME + 0.5) / WINGBEAT_FRAMES_PER_SECOND
	_shadow.shift = GroundShadows.SHIFT * _lift / FLIGHT_HEIGHT
	_shadow.set_point(0, position)
	if _is_out_of_view(LEAVE_MARGIN):
		is_done = true
