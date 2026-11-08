class_name Tern
extends Animal
## A common tern fishing over the sea in summer. It flies along over the water, turning back where
## the water ends ahead, stops to hover with its head bent down, and plunges in with a splash; it
## comes up again, now and then with a fish in its bill, and flies on. After a few dives (or when
## sent away) it flies out of the view. It takes no notice of the player.
##
## Its node's position is the point of the water below it; the bird is drawn `_lift` pixels above,
## and its shadow falls on the water.

## Flying along, hovering, plunging in, and the splash where it is under water.
const PATROL := &"patrol"
const HOVER := &"hover"
const DIVE := &"dive"
const SPLASH := &"splash"

const FLY_SPEED := 30.0 * TerrainTileset.ART_16_SCALE
const CLIMB_SPEED := 16.0 * TerrainTileset.ART_16_SCALE
const FLIGHT_HEIGHT := 28.0 * TerrainTileset.ART_16_SCALE
## How fast it falls when it plunges, in pixels per second.
const DIVE_SPEED := 80.0 * TerrainTileset.ART_16_SCALE
## The seconds it flies along before it stops to hover, and hovers.
const PATROL_SECONDS := Vector2(2.0, 5.0)
const HOVER_SECONDS := Vector2(1.0, 2.5)
## The chance that a hover ends in a plunge, else it flies on.
const DIVE_CHANCE := 0.6
## How many times it plunges before it leaves.
const DIVES := Vector2i(2, 4)
const SPLASH_SECONDS := 0.9
## The chance that it comes up with a fish, and how long it carries the fish before it is eaten.
const CATCH_CHANCE := 0.4
const FISH_SECONDS := 4.0
## It looks this far ahead, in pixels, for where the water ends.
const LOOK_AHEAD := 16.0 * TerrainTileset.ART_16_SCALE
## The frames per second of its wingbeat in flight and hovering.
const WINGBEAT_FRAMES_PER_SECOND := 8.0
const HOVER_FRAMES_PER_SECOND := 10.0
## It is gone once it is this far outside the view: far enough for its height and its wings.
const LEAVE_MARGIN := 48.0 * TerrainTileset.ART_16_SCALE

var _state_seconds := 1.0
var _direction := Vector2.RIGHT
var _dives_left := 0
## How long it has still to carry its fish, in seconds; 0 for none.
var _fish_seconds := 0.0
var _shadow: GroundShadows


func _init() -> void:
	super(WildlifeRules.TERN)
	shadow_half_width = 0


func _ready() -> void:
	super()
	_lift = FLIGHT_HEIGHT
	_dives_left = wildlife.rng.randi_range(DIVES.x, DIVES.y)
	# Into the view, along the coast's tideways, which run from east to west.
	var towards_view := signf(wildlife.view_rect().get_center().x - position.x)
	_direction = Vector2(towards_view if towards_view != 0.0 else 1.0, 0.0)
	_direction = _direction.rotated(wildlife.rng.randf_range(-0.3, 0.3))
	_shadow = GroundShadows.new(1, 2)
	wildlife.ground.add_child(_shadow)
	_patrol()


func _exit_tree() -> void:
	_shadow.queue_free()


func dismiss() -> void:
	_dives_left = 0
	if _state != DIVE and _state != SPLASH:
		_direction = _away_from_view_centre()
		_patrol()


## Whether it carries a fish.
func has_fish() -> bool:
	return _fish_seconds > 0.0


func _update(delta: float) -> void:
	_fish_seconds = maxf(_fish_seconds - delta, 0.0)
	match _state:
		PATROL:
			_fly_along(delta)
			if _state_time >= _state_seconds and _dives_left > 0 and wildlife.is_water(position):
				_hover()
			elif _dives_left == 0 and _is_out_of_view(LEAVE_MARGIN):
				is_done = true
		HOVER:
			if _state_time >= _state_seconds:
				if wildlife.rng.randf() < DIVE_CHANCE and wildlife.is_water(position):
					_dive()
				else:
					_patrol()
		DIVE:
			_lift -= DIVE_SPEED * delta
			if _lift <= 0.0:
				_splash()
		SPLASH:
			if _state_time >= SPLASH_SECONDS:
				if wildlife.rng.randf() < CATCH_CHANCE:
					_fish_seconds = FISH_SECONDS
				_patrol()
	if _state == PATROL:
		# The fish is eaten on the wing: the wingbeat goes on from where it was.
		_play(&"fly_with_fish" if has_fish() else &"fly", WINGBEAT_FRAMES_PER_SECOND)
	_shadow.shift = GroundShadows.SHIFT * _lift / FLIGHT_HEIGHT
	_shadow.set_point(0, position)


func _patrol() -> void:
	_enter(PATROL)
	_state_seconds = wildlife.rng.randf_range(PATROL_SECONDS.x, PATROL_SECONDS.y)
	_face(_direction.x)
	_is_ping_pong = true
	z_index = 1
	_shadow.show()


## Flies on, climbing back to its height; while it still fishes it turns back where the water ends
## ahead of it (only over water: from over the mud it flies on until it is over water again).
func _fly_along(delta: float) -> void:
	var is_fishing := _dives_left > 0
	if is_fishing and wildlife.is_water(position):
		if not wildlife.is_water(position + _direction * LOOK_AHEAD):
			_direction = Vector2(-_direction.x, wildlife.rng.randf_range(-0.4, 0.4)).normalized()
			_face(_direction.x)
	position += _direction * FLY_SPEED * delta
	_lift = minf(_lift + CLIMB_SPEED * delta, FLIGHT_HEIGHT)


func _hover() -> void:
	_enter(HOVER)
	_state_seconds = wildlife.rng.randf_range(HOVER_SECONDS.x, HOVER_SECONDS.y)
	_is_ping_pong = false
	_play(&"hover", HOVER_FRAMES_PER_SECOND)


func _dive() -> void:
	_enter(DIVE)
	_dives_left -= 1
	_play(&"dive", 2.0 * DIVE_SPEED / FLIGHT_HEIGHT)


func _splash() -> void:
	_enter(SPLASH)
	_lift = 0.0
	_fish_seconds = 0.0
	_play(&"splash", 3.0 / SPLASH_SECONDS)
	# On the water, sorted with what stands around it.
	z_index = 0
	_shadow.hide()
