class_name GroundFlock
extends Animal
## A flock of birds feeding on the ground: greylag geese grazing on the marsh, oystercatchers and
## dunlin probing the tidal mud. Each bird feeds, looks up or takes a few steps on its own, keeping
## near the others; they all raise their heads when the player comes near, and all take off
## together when the player comes nearer, when the tide comes in over the mud they stand on, or
## when the flock is sent away: they climb and fly out of the view, geese closing up into a V,
## waders into a tight bunch that dunlin swing round in a wheel.
##
## The node is the middle of the flock; each bird is a sprite of its own, sorted with the rest
## of the world by its feet (the node sorts its children with its parent's). Their shadows lie on
## the ground layer: under their feet while they feed, falling further off as they climb.

## The flock's states: feeding, heads up, flying off.
const FEED := &"feed"
const ALERT := &"alert"
const FLY := &"fly"

## Per kind: the sheet its birds show and its action of feeding (`feed`); how many birds there
## are, how far from the middle one may wander (`radius`) and how close to another one it starts
## (`spacing`); its walking speed; the chances by which a bird picks what to do next (feed, else
## stand, else walk); the frames per second of each action; its speed, climb and height in
## flight, in pixels; how far apart the birds keep in the V they close up into along and across
## the way they fly (zero: no V, they close up into a bunch); how fast the flock turns in the
## first WHEEL_SECONDS of its flight, in radians per second, to one side or the other; and half
## the width of their shadows.
const FLOCKS := {
	WildlifeRules.GEESE:
	{
		"sheet": &"goose",
		"feed": &"graze",
		"size": Vector2i(6, 12),
		"radius": 52.0,
		"spacing": 14.0,
		"walk_speed": 8.0,
		"feed_chance": 0.6,
		"stand_chance": 0.25,
		"frames_per_second": {&"stand": 0.3, &"graze": 1.5, &"walk": 4.0, &"fly": 5.0},
		"fly_speed": 60.0,
		"climb_speed": 32.0,
		"flight_height": 112.0,
		"v_spacing": Vector2(28.0, 24.0),
		"wheel": 0.0,
		"shadow": 6,
	},
	WildlifeRules.OYSTERCATCHER:
	{
		"sheet": &"oystercatcher",
		"feed": &"probe",
		"size": Vector2i(2, 5),
		"radius": 32.0,
		"spacing": 12.0,
		"walk_speed": 12.0,
		"feed_chance": 0.6,
		"stand_chance": 0.2,
		"frames_per_second": {&"stand": 0.4, &"probe": 3.0, &"walk": 5.0, &"fly": 10.0},
		"fly_speed": 80.0,
		"climb_speed": 28.0,
		"flight_height": 36.0,
		"v_spacing": Vector2.ZERO,
		"wheel": 0.0,
		"shadow": 4,
	},
	WildlifeRules.DUNLIN:
	{
		"sheet": &"dunlin",
		"feed": &"probe",
		"size": Vector2i(12, 24),
		"radius": 36.0,
		"spacing": 8.0,
		"walk_speed": 14.0,
		"feed_chance": 0.75,
		"stand_chance": 0.1,
		"frames_per_second": {&"stand": 0.5, &"probe": 6.0, &"walk": 7.0, &"fly": 16.0},
		"fly_speed": 100.0,
		"climb_speed": 32.0,
		"flight_height": 40.0,
		"v_spacing": Vector2.ZERO,
		"wheel": 0.7,
		"shadow": 2,
	},
}
## How many spots are tried for each bird of the flock before it makes do with fewer birds.
const PLACING_TRIES := 20
## They close up over this many seconds after taking off; a bunch to this share of how far apart
## the birds stood.
const FORMING_SECONDS := 3.0
const BUNCH_CLOSING := 0.5
const WHEEL_SECONDS := 2.5
## It is gone once it is this far outside the view: far enough for the V and its height.
const LEAVE_MARGIN := 280.0
## The flock goes back to feeding once the player is this many tiles farther than the distance
## that alerted it.
const CALM_EXTRA_TILES := 1.5

var _birds: Array[FlockBird] = []
var _shadows: GroundShadows
var _flight_direction := Vector2.RIGHT
## How fast it turns in flight, in radians per second (see FLOCKS).
var _wheel := 0.0
## The numbers of its kind (see FLOCKS), and its action of feeding.
var _flock: Dictionary
var _feed: StringName
## The frames of each action, looked up once; the wingbeat goes up, level, down, level.
var _frames := {}


## One bird of the flock: what it does and for how long, and where it is.
class FlockBird:
	var sprite: Sprite2D
	## Where it stands from the flock's middle; in flight, where it flies.
	var spot := Vector2.ZERO
	## Where it was when the flock took off, and its place in the V.
	var take_off_spot := Vector2.ZERO
	var v_spot := Vector2.ZERO
	var action := &""
	var seconds_left := 0.0
	var action_time := 0.0
	var walk_direction := Vector2.ZERO
	var shown_frame := -1


func _init(flock_kind: StringName) -> void:
	_flock = FLOCKS[flock_kind]
	_feed = _flock["feed"]
	super(flock_kind, _flock["sheet"])
	shadow_half_width = 0


func _ready() -> void:
	super()
	_sprite.hide()
	y_sort_enabled = true
	for action: StringName in _flock["frames_per_second"]:
		var frames := PackedInt32Array()
		for column in WildlifeSprites.frame_count(_sheet_kind, action):
			frames.append(WildlifeSprites.frame_index(_sheet_kind, action, column))
		_frames[action] = frames
	_frames[&"fly"].append(_frames[&"fly"][1])
	var size: Vector2i = _flock["size"]
	_place_birds(wildlife.rng.randi_range(size.x, size.y))
	# Where no bird could stand there is no flock.
	is_done = _birds.is_empty()
	_shadows = GroundShadows.new(_birds.size(), _flock["shadow"])
	_shadows.shift = Vector2.ZERO
	wildlife.ground.add_child(_shadows)
	_enter(FEED)


func _exit_tree() -> void:
	_shadows.queue_free()


func show_art_set() -> void:
	super()
	for bird in _birds:
		bird.sprite.texture = _sprite.texture


func dismiss() -> void:
	if _state != FLY:
		_take_off(_away_from_view_centre())


func _update(delta: float) -> void:
	var reaction := _reaction()
	if _state != FLY and reaction == WildlifeRules.Reaction.FLEE:
		_take_off(_away_from_player())
	elif _state != FLY and wildlife.is_water(position):
		# The tide came in over the mud they stood on.
		_take_off(_away_from_view_centre())
	elif _state == FEED and reaction == WildlifeRules.Reaction.ALERT:
		_enter(ALERT)
		for bird in _birds:
			_start(bird, &"stand", INF)
			bird.sprite.flip_h = wildlife.world_view.player_feet.x < position.x + bird.spot.x
	elif _state == ALERT:
		if _player_distance_tiles() > wildlife.rules.alert_tiles(kind) + CALM_EXTRA_TILES:
			_enter(FEED)
			for bird in _birds:
				bird.seconds_left = wildlife.rng.randf_range(0.0, 2.0)
	if _state == FLY:
		_fly(delta)
		return
	for i in _birds.size():
		var bird := _birds[i]
		bird.action_time += delta
		bird.seconds_left -= delta
		if bird.seconds_left <= 0.0:
			_choose_next(bird)
		if bird.action == &"walk":
			_step(bird, delta)
		bird.sprite.position = bird.spot
		_show(bird)
		_shadows.set_point(i, position + bird.spot)


## Spreads the birds around the middle, each where it can stand and not on top of another.
func _place_birds(count: int) -> void:
	for _try in count * PLACING_TRIES:
		if _birds.size() == count:
			return
		var radius: float = _flock["radius"]
		var spot := Vector2.from_angle(wildlife.rng.randf() * TAU) * radius
		spot *= sqrt(wildlife.rng.randf())
		if not wildlife.can_stand(position + spot, kind) or _is_crowded(spot):
			continue
		var bird := FlockBird.new()
		bird.spot = spot
		bird.sprite = WildlifeSprites.make_sprite(_sheet_kind)
		bird.sprite.flip_h = wildlife.rng.randf() < 0.5
		add_child(bird.sprite)
		_birds.append(bird)
		_start(bird, _feed, wildlife.rng.randf_range(0.0, 4.0))


func _is_crowded(spot: Vector2) -> bool:
	for bird in _birds:
		if bird.spot.distance_to(spot) < _flock["spacing"]:
			return true
	return false


func _start(bird: FlockBird, action: StringName, seconds: float) -> void:
	bird.action = action
	bird.seconds_left = seconds
	bird.action_time = 0.0


## A bird feeds, stands and looks round, or walks a few steps, back towards the others if it
## has strayed.
func _choose_next(bird: FlockBird) -> void:
	var roll := wildlife.rng.randf()
	var feed_chance: float = _flock["feed_chance"]
	if roll < feed_chance:
		_start(bird, _feed, wildlife.rng.randf_range(2.0, 6.0))
	elif roll < feed_chance + _flock["stand_chance"]:
		_start(bird, &"stand", wildlife.rng.randf_range(1.0, 3.0))
		if wildlife.rng.randf() < 0.3:
			bird.sprite.flip_h = not bird.sprite.flip_h
	else:
		_start(bird, &"walk", wildlife.rng.randf_range(1.0, 2.5))
		var direction := Vector2.from_angle(wildlife.rng.randf() * TAU)
		if bird.spot.length() > _flock["radius"] * 0.6:
			direction = (-bird.spot).normalized().rotated(wildlife.rng.randf_range(-1.0, 1.0))
		bird.walk_direction = direction
		bird.sprite.flip_h = direction.x < 0.0


func _step(bird: FlockBird, delta: float) -> void:
	var next: Vector2 = bird.spot + bird.walk_direction * _flock["walk_speed"] * delta
	if next.length() > _flock["radius"] or not wildlife.can_stand(position + next, kind):
		bird.seconds_left = 0.0
	else:
		bird.spot = next


func _show(bird: FlockBird) -> void:
	var frames: PackedInt32Array = _frames[bird.action]
	var frames_per_second: float = _flock["frames_per_second"][bird.action]
	var step := int(bird.action_time * frames_per_second)
	var frame := frames[step % frames.size()]
	if frame != bird.shown_frame:
		bird.shown_frame = frame
		bird.sprite.frame = frame


## All take off together and fly off; on the way they close up into a V, the bird furthest
## ahead leading, or into a bunch.
func _take_off(away: Vector2) -> void:
	_enter(FLY)
	z_index = 1
	_flight_direction = (away + Vector2(0.0, -0.3)).normalized()
	_wheel = _flock["wheel"] * (1.0 if wildlife.rng.randf() < 0.5 else -1.0)
	_birds.sort_custom(
		func(a: FlockBird, b: FlockBird) -> bool:
			return a.spot.dot(_flight_direction) > b.spot.dot(_flight_direction)
	)
	var v_spacing: Vector2 = _flock["v_spacing"]
	var v_spots := Flock.v_offsets(_flight_direction, _birds.size(), v_spacing)
	for i in _birds.size():
		var bird := _birds[i]
		bird.take_off_spot = bird.spot
		bird.v_spot = v_spots[i] if v_spacing != Vector2.ZERO else bird.spot * BUNCH_CLOSING
		bird.sprite.flip_h = _flight_direction.x < 0.0
		# Each a little out of step with the others.
		_start(bird, &"fly", INF)
		bird.action_time = i * 0.13


func _fly(delta: float) -> void:
	var flight_height: float = _flock["flight_height"]
	if _state_time < WHEEL_SECONDS:
		_flight_direction = _flight_direction.rotated(_wheel * delta)
	position += _flight_direction * _flock["fly_speed"] * delta
	_lift = minf(_lift + _flock["climb_speed"] * delta, flight_height)
	_shadows.shift = GroundShadows.SHIFT * _lift / flight_height
	var forming := smoothstep(0.0, FORMING_SECONDS, _state_time)
	for i in _birds.size():
		var bird := _birds[i]
		bird.action_time += delta
		bird.spot = bird.take_off_spot.lerp(bird.v_spot, forming)
		bird.sprite.position = bird.spot + Vector2(0.0, -_lift)
		bird.sprite.flip_h = _flight_direction.x < 0.0
		_show(bird)
		_shadows.set_point(i, position + bird.spot)
	if _is_out_of_view(LEAVE_MARGIN):
		is_done = true


## The frame of the base class is not used: every bird sets its own.
func _show_frame() -> void:
	pass
