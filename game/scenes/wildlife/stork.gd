class_name Stork
extends Animal
## A white stork. On wet ground (kind STORK) it hunts: slow steps with the head down, a stab
## into the grass now and then, a look round; it flies off with slow wingbeats when the player
## comes near. On a roof (kind ROOF_STORK) it flies in, lands on the ridge and stands there,
## clattering its bill now and then, until it is sent away or the house is gone.
##
## A flying stork is drawn `_lift` pixels above the point of the ground below it, its node's
## position. On a roof that point is just in front of the house, so the stork sorts in front of
## the roof it stands on and behind whatever stands in front of the house.

const STAND := &"stand"
const WALK := &"walk"
const STRIKE := &"strike"
const CLATTER := &"clatter"
const FLY := &"fly"
## Flying to a roof, and standing on it.
const ARRIVE := &"arrive"
const PERCH := &"perch"

const WALK_SPEED := 6.0
const FLY_SPEED := 32.0
const CLIMB_SPEED := 14.0
## How high it flies over open ground, and above the roof it flies to or leaves.
const FLIGHT_HEIGHT := 40.0
const ROOF_CLEARANCE := 24.0
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
## It is gone once it is this far outside the view: far enough for its height and its wings.
const LEAVE_MARGIN := 72.0

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


func _init(stork_kind: StringName) -> void:
	super(stork_kind, WildlifeRules.STORK)
	shadow_half_width = 4


func _ready() -> void:
	super()
	_shadow = GroundShadows.new(1, 3)
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
		STAND, STRIKE, CLATTER:
			if _state_time >= _state_seconds:
				if roof == null:
					_choose_next()
				else:
					_choose_on_roof()
		WALK:
			if _state_time >= _state_seconds or not _walk(_walk_direction, WALK_SPEED, delta):
				_choose_next()
		PERCH:
			if _state_time >= _state_seconds:
				_choose_on_roof()
		ARRIVE:
			_arrive(delta)
		FLY:
			_fly(delta)


func _choose_next() -> void:
	var roll := wildlife.rng.randf()
	if _state == WALK and roll < 0.35:
		_enter(STRIKE)
		_state_seconds = 0.8
		_play(STRIKE, 2.5)
	elif roll < GROUND_CLATTER_CHANCE:
		_clatter()
	elif _state != WALK and roll < 0.75:
		_enter(WALK)
		_state_seconds = wildlife.rng.randf_range(2.0, 5.0)
		_walk_direction = Vector2.from_angle(wildlife.rng.randf() * TAU)
		_play(WALK, 4.0)
	else:
		_stand()


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
