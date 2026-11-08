class_name Frog
extends Animal
## A frog at the water's edge and on wet meadows: it sits a long while, puffing its throat, and
## takes a hop or two now and then; it hops off when the player comes near, and out of the view
## when it is sent away. Never onto ground it can't stand on (water). A hunting stork catches it
## (see Stork).

const SIT := &"sit"
const HOP := &"hop"
const FLEE := &"flee"

const HOP_LENGTH := 14.0
const HOP_SECONDS := 0.3
const HOP_HEIGHT := 6.0
const FLEE_HOP_LENGTH := 24.0
const FLEE_HOP_SECONDS := 0.3
const FLEE_HOP_HEIGHT := 8.0
## It stops fleeing when this many tiles beyond the distance it flees from.
const SAFE_EXTRA_TILES := 1.5

var _state_seconds := 1.0
var _hops_left := 0
var _is_dismissed := false


func _init() -> void:
	super(WildlifeRules.FROG)
	shadow_half_width = 3


func _ready() -> void:
	super()
	_sit()


func dismiss() -> void:
	_is_dismissed = true
	if _state != FLEE:
		_start_fleeing()


func _update(delta: float) -> void:
	if _state != FLEE and _reaction() == WildlifeRules.Reaction.FLEE:
		_start_fleeing()
	match _state:
		SIT:
			if _state_time >= _state_seconds:
				_hops_left = wildlife.rng.randi_range(1, 2)
				_hop_on()
		HOP:
			if _advance_hop(delta):
				_hop_on()
		FLEE:
			if not _is_hopping or _advance_hop(delta):
				_flee_hop()


func _sit() -> void:
	_enter(SIT)
	_state_seconds = wildlife.rng.randf_range(3.0, 9.0)
	# The throat puffs out and in, slowly.
	_play(SIT, 0.5)


## Hops again if it has hops left and ground to hop on; else sits.
func _hop_on() -> void:
	if _hops_left == 0:
		_sit()
		return
	_hops_left -= 1
	var direction := Vector2.from_angle(wildlife.rng.randf() * TAU)
	if _try_hop_around(direction, HOP_LENGTH, HOP_SECONDS, HOP_HEIGHT):
		_enter(HOP)
		_play(HOP, 2.0 / HOP_SECONDS)
	else:
		_sit()


func _start_fleeing() -> void:
	_enter(FLEE)
	_is_hopping = false
	_arc = 0.0
	_flee_hop()


## Hops on away from the player (or out of the view, if dismissed) until it is safe.
func _flee_hop() -> void:
	if _is_dismissed and _is_out_of_view():
		is_done = true
		return
	var safe_tiles: float = wildlife.rules.flee_tiles(kind) + SAFE_EXTRA_TILES
	if not _is_dismissed and _player_distance_tiles() > safe_tiles:
		_sit()
		return
	var away := _away_from_view_centre() if _is_dismissed else _away_from_player()
	if _try_hop_around(away, FLEE_HOP_LENGTH, FLEE_HOP_SECONDS, FLEE_HOP_HEIGHT):
		_play(HOP, 2.0 / FLEE_HOP_SECONDS)
	elif _is_dismissed:
		is_done = true
	else:
		_sit()
