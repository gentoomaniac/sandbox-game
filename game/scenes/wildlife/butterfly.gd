class_name Butterfly
extends Animal
## A butterfly over the meadow: flutters along lazy curves, up and down a little, and turns
## back at the water's edge.

const FLUTTER := &"flutter"
const LEAVE := &"leave"
## The colours the sheet has, one row each.
const VARIANTS: Array[StringName] = [&"flutter", &"flutter_pale", &"flutter_pink"]

const SPEED := 11.0 * TerrainTileset.ART_16_SCALE
const LEAVE_SPEED := 22.0 * TerrainTileset.ART_16_SCALE
## The most it turns per second, in radians, and how slowly the turning swings from one side
## to the other.
const MAX_TURN := 1.3
const TURN_SWING := 0.6
const FLIGHT_HEIGHT := 7.0 * TerrainTileset.ART_16_SCALE
const BOB := 3.0 * TerrainTileset.ART_16_SCALE
const LEAVE_MARGIN := 12.0 * TerrainTileset.ART_16_SCALE

var _heading := 0.0
var _swing_phase := 0.0


func _init() -> void:
	super(WildlifeRules.BUTTERFLY)
	shadow_half_width = 0


func _ready() -> void:
	super()
	z_index = 1
	_is_ping_pong = true
	_heading = wildlife.rng.randf() * TAU
	_swing_phase = wildlife.rng.randf() * TAU
	_enter(FLUTTER)
	_play(VARIANTS[wildlife.rng.randi() % VARIANTS.size()], 7.0)


func dismiss() -> void:
	_enter(LEAVE)
	_heading = _away_from_view_centre().angle()


func _update(delta: float) -> void:
	var seconds := _state_time + _swing_phase
	_lift = FLIGHT_HEIGHT + sin(seconds * 2.3) * BOB
	if _state == LEAVE:
		position += Vector2.from_angle(_heading) * LEAVE_SPEED * delta
		_face(cos(_heading))
		if _is_out_of_view(LEAVE_MARGIN):
			is_done = true
		return
	_heading += sin(seconds * TURN_SWING) * MAX_TURN * delta
	var direction := Vector2.from_angle(_heading)
	# Over the water the way it came: a butterfly stays over the meadow.
	if _walk(direction, SPEED, delta):
		return
	_heading += PI * 0.8
