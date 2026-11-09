extends WildlifeCase
## The fireflies on screen: they drift about and blink, with a light that follows the blinks.

const SECONDS_OF_BLINKS := 12.0


func _spawn_firefly() -> Firefly:
	_wildlife.place(WildlifeRules.FIREFLY, VIEW_CENTRE)
	return _animals_of(Firefly)[0]


func test_a_firefly_blinks_between_dark_and_bright() -> void:
	var firefly := _spawn_firefly()
	var darkest := 1.0
	var brightest := 0.0
	for _i in roundi(SECONDS_OF_BLINKS / STEP):
		firefly._process(STEP)
		darkest = minf(darkest, firefly.glow)
		brightest = maxf(brightest, firefly.glow)
	assert_eq(darkest, 0.0, "it goes dark between flashes")
	assert_gt(brightest, 0.9, "and flashes up")


func test_the_light_follows_the_glow_and_shines_only_as_the_world_lights_do() -> void:
	var firefly := _spawn_firefly()
	_wildlife.world_view.set_light_strength(1.0)
	for _i in roundi(SECONDS_OF_BLINKS / STEP):
		firefly._process(STEP)
		assert_almost_eq(firefly._light.energy, firefly.glow * Firefly.LIGHT_ENERGY, 0.001)
	_wildlife.world_view.set_light_strength(0.0)
	firefly._process(STEP)
	assert_false(firefly._light.visible, "no glow in daylight")


func test_a_firefly_drifts_about_slowly() -> void:
	var firefly := _spawn_firefly()
	_run(firefly, 5.0)
	var moved := firefly.position.distance_to(VIEW_CENTRE)
	assert_between(moved, 5.0, 5.0 * Firefly.SPEED + 1.0)


func test_a_sent_away_firefly_fades_out_and_is_done() -> void:
	var firefly := _spawn_firefly()
	firefly.dismiss()
	_run(firefly, Firefly.FADE_SECONDS / 2.0)
	assert_false(firefly.is_done)
	_run(firefly, Firefly.FADE_SECONDS)
	assert_true(firefly.is_done)
