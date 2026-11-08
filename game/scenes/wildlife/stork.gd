class_name Stork
extends Animal
## A white stork. On wet ground (kind STORK) it hunts: slow steps with the head down, a stab
## into the grass now and then, a look round; it walks up to a frog it sees near it, strikes and
## swallows it (the frog is gone). It flies off with slow wingbeats when the player comes near.
## On a roof (kind ROOF_STORK) it flies in, lands on the ridge and stands there, clattering its
## bill now and then, until it is sent away or the house is gone.
##
## A flying stork is drawn `_lift` pixels above the point of the ground below it, its node's
## position. On a roof that point is just in front of the house, so the stork sorts in front of
## the roof it stands on and behind whatever stands in front of the house.

const STAND := &"stand"
const WALK := &"walk"
const STRIKE := &"strike"
const CLATTER := &"clatter"
const FLY := &"fly"
## Walking up to a frog, and swallowing it.
const STALK := &"stalk"
const SWALLOW := &"swallow"
## Flying to a roof, and standing on it.
const ARRIVE := &"arrive"
const PERCH := &"perch"

const WALK_SPEED := 12.0
const STALK_SPEED := 18.0
const FLY_SPEED := 64.0
const CLIMB_SPEED := 28.0
## How high it flies over open ground, and above the roof it flies to or leaves.
const FLIGHT_HEIGHT := 80.0
const ROOF_CLEARANCE := 48.0
## A wingbeat is the three frames of `fly` and back; between a few beats it glides.
const WINGBEAT_FRAMES_PER_SECOND := 5.0
const FLAP_SECONDS := 2.4
const GLIDE_SECONDS := 1.6
const GLIDE_FRAME := 1
## The chances that a stork on the ground, and one on a roof, clatters when it picks what to do
## next: about once a minute and a half, and once a minute. The clatter is heard (see
## AmbienceSounds), so it is rare.
const GROUND_CLATTER_CHANCE := 0.04
const ROOF_CLATTER_CHANCE := 0.09
## It sees a frog this many tiles away, when it picks what to do next, and gives up on one it
## hasn't reached in STALK_SECONDS.
const SIGHT_TILES := 3.0
const STALK_SECONDS := 15.0
## The tip of its bill in a strike is this many pixels ahead of its feet, and takes a frog this
## near to it.
const BILL_REACH := 20.0
const CATCH_DISTANCE := 8.0
const STRIKE_SECONDS := 0.8
const SWALLOW_SECONDS := 1.6
## It is gone once it is this far outside the view: far enough for its height and its wings.
const LEAVE_MARGIN := 144.0

## The house whose roof it stands on or flies to, or null, and the column of the house's
## picture it stands on.
var roof: Building
var _roof_column := 0
var _state_seconds := 1.0
var _walk_direction := Vector2.RIGHT
var _flight_direction := Vector2.RIGHT
## Where an arriving stork lands: the point of the ground below the spot, and its height.
var _landing := Vector2.ZERO
var _landing_lift := 0.0
var _arrival_distance := 1.0
var _arrival_lift := 0.0
var _shadow: GroundShadows
## The frog it walks up to and strikes at, or null.
var _prey: Animal


func _init(stork_kind: StringName) -> void:
	super(stork_kind, WildlifeRules.STORK)
	shadow_half_width = 8


func _ready() -> void:
	super()
	_shadow = GroundShadows.new(1, 6)
	_shadow.hide()
	wildlife.ground.add_child(_shadow)
	if roof != null:
		_landing_lift = wildlife.roof_lift(roof, _roof_column)
		_arrival_lift = _landing_lift + ROOF_CLEARANCE
		_lift = _arrival_lift if _state == ARRIVE else _landing_lift
	if _state == ARRIVE:
		_start_flying((_landing - position).normalized())
	elif roof != null:
		_perch()
	else:
		_stand()


func _exit_tree() -> void:
	_shadow.queue_free()


## Puts it on a column of a house's picture at once: `ground` is the point in front of the
## house below it (see WildlifeView._send_stork_to_roof), and it stands as high above it as the
## roof is there. Called before it is added to the view, like `fly_to`.
func stand_on(house: Building, column: int, ground: Vector2) -> void:
	roof = house
	_roof_column = column
	position = ground


## Makes it fly in from where it is to a spot of a roof (see `stand_on`).
func fly_to(house: Building, column: int, ground: Vector2) -> void:
	roof = house
	_roof_column = column
	_landing = ground
	_arrival_distance = maxf(position.distance_to(ground), 1.0)
	_enter(ARRIVE)


func dismiss() -> void:
	if _state != FLY:
		_take_off(_away_from_view_centre())


func _update(delta: float) -> void:
	if _state not in [FLY, ARRIVE] and _reaction() == WildlifeRules.Reaction.FLEE:
		_take_off(_away_from_player())
	match _state:
		STAND, CLATTER:
			if _state_time >= _state_seconds:
				if roof == null:
					_choose_next()
				else:
					_choose_on_roof()
		WALK:
			if _state_time >= _state_seconds or not _walk(_walk_direction, WALK_SPEED, delta):
				_choose_next()
		STALK:
			_stalk(delta)
		STRIKE:
			if _state_time >= _state_seconds:
				_finish_strike()
		SWALLOW:
			if _state_time >= _state_seconds:
				_choose_next()
		PERCH:
			if _state_time >= _state_seconds:
				_choose_on_roof()
		ARRIVE:
			_arrive(delta)
		FLY:
			_fly(delta)


func _choose_next() -> void:
	_prey = wildlife.nearest_animal(
		WildlifeRules.FROG, position, SIGHT_TILES * WildlifeRules.TILE_SIZE
	)
	if _prey != null:
		_enter(STALK)
		_play(WALK, 6.0)
		return
	var roll := wildlife.rng.randf()
	if _state == WALK and roll < 0.35:
		_strike()
	elif roll < GROUND_CLATTER_CHANCE:
		_clatter()
	elif _state != WALK and roll < 0.75:
		_enter(WALK)
		_state_seconds = wildlife.rng.randf_range(2.0, 5.0)
		_walk_direction = Vector2.from_angle(wildlife.rng.randf() * TAU)
		_play(WALK, 4.0)
	else:
		_stand()


## Walks up to its frog until the frog is under the tip of its bill, and strikes; gives up if
## the frog is gone, out of reach or too long in coming.
func _stalk(delta: float) -> void:
	if not _has_prey() or _state_time >= STALK_SECONDS:
		_stand()
		return
	var side := 1.0 if position.x >= _prey.position.x else -1.0
	var spot := _prey.position + Vector2(side * BILL_REACH, 0.0)
	var to_go := spot - position
	if to_go.length() <= STALK_SPEED * delta:
		position = spot
		_face(-side)
		_strike()
	elif not _walk(to_go.normalized(), STALK_SPEED, delta):
		_stand()


func _strike() -> void:
	_enter(STRIKE)
	_state_seconds = STRIKE_SECONDS
	_play(STRIKE, 2.0 / STRIKE_SECONDS)


## The bill comes up: with the frog, if it was still under its tip, which it swallows.
func _finish_strike() -> void:
	var tip := position + Vector2(_facing * BILL_REACH, 0.0)
	if _has_prey() and _prey.position.distance_to(tip) <= CATCH_DISTANCE:
		_prey.is_done = true
		_enter(SWALLOW)
		_state_seconds = SWALLOW_SECONDS
		_play(SWALLOW, 2.0 / SWALLOW_SECONDS)
	else:
		_choose_next()


## Whether its frog is still about: not caught, not gone (the view frees what is done).
func _has_prey() -> bool:
	return is_instance_valid(_prey) and not _prey.is_done


func _stand() -> void:
	_enter(STAND)
	_state_seconds = wildlife.rng.randf_range(1.5, 4.0)
	_play(STAND, 0.4)


func _clatter() -> void:
	_enter(CLATTER)
	_state_seconds = wildlife.rng.randf_range(1.2, 2.0)
	_play(CLATTER, 10.0)


## On a roof: it stands, and now and then clatters; it stays on top of the roof as snow comes
## and goes, and leaves if the house is gone.
func _choose_on_roof() -> void:
	if not wildlife.is_standing(roof):
		_take_off(_away_from_view_centre())
		return
	_landing_lift = wildlife.roof_lift(roof, _roof_column)
	_lift = _landing_lift
	if _state != CLATTER and wildlife.rng.randf() < ROOF_CLATTER_CHANCE:
		_clatter()
	else:
		_perch()


func _perch() -> void:
	_enter(PERCH)
	_state_seconds = wildlife.rng.randf_range(3.0, 8.0)
	_play(STAND, 0.25)
	_is_ping_pong = false
	z_index = 0
	shadow_half_width = 0
	queue_redraw()


func _take_off(away: Vector2) -> void:
	_enter(FLY)
	_start_flying((away + Vector2(0.0, -0.3)).normalized())


func _start_flying(direction: Vector2) -> void:
	_flight_direction = direction
	_face(direction.x)
	_play(FLY, WINGBEAT_FRAMES_PER_SECOND)
	_is_ping_pong = true
	z_index = 1
	shadow_half_width = 0
	queue_redraw()
	_shadow.show()


func _fly(delta: float) -> void:
	position += _flight_direction * FLY_SPEED * delta
	# It climbs to its height and never sinks on the way out.
	var height := FLIGHT_HEIGHT if roof == null else _landing_lift + ROOF_CLEARANCE
	_lift = minf(_lift + CLIMB_SPEED * delta, maxf(height, _lift))
	_beat_or_glide()
	_shadow.set_point(0, position)
	if _is_out_of_view(LEAVE_MARGIN):
		is_done = true


## Flies on to the roof, sinking from its height as it comes nearer, and lands.
func _arrive(delta: float) -> void:
	var to_go := _landing - position
	var step := FLY_SPEED * delta
	if to_go.length() <= step:
		position = _landing
		_lift = _landing_lift
		_shadow.hide()
		_perch()
		return
	position += to_go.normalized() * step
	var progress := 1.0 - position.distance_to(_landing) / _arrival_distance
	_lift = lerpf(_arrival_lift, _landing_lift, progress)
	_beat_or_glide()
	_shadow.set_point(0, position)


## Storks flap a few slow beats, then glide on outstretched wings.
func _beat_or_glide() -> void:
	if fmod(_state_time, FLAP_SECONDS + GLIDE_SECONDS) > FLAP_SECONDS:
		# Held on the frame with the wings level (the middle of the step).
		_action_time = (GLIDE_FRAME + 0.5) / WINGBEAT_FRAMES_PER_SECOND
