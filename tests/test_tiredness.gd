extends EnergyCase
## The signs of tiredness: how much sweat an action throws, and when the late-hour thought
## bubble shows. The test rules put the levels at 30 and 12, the late warnings at 00:15 and 00:45
## (see EnergyCase).

const LEVELS := TirednessSigns.Level
const KINDS := HitEffect.Kind
const DAY := GameClock.MINUTES_PER_DAY

var _signs: TirednessSigns


func before_each() -> void:
	super.before_each()
	_signs = TirednessSigns.new(_state.energy_rules, _state.cheats)


func test_the_level_is_found_from_the_energy() -> void:
	assert_eq(_signs.level_of(31.0), LEVELS.RESTED)
	assert_eq(_signs.level_of(30.0), LEVELS.TIRED)
	assert_eq(_signs.level_of(12.5), LEVELS.TIRED)
	assert_eq(_signs.level_of(12.0), LEVELS.EXHAUSTED)
	assert_eq(_signs.level_of(0.0), LEVELS.EXHAUSTED)


## Runs the clock from `from_minute` to `to_minute` one minute at a time and lists the minutes
## at which the late bubble showed.
func _bubbles_between(from_minute: int, to_minute: int, is_awake := true) -> Array[int]:
	var shown: Array[int] = []
	for minute in range(from_minute, to_minute + 1):
		if _signs.late_bubble_for(minute, is_awake) == &"zzz":
			shown.append(minute)
	return shown


func test_the_late_bubble_shows_at_each_warning_time_once() -> void:
	# The test rules warn at 00:15 and 00:45; day 1 begins at minute 0.
	assert_eq(_bubbles_between(DAY - 60, DAY + 120), [DAY + 15, DAY + 45] as Array[int])


func test_the_late_bubble_comes_every_night() -> void:
	assert_eq(_bubbles_between(DAY + 100, 3 * DAY), [2 * DAY + 15, 2 * DAY + 45] as Array[int])


func test_no_late_bubble_while_asleep_or_collapsing() -> void:
	assert_eq(_bubbles_between(DAY - 60, DAY + 120, false), [] as Array[int])


func test_no_late_bubble_for_the_time_a_jump_passes() -> void:
	assert_eq(_signs.late_bubble_for(DAY - 60, true), &"")
	assert_eq(_signs.late_bubble_for(DAY + 60, true), &"", "a skip over 00:15 and 00:45")
	assert_eq(_signs.late_bubble_for(2 * DAY + 400, true), &"", "a night's sleep")


func test_waking_up_after_a_pause_does_not_warn_for_the_time_in_between() -> void:
	_signs.late_bubble_for(DAY - 5, true)
	assert_eq(_signs.late_bubble_for(DAY + 20, false), &"")
	assert_eq(_signs.late_bubble_for(DAY + 21, true), &"", "the first minute awake only starts")
	assert_eq(_signs.late_bubble_for(DAY + 22, true), &"")


func test_every_use_that_costs_energy_makes_a_tired_player_sweat() -> void:
	for use in ToolUse.COST_KINDS:
		assert_eq(_signs.sweat_for(use, 25.0), KINDS.SWEAT, "use %s" % use)
		assert_eq(_signs.sweat_for(use, 8.0), KINDS.SWEAT_HEAVY, "use %s" % use)


func test_a_use_that_costs_nothing_makes_no_sweat() -> void:
	for use in [ToolUse.Use.NOTHING, ToolUse.Use.NEEDS_BETTER_TOOL, ToolUse.Use.OUT_OF_REACH]:
		assert_eq(_signs.sweat_for(use, 5.0), KINDS.NONE)


func test_a_rested_player_does_not_sweat() -> void:
	assert_eq(_signs.sweat_for(ToolUse.Use.HIT, 31.0), KINDS.NONE)


func test_sweat_is_one_drop_when_tired_and_two_or_three_when_exhausted() -> void:
	assert_eq(HitParticles.SPECS[KINDS.SWEAT]["count"], Vector2i(1, 1))
	assert_eq(HitParticles.SPECS[KINDS.SWEAT_HEAVY]["count"], Vector2i(2, 3))


func test_sweat_drops_are_tiny_and_short_lived() -> void:
	for kind in [KINDS.SWEAT, KINDS.SWEAT_HEAVY]:
		for size: Vector2 in HitParticles.SPECS[kind]["sizes"]:
			assert_true(size.x <= 4 and size.y <= 4, "drop size %s" % size)
		assert_lt(HitParticles.SPECS[kind]["life"], 1.0)


func test_the_energy_a_use_leaves_decides_the_sweat() -> void:
	_state.player.energy = 31.0
	_hold(ItemTypes.RUSTY_IRON_HOE)
	var use := _state.use_facing_tile()
	assert_eq(use, ToolUse.Use.TILL)
	assert_eq(_state.player.energy, 27.0)
	assert_eq(_signs.sweat_for(use, _state.player.energy), KINDS.SWEAT)


func test_the_bubble_pops_up_in_whole_pixels_and_fades_at_the_end() -> void:
	assert_eq(ThoughtBubble.drop_at(0.0), ThoughtBubble.POP_DROP)
	assert_eq(ThoughtBubble.drop_at(ThoughtBubble.POP_SECONDS), 0)
	assert_eq(ThoughtBubble.drop_at(1.0), 0)
	assert_eq(ThoughtBubble.alpha_at(1.0), 1.0)
	assert_between(ThoughtBubble.alpha_at(1.8), 0.1, 0.9)
	assert_eq(ThoughtBubble.alpha_at(ThoughtBubble.LIFE_SECONDS), 0.0)


func test_every_bubble_picture_is_there() -> void:
	assert_not_null(load(ThoughtBubble.PICTURE_PATH % TirednessSigns.BUBBLE_ICON))


## The topmost opaque row, counted up from the feet, over every frame of what the player wears.
func _head_top_in_sheets(appearance: Appearance) -> int:
	var top := 0
	for layer in appearance.layers:
		var image := (load(Appearance.sheet_path(layer)) as Texture2D).get_image()
		for frame_y in PlayerView.FACING_ROWS.size():
			for y in PlayerView.FRAME_HEIGHT:
				var row := Rect2i(0, frame_y * PlayerView.FRAME_HEIGHT + y, image.get_width(), 1)
				if not image.get_region(row).is_invisible():
					top = maxi(top, PlayerView.FRAME_HEIGHT - y)
					break
	return -top


func test_the_bubble_sits_just_above_the_head_bare_or_with_a_hat() -> void:
	var appearance := Appearance.new()
	var gap := TirednessView.BUBBLE_GAP
	assert_eq(
		TirednessView.bubble_origin(appearance).y, float(_head_top_in_sheets(appearance) - gap)
	)
	appearance.wear(Appearance.HEAD, "straw_hat")
	assert_eq(
		TirednessView.bubble_origin(appearance).y, float(_head_top_in_sheets(appearance) - gap)
	)
	appearance.wear(Appearance.HAIR, "1")
	assert_eq(
		TirednessView.bubble_origin(appearance).y, float(_head_top_in_sheets(appearance) - gap)
	)
	appearance.wear(Appearance.HEAD, "knitted_cap")
	assert_eq(
		TirednessView.bubble_origin(appearance).y, float(_head_top_in_sheets(appearance) - gap)
	)


func test_sweat_drops_are_thrown_sideways_and_have_a_dark_pixel_to_show() -> void:
	for kind in [KINDS.SWEAT, KINDS.SWEAT_HEAVY]:
		var spec: Dictionary = HitParticles.SPECS[kind]
		assert_true(spec["is_outward"], "thrown away from the head")
		assert_true(spec["is_shaded"], "darker last pixel")
		assert_true(spec["spread"].x > 3, "starts beside the head")
		for size: Vector2 in spec["sizes"]:
			assert_true(size.x * size.y >= 2, "drop size %s" % size)


func test_sweat_flies_off_to_both_sides_and_then_falls() -> void:
	var particles: HitParticles = autofree(HitParticles.new())
	var sides := {}
	for _i in 30:
		particles.emit(KINDS.SWEAT, Vector2.ZERO)
	for particle in particles._particles:
		sides[signf(particle.velocity.x)] = true
		assert_eq(signf(particle.velocity.x), signf(particle.start.x))
		assert_gt(particle.position_now().y, particle.start.y - 100)
		particle.age = particle.life * 0.9
		assert_gt(particle.position_now().y, particle.start.y, "has fallen below where it began")
	assert_eq(sides.size(), 2)


func test_heavy_sweat_flies_off_both_sides_of_the_head() -> void:
	for _attempt in 20:
		var particles: HitParticles = autofree(HitParticles.new())
		particles.emit(KINDS.SWEAT_HEAVY, Vector2.ZERO)
		var directions := particles._particles.map(
			func(p: HitParticles.Particle) -> float: return signf(p.velocity.x)
		)
		assert_true(directions.has(1.0) and directions.has(-1.0))
