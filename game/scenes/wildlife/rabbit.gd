class_name Rabbit
extends Animal
## A rabbit on grassland: sits, nibbles and hops about; flees from the player in zigzag hops,
## and never hops onto ground it can't stand on (water).

const SIT := &"sit"
const NIBBLE := &"nibble"
const HOP := &"hop"
const FLEE := &"flee"

const HOP_LENGTH := 18.0
const HOP_SECONDS := 0.3
const HOP_HEIGHT := 6.0
const FLEE_HOP_LENGTH := 34.0
const FLEE_HOP_SECONDS := 0.26
const FLEE_HOP_HEIGHT := 8.0
## Each flee hop turns this far off the straight way from the player, to the other side
## than the one before.
const ZIGZAG := 0.7
## It stops fleeing when this many tiles beyond the distance it flees from.
const SAFE_EXTRA_TILES := 3.0

var _state_seconds := 1.0
var _hops_left := 0
var _flee_side := 1.0
var _is_dismissed := false


func _init() -> void:
	super(WildlifeRules.RABBIT)
	shadow_half_width = 4


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
		SIT, NIBBLE:
			if _state_time >= _state_seconds:
				_choose_next()
		HOP:
			if _advance_hop(delta):
				_hop_on()
		FLEE:
			_flee(delta)


func _choose_next() -> void:
	var roll := wildlife.rng.randf()
	if roll < 0.4:
		_enter(NIBBLE)
		_state_seconds = wildlife.rng.randf_range(1.5, 3.5)
		_play(NIBBLE, 3.0)
	elif roll < 0.7:
		_sit()
	else:
		_hops_left = wildlife.rng.randi_range(1, 3)
		_hop_on()


func _sit() -> void:
	_enter(SIT)
	_state_seconds = wildlife.rng.randf_range(1.0, 3.0)
	_play(SIT, 1.5)


## Hops again if it has hops left and ground to hop on; else sits.
func _hop_on() -> void:
	if _hops_left == 0:
		_sit()
		return
	_hops_left -= 1
	var direction := Vector2.from_angle(wildlife.rng.randf() * TAU)
	if _try_hop_around(direction, HOP_LENGTH, HOP_SECONDS, HOP_HEIGHT):
		_enter(HOP)
		_play(HOP, 3.0 / HOP_SECONDS)
	else:
		_sit()


func _start_fleeing() -> void:
	_enter(FLEE)
	_is_hopping = false
	_arc = 0.0
	_flee_side = 1.0 if wildlife.rng.randf() < 0.5 else -1.0
	_flee_hop()


func _flee(delta: float) -> void:
	if _is_hopping:
		if not _advance_hop(delta):
			return
		if _is_safe():
			is_done = _is_dismissed
			_sit()
			return
	_flee_hop()


## Hops one zigzag step away from the player (or out of the view, if dismissed).
func _flee_hop() -> void:
	var away := _away_from_view_centre() if _is_dismissed else _away_from_player()
	_flee_side = -_flee_side
	if _try_hop_around(
		away.rotated(ZIGZAG * _flee_side),
		FLEE_HOP_LENGTH,
		FLEE_HOP_SECONDS,
		FLEE_HOP_HEIGHT,
		ZIGZAG
	):
		_play(HOP, 3.0 / FLEE_HOP_SECONDS)
	elif _is_dismissed:
		is_done = true
	else:
		_sit()


func _is_safe() -> bool:
	if _is_dismissed:
		return _is_out_of_view()
	var flee_tiles: float = wildlife.rules.flee_tiles(kind)
	return _player_distance_tiles() > flee_tiles + SAFE_EXTRA_TILES
