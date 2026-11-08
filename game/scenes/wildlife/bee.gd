class_name Bee
extends Animal
## A bee at the flowers: hovers over one with a jitter, then buzzes to another nearby. With no
## flower in reach (they are gone for the year) it flies off.

const HOVER := &"hover"
const TRAVEL := &"travel"
const LEAVE := &"leave"

const TRAVEL_SPEED := 56.0
## How far it looks for the next flower, in tiles.
const FLOWER_REACH_TILES := 4
## How high above the flower it flies, in pixels.
const FLIGHT_HEIGHT := 12.0
## The pixels it jitters by while hovering, and how often it picks a new spot.
const JITTER := Vector2(3.0, 2.0)
const JITTER_SECONDS := 0.12
const LEAVE_MARGIN := 24.0

var _state_seconds := 4.0
var _flower := Vector2i.ZERO
var _jitter_goal := Vector2.ZERO
var _jitter_seconds := 0.0
var _flight_direction := Vector2.RIGHT


func _init() -> void:
	super(WildlifeRules.BEE)
	shadow_half_width = 0


func _ready() -> void:
	super()
	_lift = FLIGHT_HEIGHT
	z_index = 1
	_flower = Vector2i((position / WildlifeRules.TILE_SIZE).floor())
	_hover()


func dismiss() -> void:
	_leave(_away_from_view_centre())


func _update(delta: float) -> void:
	match _state:
		HOVER:
			_jitter(delta)
			if _state_time >= _state_seconds:
				_fly_to_next_flower()
		TRAVEL:
			_travel(delta)
		LEAVE:
			position += _flight_direction * TRAVEL_SPEED * delta
			if _is_out_of_view(LEAVE_MARGIN):
				is_done = true


func _hover() -> void:
	_enter(HOVER)
	_state_seconds = wildlife.rng.randf_range(3.0, 8.0)
	_play(HOVER, 24.0)


## Moves a little around in the air, as if it could not make up its mind.
func _jitter(delta: float) -> void:
	_jitter_seconds -= delta
	if _jitter_seconds <= 0.0:
		_jitter_seconds = JITTER_SECONDS
		_jitter_goal = Vector2(
			wildlife.rng.randf_range(-JITTER.x, JITTER.x),
			wildlife.rng.randf_range(-JITTER.y, JITTER.y)
		)
	var speed := Vector2(40.0, 24.0)
	_sprite.position.x = move_toward(_sprite.position.x, _jitter_goal.x, speed.x * delta)
	_arc = move_toward(_arc, _jitter_goal.y, speed.y * delta)


func _fly_to_next_flower() -> void:
	var flowers := wildlife.flowers_near(position, FLOWER_REACH_TILES)
	flowers.erase(_flower)
	if flowers.is_empty():
		if wildlife.has_flower(_flower):
			_hover()
		else:
			_leave(Vector2.from_angle(wildlife.rng.randf() * TAU))
		return
	_flower = flowers[wildlife.rng.randi() % flowers.size()]
	_enter(TRAVEL)
	_sprite.position.x = 0.0
	_arc = 0.0
	_play(HOVER, 24.0)


func _travel(delta: float) -> void:
	var goal := TerrainTileset.tile_centre(_flower)
	var to_goal := goal - position
	if to_goal.length() <= TRAVEL_SPEED * delta:
		position = goal
		_hover()
		return
	position += to_goal.normalized() * TRAVEL_SPEED * delta
	_face(to_goal.x)
	# A wavering flight: up and down a little as it goes.
	_arc = sin(_state_time * 9.0) * 2.0


func _leave(direction: Vector2) -> void:
	_enter(LEAVE)
	_flight_direction = direction
	_face(direction.x)
