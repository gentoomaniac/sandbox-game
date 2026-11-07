class_name Flock
extends Animal
## Birds crossing the view high up in a V: a flock of three to six sparrows (kind FLOCK), or a
## skein of greylag geese with slow wingbeats (kind FLYING_GEESE). Their small shadows cross the
## ground below, which is how it reads at a glance: the shadows are drawn on a layer of the
## ground (see GroundShadows), the birds above everything.

## Per kind: the sheet its birds show, how many there are, their speed and height in pixels,
## their wingbeat in frames per second (`ping_pong`: the wings go up, level, down and back), how
## far apart they keep in the V along and across the way they fly, and half the width of their
## shadows.
const BIRDS := {
	WildlifeRules.FLOCK:
	{
		"sheet": WildlifeRules.BIRD,
		"count": Vector2i(3, 6),
		"speed": 48.0,
		"height": 32.0,
		"wingbeat": 10.0,
		"ping_pong": false,
		"spacing": Vector2(5.0, 6.0),
		"shadow": 2,
	},
	WildlifeRules.FLYING_GEESE:
	{
		"sheet": GroundFlock.FLOCKS[WildlifeRules.GEESE]["sheet"],
		"count": Vector2i(7, 13),
		"speed": 26.0,
		"height": 56.0,
		"wingbeat": 5.0,
		"ping_pong": true,
		"spacing": Vector2(14.0, 12.0),
		"shadow": 4,
	},
}
const ANIMATION := &"fly"
## Gone once this far outside the view, having been inside it, and beyond its height and the
## length of its V, so that no bird of it is still seen.
const LEAVE_MARGIN := 24.0
const MAX_SECONDS := 90.0

var _birds_of_kind: Dictionary
var _heading := Vector2.RIGHT
var _birds: Array[Sprite2D] = []
var _offsets := PackedVector2Array()
## The sprite frames of a wingbeat, looked up once.
var _wingbeat := PackedInt32Array()
var _shadows: GroundShadows
var _leave_margin := LEAVE_MARGIN
var _has_entered_view := false


func _init(flock_kind: StringName) -> void:
	super(flock_kind, BIRDS[flock_kind]["sheet"])
	_birds_of_kind = BIRDS[flock_kind]
	shadow_half_width = 0


## Where the birds of a V fly, from the leader: the others in pairs behind it, to either side in
## turn, `spacing` apart along and across `heading`.
static func v_offsets(heading: Vector2, count: int, spacing: Vector2) -> PackedVector2Array:
	var side := heading.rotated(PI / 2.0)
	var offsets := PackedVector2Array()
	for i in count:
		var rank := ceili(i / 2.0)
		var across := rank * (1 if i % 2 == 1 else -1)
		offsets.append(-heading * spacing.x * rank + side * spacing.y * across)
	return offsets


## How many birds a flock of a kind has, drawn with `rng`.
static func bird_count(flock_kind: StringName, rng: RandomNumberGenerator) -> int:
	var count: Vector2i = BIRDS[flock_kind]["count"]
	return rng.randi_range(count.x, count.y)


## Flies from `start` towards `goal`, with this many birds.
func set_course(start: Vector2, goal: Vector2, count: int) -> void:
	position = start
	_heading = (goal - start).normalized()
	_offsets = v_offsets(_heading, count, _birds_of_kind["spacing"])
	var v_length: float = _birds_of_kind["spacing"].x * ceili(count / 2.0)
	_leave_margin = LEAVE_MARGIN + _birds_of_kind["height"] + v_length


func _ready() -> void:
	super()
	_sprite.hide()
	z_index = 1
	_shadows = GroundShadows.new(_offsets.size(), _birds_of_kind["shadow"])
	wildlife.ground.add_child(_shadows)
	var columns := WildlifeSprites.frame_count(_sheet_kind, ANIMATION)
	for column in columns:
		_wingbeat.append(WildlifeSprites.frame_index(_sheet_kind, ANIMATION, column))
	if _birds_of_kind["ping_pong"]:
		for column in range(columns - 2, 0, -1):
			_wingbeat.append(_wingbeat[column])
	for i in _offsets.size():
		var bird := WildlifeSprites.make_sprite(_sheet_kind)
		bird.flip_h = _heading.x < 0.0
		add_child(bird)
		_birds.append(bird)


func _exit_tree() -> void:
	_shadows.queue_free()


func dismiss() -> void:
	# Already on its way across: nothing to do but let it finish.
	pass


func _update(delta: float) -> void:
	position += _heading * _birds_of_kind["speed"] * delta
	var height: float = _birds_of_kind["height"]
	var wingbeat: float = _birds_of_kind["wingbeat"]
	for i in _birds.size():
		var bob := sin(_state_time * 3.0 + i) * 1.5
		var offset := _offsets[i]
		_birds[i].position = offset + Vector2(0.0, -height + bob)
		# Each bird beats its wings a little out of step with the others.
		_birds[i].frame = _wingbeat[int(_state_time * wingbeat + i) % _wingbeat.size()]
		_shadows.set_point(i, position + offset)
	var is_inside := not _is_out_of_view(_leave_margin)
	_has_entered_view = _has_entered_view or is_inside
	if (_has_entered_view and not is_inside) or _state_time > MAX_SECONDS:
		is_done = true


## The frame of the base class is not used: every bird of the flock sets its own.
func _show_frame() -> void:
	pass
