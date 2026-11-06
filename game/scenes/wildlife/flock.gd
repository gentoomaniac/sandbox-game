class_name Flock
extends Animal
## A flock of three to six birds crossing the view high up. Their small shadows cross the
## ground below, which is how it reads at a glance: the shadows are drawn on a layer of the
## ground (see GroundShadows), the birds above everything.

## A flock is made of birds that look like the sparrows on the ground.
const BIRD_ANIMATION := &"fly"
const SPEED := 48.0
const FLIGHT_HEIGHT := 32.0
const WINGBEAT_PER_SECOND := 10.0
## The birds keep a V: this far apart along and across the way they fly, in pixels.
const SPACING := Vector2(5.0, 6.0)
## Gone once this far outside the view, having been inside it.
const LEAVE_MARGIN := 24.0
const MAX_SECONDS := 90.0

var _heading := Vector2.RIGHT
var _birds: Array[Sprite2D] = []
var _offsets := PackedVector2Array()
var _shadows: GroundShadows
var _has_entered_view := false


func _init() -> void:
	super(WildlifeRules.FLOCK, WildlifeRules.BIRD)
	shadow_half_width = 0


## Flies from `start` towards `goal`, with this many birds.
func set_course(start: Vector2, goal: Vector2, bird_count: int) -> void:
	position = start
	_heading = (goal - start).normalized()
	var side := _heading.rotated(PI / 2.0)
	for i in bird_count:
		# Leader first, the others in pairs behind it, to either side in turn.
		var rank := ceili(i / 2.0)
		var across := rank * (1 if i % 2 == 1 else -1)
		_offsets.append(-_heading * SPACING.x * rank + side * SPACING.y * across)


func _ready() -> void:
	super()
	_sprite.hide()
	z_index = 1
	_shadows = GroundShadows.new(_offsets.size())
	wildlife.ground.add_child(_shadows)
	for i in _offsets.size():
		var bird := WildlifeSprites.make_sprite(WildlifeRules.BIRD)
		bird.flip_h = _heading.x < 0.0
		add_child(bird)
		_birds.append(bird)


func _exit_tree() -> void:
	_shadows.queue_free()


func dismiss() -> void:
	# Already on its way across: nothing to do but let it finish.
	pass


func _update(delta: float) -> void:
	position += _heading * SPEED * delta
	var count := WildlifeSprites.frame_count(WildlifeRules.BIRD, BIRD_ANIMATION)
	for i in _birds.size():
		var bob := sin(_state_time * 3.0 + i) * 1.5
		var offset := _offsets[i]
		_birds[i].position = offset + Vector2(0.0, -FLIGHT_HEIGHT + bob)
		# Each bird beats its wings a little out of step with the others.
		var step := int(_state_time * WINGBEAT_PER_SECOND + i) % count
		_birds[i].frame = WildlifeSprites.frame_index(WildlifeRules.BIRD, BIRD_ANIMATION, step)
		_shadows.set_point(i, position + offset)
	var is_inside := not _is_out_of_view(LEAVE_MARGIN)
	_has_entered_view = _has_entered_view or is_inside
	if (_has_entered_view and not is_inside) or _state_time > MAX_SECONDS:
		is_done = true


## The frame of the base class is not used: every bird of the flock sets its own.
func _show_frame() -> void:
	pass
