class_name Animal
extends Node2D
## What every animal has: a sprite standing at its position (its feet), a contact shadow, the
## frames of the action it plays, a state machine (each kind decides what its states are in
## `_update`) and a hop. The WildlifeView creates animals, and takes them away once they are
## `is_done` or far from the view. Animals stand in the y-sorted `entities` node, so the
## player and the objects pass in front of or behind them; those that fly are drawn above.

## The animal entered a state (see each kind's constants).
signal state_entered(state: StringName)

const SHADOW_COLOR := Color(0.0, 0.0, 0.0, 0.2)

## Set by the WildlifeView that made it.
var wildlife: WildlifeView
## Made by the debug flag or the console: the view keeps it until it is far away.
var is_pinned := false
## Gone for good (flown off, hidden behind a tree): the view takes it away.
var is_done := false
var kind: StringName
## Half the width of the contact shadow in pixels; 0 for none.
var shadow_half_width := 3
var _sprite: Sprite2D
var _sheet_kind: StringName
var _action := &""
var _action_time := 0.0
var _frames_per_second := 6.0
## Whether frames play 0, 1, 2, 1, 0 ... instead of 0, 1, 2, 0 ...
var _is_ping_pong := false
var _facing := 1.0
var _state := &""
var _state_time := 0.0
## Pixels the sprite is lifted off the ground (flying) and the jump of a hop.
var _lift := 0.0
var _arc := 0.0
var _is_hopping := false
var _hop_from := Vector2.ZERO
var _hop_to := Vector2.ZERO
var _hop_seconds := 1.0
var _hop_height := 0.0
var _hop_time := 0.0


## `sheet_kind` is the kind whose pictures it shows, if another than its own.
func _init(animal_kind: StringName, sheet_kind := &"") -> void:
	kind = animal_kind
	_sheet_kind = animal_kind if sheet_kind == &"" else sheet_kind


func _ready() -> void:
	_sprite = WildlifeSprites.make_sprite(_sheet_kind)
	add_child(_sprite)


func _process(delta: float) -> void:
	_state_time += delta
	_action_time += delta
	_update(delta)
	_show_frame()


func _draw() -> void:
	if shadow_half_width == 0:
		return
	# A flat ellipse of three rows, a little in front of the feet.
	for row in 3:
		var half := shadow_half_width - (1 if row != 1 else 0)
		draw_rect(Rect2(-half, row - 1, half * 2, 1), SHADOW_COLOR)


## Leaves for good: runs or flies off, whatever it was doing. Each kind knows how.
func dismiss() -> void:
	pass


## Does what the state calls for; kinds override it.
func _update(_delta: float) -> void:
	pass


func _enter(state: StringName) -> void:
	_state = state
	_state_time = 0.0
	state_entered.emit(state)


## Starts playing an action's frames from the first, unless it is playing already.
func _play(action: StringName, frames_per_second: float) -> void:
	_frames_per_second = frames_per_second
	if action == _action:
		return
	_action = action
	_action_time = 0.0


## Turns to look in the direction of x (to the right is how the sheets are drawn).
func _face(direction_x: float) -> void:
	if absf(direction_x) < 0.01:
		return
	_facing = signf(direction_x)
	_sprite.flip_h = _facing < 0.0


func _show_frame() -> void:
	var count := WildlifeSprites.frame_count(_sheet_kind, _action)
	var step := int(_action_time * _frames_per_second)
	var column := step % count
	if _is_ping_pong and count > 1:
		var cycle := (count - 1) * 2
		column = step % cycle
		column = column if column < count else cycle - column
	_sprite.frame = WildlifeSprites.frame_index(_sheet_kind, _action, column)
	_sprite.position.y = -(_lift + _arc)


## How far the player is, in tiles; far away if the animals are told to take no notice.
func _player_distance_tiles() -> float:
	if wildlife.is_player_ignored:
		return INF
	return position.distance_to(wildlife.world_view.player_feet) / WildlifeRules.TILE_SIZE


func _reaction() -> WildlifeRules.Reaction:
	return wildlife.rules.reaction(kind, _player_distance_tiles())


## The direction away from the player: any direction if the animal is on top of them.
func _away_from_player() -> Vector2:
	var away := position - wildlife.world_view.player_feet
	if away.length() < 1.0:
		return Vector2.from_angle(wildlife.rng.randf() * TAU)
	return away.normalized()


## The direction away from the middle of the view, to leave it.
func _away_from_view_centre() -> Vector2:
	var away := position - wildlife.view_rect().get_center()
	if away.length() < 1.0:
		return Vector2.from_angle(wildlife.rng.randf() * TAU)
	return away.normalized()


## Whether the animal is outside the view (a margin of `margin` pixels counted as inside).
func _is_out_of_view(margin := 0.0) -> bool:
	return not wildlife.view_rect().grow(margin).has_point(position)


## Takes a step in a direction if the ground there can be stood on; returns whether it did.
func _walk(direction: Vector2, speed: float, delta: float) -> bool:
	var next := position + direction * speed * delta
	if not wildlife.can_stand(next):
		return false
	position = next
	_face(direction.x)
	return true


## Starts a hop of `length` pixels in a direction, if the ground there can be stood on.
func _try_hop(direction: Vector2, length: float, seconds: float, height: float) -> bool:
	var target := position + direction * length
	if not wildlife.can_stand(target):
		return false
	_is_hopping = true
	_hop_from = position
	_hop_to = target
	_hop_seconds = seconds
	_hop_height = height
	_hop_time = 0.0
	_action_time = 0.0
	_face(direction.x)
	return true


## Hops on from the last call of `_try_hop`; returns true on the frame it lands.
func _advance_hop(delta: float) -> bool:
	_hop_time += delta
	var progress := minf(_hop_time / _hop_seconds, 1.0)
	position = _hop_from.lerp(_hop_to, progress)
	_arc = sin(progress * PI) * _hop_height
	if progress < 1.0:
		return false
	_is_hopping = false
	_arc = 0.0
	return true


## Starts a hop in the first direction that works: the given one, then turned by more and
## more, to either side. Returns whether any did.
func _try_hop_around(
	direction: Vector2, length: float, seconds: float, height: float, turn := 0.7
) -> bool:
	for steps in [0, 1, -1, 2, -2, 3, -3]:
		if _try_hop(direction.rotated(steps * turn), length, seconds, height):
			return true
	return false
