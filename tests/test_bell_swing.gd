extends GutTest
## The bell swinging in its frame: the pendulum (BellSwing) and the bell sprite that BuildingViews
## lays over the frame's picture, in both arts.

const STEP := 1.0 / 60.0

var _entities: Node2D
var _views: BuildingViews


func before_each() -> void:
	_entities = Node2D.new()
	add_child_autofree(_entities)
	_views = BuildingViews.new(_entities)
	add_child_autofree(_views)
	var blend := SeasonBlend.new(1)
	_views.set_looks(blend, blend.conditions(0))


func after_each() -> void:
	ArtSet.is_classic = false


## Runs the swing for `seconds` and returns the frame shown after each step.
func _frames_over(swing: BellSwing, seconds: float) -> Array[int]:
	var frames: Array[int] = []
	for step in roundi(seconds / STEP):
		swing.step(STEP)
		frames.append(swing.frame())
	return frames


func test_a_bell_at_rest_hangs_straight() -> void:
	var swing := BellSwing.new()
	assert_eq(swing.frame(), BellSwing.MIDDLE)
	swing.step(1.0)
	assert_eq(swing.frame(), BellSwing.MIDDLE)
	assert_false(swing.is_swinging())


func test_a_ring_swings_it_widely_to_both_sides_and_it_comes_to_rest() -> void:
	var swing := BellSwing.new()
	swing.ring()
	var frames := _frames_over(swing, 2.0)
	assert_eq(frames.max(), BellSwing.FRAMES - 1)
	assert_lte(frames.min(), 2)
	_frames_over(swing, 5.0)
	assert_false(swing.is_swinging())
	assert_eq(swing.frame(), BellSwing.MIDDLE)


func test_ringing_while_it_swings_does_not_make_the_bell_jump_and_swings_it_fully_again() -> void:
	var swing := BellSwing.new()
	swing.ring()
	_frames_over(swing, 2.0)
	var angle_before := swing.angle
	swing.ring()
	assert_eq(swing.angle, angle_before, "the bell stays where it is")
	var frames := _frames_over(swing, 2.0)
	assert_eq(frames.max(), BellSwing.FRAMES - 1)
	assert_lte(frames.min(), 2)


func test_a_bell_frame_has_a_bell_with_all_the_frames_of_the_swing_in_both_arts() -> void:
	var frame := Building.new(BuildingTypes.BELL_FRAME, Vector2i(3, 3))
	_views.add(frame)
	var sprite: Sprite2D = _entities.get_child(0)
	assert_eq(sprite.get_child_count(), 1)
	var bell: Sprite2D = sprite.get_child(0)
	assert_eq(bell.hframes, BellSwing.FRAMES)
	var cell_size := bell.texture.get_size() / Vector2(BellSwing.FRAMES, 1)
	for is_classic in [false, true]:
		ArtSet.is_classic = is_classic
		_views.show_art_set()
		assert_ne(bell.texture, null)
		assert_eq(
			bell.texture.get_size() / Vector2(BellSwing.FRAMES, 1), cell_size, str(is_classic)
		)
	assert_true(bell.use_parent_material, "it fades with the frame")


func test_other_buildings_have_no_bell() -> void:
	_views.add(Building.new(BuildingTypes.SHACK, Vector2i(3, 3)))
	assert_eq(_entities.get_child(0).get_child_count(), 0)


func test_ringing_swings_the_bell_sprite_and_it_ends_straight() -> void:
	var frame := Building.new(BuildingTypes.BELL_FRAME, Vector2i(3, 3))
	_views.add(frame)
	var bell: Sprite2D = _entities.get_child(0).get_child(0)
	_views.swing_bell(frame)
	_views._process(0.2)
	assert_ne(bell.frame, BellSwing.MIDDLE)
	for step in 300:
		_views._process(0.02)
	assert_eq(bell.frame, BellSwing.MIDDLE)
