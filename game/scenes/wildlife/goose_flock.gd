class_name GooseFlock
extends Animal
## A flock of greylag geese grazing on the marsh. Each goose grazes, looks up or takes a few
## steps on its own, keeping near the others; they all raise their heads when the player comes
## near, and all take off together when the player comes nearer (or the flock is sent away):
## they climb with slow wingbeats, close up into a V and fly out of the view.
##
## The node is the middle of the flock; each goose is a sprite of its own, sorted with the rest
## of the world by its feet (the node sorts its children with its parent's). Their shadows lie on
## the ground layer: under their feet while they graze, falling further off as they climb.

## The flock's states: grazing, heads up, flying off.
const GRAZE := &"graze"
const ALERT := &"alert"
const FLY := &"fly"

const SHEET := &"goose"
const FLOCK_SIZE := Vector2i(6, 12)
## How far from the middle a goose may wander, and how close to another one it starts.
const RADIUS := 26.0
const MIN_SPACING := 7.0
## How many spots are tried for each goose of the flock before it makes do with fewer geese.
const PLACING_TRIES := 20
const WALK_SPEED := 4.0
## A goose picks what to do next by these chances: graze, else stand, else walk.
const GRAZE_CHANCE := 0.6
const STAND_CHANCE := 0.25
## The frames per second of each thing a goose does.
const FRAMES_PER_SECOND := {&"stand": 0.3, &"graze": 1.5, &"walk": 4.0, &"fly": 5.0}
const FLY_SPEED := 30.0
const CLIMB_SPEED := 16.0
const FLIGHT_HEIGHT := 56.0
## They close up into a V over this many seconds after taking off.
const FORMING_SECONDS := 3.0
const V_SPACING := Vector2(14.0, 12.0)
const SHADOW_HALF_WIDTH := 3
## It is gone once it is this far outside the view: far enough for the V and its height.
const LEAVE_MARGIN := 140.0
## The flock goes back to grazing once the player is this many tiles farther than the distance
## that alerted it.
const CALM_EXTRA_TILES := 1.5

var _geese: Array[Goose] = []
var _shadows: GroundShadows
var _flight_direction := Vector2.RIGHT
## The frames of each thing a goose does, looked up once; the wingbeat goes up, level, down,
## level.
var _frames := {}


## One goose of the flock: what it does and for how long, and where it is.
class Goose:
	var sprite: Sprite2D
	## Where it stands from the flock's middle; in flight, where it flies.
	var spot := Vector2.ZERO
	## Where it was when the flock took off, and its place in the V.
	var take_off_spot := Vector2.ZERO
	var v_spot := Vector2.ZERO
	var action := &"graze"
	var seconds_left := 0.0
	var action_time := 0.0
	var walk_direction := Vector2.ZERO
	var shown_frame := -1


func _init() -> void:
	super(WildlifeRules.GEESE, SHEET)
	shadow_half_width = 0


func _ready() -> void:
	super()
	_sprite.hide()
	y_sort_enabled = true
	for action: StringName in FRAMES_PER_SECOND:
		var frames := PackedInt32Array()
		for column in WildlifeSprites.frame_count(SHEET, action):
			frames.append(WildlifeSprites.frame_index(SHEET, action, column))
		_frames[action] = frames
	_frames[&"fly"].append(_frames[&"fly"][1])
	_place_geese(wildlife.rng.randi_range(FLOCK_SIZE.x, FLOCK_SIZE.y))
	# Where no goose could stand there is no flock.
	is_done = _geese.is_empty()
	_shadows = GroundShadows.new(_geese.size(), SHADOW_HALF_WIDTH)
	_shadows.shift = Vector2.ZERO
	wildlife.ground.add_child(_shadows)
	_enter(GRAZE)


func _exit_tree() -> void:
	_shadows.queue_free()


func dismiss() -> void:
	if _state != FLY:
		_take_off(_away_from_view_centre())


func _update(delta: float) -> void:
	var reaction := _reaction()
	if _state != FLY and reaction == WildlifeRules.Reaction.FLEE:
		_take_off(_away_from_player())
	elif _state == GRAZE and reaction == WildlifeRules.Reaction.ALERT:
		_enter(ALERT)
		for goose in _geese:
			_start(goose, &"stand", INF)
			goose.sprite.flip_h = wildlife.world_view.player_feet.x < position.x + goose.spot.x
	elif _state == ALERT:
		if _player_distance_tiles() > wildlife.rules.alert_tiles(kind) + CALM_EXTRA_TILES:
			_enter(GRAZE)
			for goose in _geese:
				goose.seconds_left = wildlife.rng.randf_range(0.0, 2.0)
	if _state == FLY:
		_fly(delta)
		return
	for i in _geese.size():
		var goose := _geese[i]
		goose.action_time += delta
		goose.seconds_left -= delta
		if goose.seconds_left <= 0.0:
			_choose_next(goose)
		if goose.action == &"walk":
			_step(goose, delta)
		goose.sprite.position = goose.spot
		_show(goose)
		_shadows.set_point(i, position + goose.spot)


## Spreads the geese around the middle, each where it can stand and not on top of another.
func _place_geese(count: int) -> void:
	for _try in count * PLACING_TRIES:
		if _geese.size() == count:
			return
		var spot := Vector2.from_angle(wildlife.rng.randf() * TAU) * RADIUS
		spot *= sqrt(wildlife.rng.randf())
		if not wildlife.can_stand(position + spot) or _is_crowded(spot):
			continue
		var goose := Goose.new()
		goose.spot = spot
		goose.sprite = WildlifeSprites.make_sprite(SHEET)
		goose.sprite.flip_h = wildlife.rng.randf() < 0.5
		add_child(goose.sprite)
		_geese.append(goose)
		_start(goose, &"graze", wildlife.rng.randf_range(0.0, 4.0))


func _is_crowded(spot: Vector2) -> bool:
	for goose in _geese:
		if goose.spot.distance_to(spot) < MIN_SPACING:
			return true
	return false


func _start(goose: Goose, action: StringName, seconds: float) -> void:
	goose.action = action
	goose.seconds_left = seconds
	goose.action_time = 0.0


## A goose grazes, stands and looks round, or walks a few steps, back towards the others if it
## has strayed.
func _choose_next(goose: Goose) -> void:
	var roll := wildlife.rng.randf()
	if roll < GRAZE_CHANCE:
		_start(goose, &"graze", wildlife.rng.randf_range(2.0, 6.0))
	elif roll < GRAZE_CHANCE + STAND_CHANCE:
		_start(goose, &"stand", wildlife.rng.randf_range(1.0, 3.0))
		if wildlife.rng.randf() < 0.3:
			goose.sprite.flip_h = not goose.sprite.flip_h
	else:
		_start(goose, &"walk", wildlife.rng.randf_range(1.0, 2.5))
		var direction := Vector2.from_angle(wildlife.rng.randf() * TAU)
		if goose.spot.length() > RADIUS * 0.6:
			direction = (-goose.spot).normalized().rotated(wildlife.rng.randf_range(-1.0, 1.0))
		goose.walk_direction = direction
		goose.sprite.flip_h = direction.x < 0.0


func _step(goose: Goose, delta: float) -> void:
	var next := goose.spot + goose.walk_direction * WALK_SPEED * delta
	if next.length() > RADIUS or not wildlife.can_stand(position + next):
		goose.seconds_left = 0.0
	else:
		goose.spot = next


func _show(goose: Goose) -> void:
	var frames: PackedInt32Array = _frames[goose.action]
	var step := int(goose.action_time * FRAMES_PER_SECOND[goose.action])
	var frame := frames[step % frames.size()]
	if frame != goose.shown_frame:
		goose.shown_frame = frame
		goose.sprite.frame = frame


## All take off together and fly off; on the way they close up into a V, the goose furthest
## ahead leading.
func _take_off(away: Vector2) -> void:
	_enter(FLY)
	z_index = 1
	_flight_direction = (away + Vector2(0.0, -0.3)).normalized()
	_geese.sort_custom(
		func(a: Goose, b: Goose) -> bool:
			return a.spot.dot(_flight_direction) > b.spot.dot(_flight_direction)
	)
	var v_spots := Flock.v_offsets(_flight_direction, _geese.size(), V_SPACING)
	for i in _geese.size():
		var goose := _geese[i]
		goose.take_off_spot = goose.spot
		goose.v_spot = v_spots[i]
		goose.sprite.flip_h = _flight_direction.x < 0.0
		# Each a little out of step with the others.
		_start(goose, &"fly", INF)
		goose.action_time = i * 0.13


func _fly(delta: float) -> void:
	position += _flight_direction * FLY_SPEED * delta
	_lift = minf(_lift + CLIMB_SPEED * delta, FLIGHT_HEIGHT)
	_shadows.shift = GroundShadows.SHIFT * _lift / FLIGHT_HEIGHT
	var forming := smoothstep(0.0, FORMING_SECONDS, _state_time)
	for i in _geese.size():
		var goose := _geese[i]
		goose.action_time += delta
		goose.spot = goose.take_off_spot.lerp(goose.v_spot, forming)
		goose.sprite.position = goose.spot + Vector2(0.0, -_lift)
		_show(goose)
		_shadows.set_point(i, position + goose.spot)
	if _is_out_of_view(LEAVE_MARGIN):
		is_done = true


## The frame of the base class is not used: every goose sets its own.
func _show_frame() -> void:
	pass
