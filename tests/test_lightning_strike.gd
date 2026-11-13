extends GutTest
## A strike of lightning: the thunder is later, quieter and duller and the flash fainter the
## farther it is; far strikes are the common ones and a close one is rare.

var _rules := WeatherRules.default_rules()
var _rng := RandomNumberGenerator.new()


func before_each() -> void:
	_rng.seed = 214


func _strike(distance_km: float) -> LightningStrike:
	return LightningStrike.new(distance_km, _rules)


func test_the_thunder_comes_later_the_farther_the_strike() -> void:
	assert_lt(_strike(0.2).delay_seconds(), _strike(2.0).delay_seconds())
	assert_lt(_strike(2.0).delay_seconds(), _strike(10.0).delay_seconds())
	assert_almost_eq(_strike(1.0).delay_seconds(), _rules.value("strike", "seconds_per_km"), 0.001)


func test_the_close_crack_comes_almost_with_the_flash() -> void:
	assert_lt(_strike(_rules.value("strike", "min_km")).delay_seconds(), 0.5)


func test_the_thunder_is_quieter_and_duller_the_farther_the_strike() -> void:
	assert_gt(_strike(0.2).level(), _strike(2.0).level())
	assert_gt(_strike(2.0).level(), _strike(10.0).level())
	assert_gt(_strike(0.2).cutoff_hz(), _strike(2.0).cutoff_hz())
	assert_gt(_strike(2.0).cutoff_hz(), _strike(10.0).cutoff_hz())
	assert_lte(_strike(0.0).level(), 1.0)


func test_the_flash_is_fainter_and_slower_the_farther_the_strike() -> void:
	assert_gt(_strike(0.2).flash_peak(), _strike(2.0).flash_peak())
	assert_gt(_strike(2.0).flash_peak(), _strike(10.0).flash_peak())
	assert_lt(_strike(0.2).flash_fade_seconds(), _strike(10.0).flash_fade_seconds())


func test_the_variety_follows_the_band_of_the_distance() -> void:
	assert_eq(_strike(0.3).event(), LightningStrike.CLOSE)
	assert_eq(_strike(2.0).event(), LightningStrike.MID)
	assert_eq(_strike(8.0).event(), LightningStrike.FAR)


func test_drawn_strikes_stay_in_range_and_far_ones_are_the_most_common() -> void:
	var counts := {
		LightningStrike.CLOSE: 0,
		LightningStrike.MID: 0,
		LightningStrike.FAR: 0,
		LightningStrike.CRAWL: 0
	}
	for _i in 1000:
		var strike := LightningStrike.draw(_rng, _rules)
		assert_between(
			strike.distance_km,
			_rules.value("strike", "min_km"),
			_rules.value("strike", "far_to_km")
		)
		counts[strike.event()] += 1
	assert_gt(counts[LightningStrike.FAR], counts[LightningStrike.MID])
	assert_gt(counts[LightningStrike.MID], counts[LightningStrike.CLOSE])


func test_a_close_strike_is_rare() -> void:
	var close := 0
	for _i in 1000:
		if LightningStrike.draw(_rng, _rules).event() == LightningStrike.CLOSE:
			close += 1
	assert_gt(close, 0, "it does happen")
	assert_lt(close, 100, "under one in ten")


func _crawler(distance_km := 3.0, seed_of_shape := 222) -> LightningStrike:
	return LightningStrike.new(distance_km, _rules, true, seed_of_shape)


func test_a_crawler_has_its_own_thunder() -> void:
	assert_eq(_crawler().event(), LightningStrike.CRAWL)
	assert_eq(_strike(3.0).event(), LightningStrike.MID)


func test_about_one_strike_in_six_is_a_crawler_as_far_as_a_mid_or_far_one() -> void:
	var crawlers := 0
	for _i in 3000:
		var strike := LightningStrike.draw(_rng, _rules)
		if not strike.is_crawl:
			continue
		crawlers += 1
		assert_between(
			strike.distance_km,
			_rules.value("strike", "close_to_km"),
			_rules.value("strike", "far_to_km")
		)
	assert_between(crawlers, 400, 600, "about 500 of 3000")


func test_the_flash_of_a_crawler_is_pulses_that_travel_one_way_across_the_sky() -> void:
	var pulses := _crawler().crawl_pulses()
	assert_eq(pulses.size(), int(_rules.value("strike", "crawl_pulses")))
	var direction := signf(pulses[-1].y - pulses[0].y)
	assert_ne(direction, 0.0)
	for index in pulses.size():
		assert_between(pulses[index].y, 0.0, 1.0)
		assert_between(pulses[index].z, 0.0, 1.0)
		assert_gt(pulses[index].z, 0.0)
		if index > 0:
			assert_gt(pulses[index].x, pulses[index - 1].x, "later")
			assert_eq(signf(pulses[index].y - pulses[index - 1].y), direction, "same way")
	assert_lt(pulses[-1].x, _rules.value("strike", "crawl_seconds"))


func test_the_flicker_is_the_same_for_a_seed_and_differs_between_seeds() -> void:
	assert_eq(_crawler(3.0, 5).crawl_pulses(), _crawler(3.0, 5).crawl_pulses())
	assert_ne(_crawler(3.0, 5).crawl_pulses(), _crawler(3.0, 6).crawl_pulses())


func test_other_strikes_do_not_flicker() -> void:
	assert_eq(_strike(3.0).crawl_pulses().size(), 0)
