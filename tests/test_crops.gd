extends CropCase
## How crops live through days: growth from how well a day met their needs, damage from bad
## days, death, healing and regrowth, on days made up for the test (and a few of the real weather).

const SEED := 7
const MID_SPRING := 15
const MIDSUMMER := 40
## The cool-weather and the warm-weather crops (see data/crops.cfg): each grows best in the
## season of its list.
const COOL_CROPS: Array[StringName] = [
	&"turnip", &"potato", &"carrot", &"cabbage", &"onion", &"peas", &"strawberries", &"flax", &"rye"
]
const WARM_CROPS: Array[StringName] = [&"beans", &"pumpkin", &"wheat", &"buckwheat"]


func test_every_crop_ripens_in_its_growth_needed_on_best_days() -> void:
	for crop_id in CropRules.default_rules().crop_ids():
		var crop := _crop(crop_id)
		var days_needed := ceili(3.0 * _need(crop, "growth_per_stage"))
		for day_number in days_needed - 1:
			_live(crop, _best_day(crop))
			assert_false(
				CropLife.is_ripe(crop), "%s ripe after %d days" % [crop_id, day_number + 1]
			)
		_live(crop, _best_day(crop))
		assert_true(CropLife.is_ripe(crop), "%s ripe after %d days" % [crop_id, days_needed])
		assert_eq(CropLife.damage(crop), 0.0, str(crop_id))


func test_a_crop_goes_through_its_stages_in_order() -> void:
	var crop := _crop()
	var stages: Array[int] = [CropLife.stage(crop)]
	for _i in 12:
		_live(crop, _best_day(crop))
		if CropLife.stage(crop) != stages[-1]:
			stages.append(CropLife.stage(crop))
	assert_eq(stages, [0, 1, 2, 3] as Array[int])


func test_a_crop_stops_at_ripe() -> void:
	var crop := _crop()
	_live(crop, _best_day(crop), 30)
	assert_eq(CropLife.stage(crop), 3)
	assert_eq(CropLife.growth(crop), 3.0 * _need(crop, "growth_per_stage"))


func test_a_poor_day_grows_in_proportion() -> void:
	var crop := _crop()
	var day := _best_day(crop)
	# Half way from the minimum to the best temperature.
	day.mean_temperature = (_need(crop, "temperature_min") + _need(crop, "temperature_best")) / 2.0
	_live_through_day(crop, day, _best_moisture(crop))
	assert_almost_eq(CropLife.growth(crop), 0.5, 0.0001)
	assert_eq(CropLife.damage(crop), 0.0, "a poor day is not a bad one")


func test_the_lowest_of_warmth_sun_and_moisture_counts() -> void:
	var crop := _crop()
	var day := _best_day(crop)
	day.sunlight_hours = _need(crop, "sunlight_best") / 4.0
	assert_almost_eq(CropLife.score(crop, day, _best_moisture(crop)), 0.25, 0.0001)
	day = _best_day(crop)
	assert_almost_eq(CropLife.score(crop, day, _best_moisture(crop) / 2.0), 0.5, 0.0001)


func test_a_day_too_hot_gives_no_growth_and_no_damage() -> void:
	var crop := _crop()
	var day := _best_day(crop)
	day.mean_temperature = _need(crop, "temperature_max") + 1.0
	_live(crop, day)
	assert_eq(CropLife.growth(crop), 0.0)
	assert_eq(CropLife.damage(crop), 0.0)


func test_each_cause_of_a_bad_day_damages_and_stops_growth() -> void:
	var causes := {}
	var drought := _best_day(_crop())
	var darkness := _best_day(_crop())
	darkness.sunlight_hours = 0.5
	var frost := _best_day(_crop())
	frost.min_temperature = -2.0
	var gale := _best_day(_crop())
	gale.max_wind_speed = 40.0
	causes[&"drought"] = [drought, 0.0]
	causes[&"darkness"] = [darkness, 0.6]
	causes[&"frost"] = [frost, 0.6]
	causes[&"wind"] = [gale, 0.6]
	for cause: StringName in causes:
		var crop := _crop()
		var day: WeatherDay = causes[cause][0]
		var moisture: float = causes[cause][1]
		assert_eq(CropLife.troubles(crop, day, moisture), [cause] as Array[StringName], str(cause))
		_live_through_day(crop, day, moisture)
		assert_almost_eq(
			CropLife.damage(crop), _need(crop, "damage_per_bad_day"), 0.00001, str(cause)
		)
		assert_eq(CropLife.growth(crop), 0.0, str(cause))


func test_a_crop_dies_after_enough_bad_days_and_shows_its_dead_stage() -> void:
	var crop := _crop()
	var drought := _best_day(crop)
	var days := ceili(1.0 / _need(crop, "damage_per_bad_day"))
	for _i in days - 1:
		_live_through_day(crop, drought, 0.0)
	assert_false(CropLife.is_dead(crop))
	assert_ne(CropLife.look(crop), CropRules.STAGES)
	assert_true(_live_through_day(crop, drought, 0.0), "its look changed")
	assert_true(CropLife.is_dead(crop))
	assert_eq(CropLife.damage(crop), 1.0)
	assert_eq(CropLife.look(crop), CropRules.STAGES, "the dead stage follows the growth stages")
	assert_false(CropLife.is_ripe(crop))
	_live(crop, _best_day(crop), 5)
	assert_true(CropLife.is_dead(crop), "the dead stay dead")
	assert_eq(CropLife.growth(crop), 0.0)


func test_a_ripe_crop_that_dies_is_not_ripe_any_more() -> void:
	var crop := _crop()
	crop.state["growth"] = 3.0 * _need(crop, "growth_per_stage")
	assert_true(CropLife.is_ripe(crop))
	crop.state["crop_damage"] = 1.0
	assert_false(CropLife.is_ripe(crop))


func test_good_days_heal_slowly_and_poor_ones_do_not() -> void:
	var crop := _crop()
	crop.state["crop_damage"] = 0.5
	_live(crop, _best_day(crop))
	assert_almost_eq(CropLife.damage(crop), 0.5 - _need(crop, "heal_per_good_day"), 0.0001)
	var poor := _best_day(crop)
	poor.sunlight_hours = _need(crop, "sunlight_best") * 0.3
	var damage_before := CropLife.damage(crop)
	_live(crop, poor)
	assert_eq(CropLife.damage(crop), damage_before)
	for _i in 100:
		crop.state["growth"] = 0.0  # Kept from ripening, which would end in withering.
		_live(crop, _best_day(crop))
	assert_eq(CropLife.damage(crop), 0.0, "never below none")


func test_beans_and_flax_die_in_a_gale_but_wheat_stands_it() -> void:
	var gale_speed := 10.0
	for crop_id: StringName in [&"beans", &"flax", &"wheat"]:
		var crop := _crop(crop_id)
		var day := _best_day(crop)
		day.max_wind_speed = gale_speed
		for _i in 4:
			_live_through_day(crop, day, _best_moisture(crop))
		assert_eq(CropLife.is_dead(crop), crop_id != &"wheat", str(crop_id))
	assert_lt(_need(_crop(&"beans"), "wind_max"), gale_speed)
	assert_gt(_need(_crop(&"wheat"), "wind_max"), gale_speed)


func test_warmth_loving_crops_suffer_a_cold_night_that_cool_crops_do_not() -> void:
	var chilly := WeatherDay.new()
	chilly.min_temperature = 4.0
	chilly.mean_temperature = 9.0
	chilly.sunlight_hours = 8.0
	assert_true(CropLife.troubles(_crop(&"beans"), chilly, 1.0).has(&"frost"))
	assert_true(CropLife.troubles(_crop(&"turnip"), chilly, 1.0).is_empty())


func test_only_peas_beans_and_strawberries_regrow() -> void:
	for crop_id in CropRules.default_rules().crop_ids():
		var regrows := crop_id in [&"peas", &"beans", &"strawberries"]
		assert_eq(CropLife.regrows(_crop(crop_id)), regrows, str(crop_id))


func test_a_regrowing_crop_goes_back_to_its_regrow_stage_and_ripens_again() -> void:
	for crop_id: StringName in [&"peas", &"strawberries"]:
		var crop := _crop(crop_id)
		crop.state["growth"] = 3.0 * _need(crop, "growth_per_stage")
		assert_true(CropLife.is_ripe(crop))
		CropLife.regrow(crop)
		assert_false(CropLife.is_ripe(crop), str(crop_id))
		assert_eq(CropLife.stage(crop), int(_need(crop, "regrow_stage")), str(crop_id))
		var days_left := ceili(
			(3.0 - _need(crop, "regrow_stage")) * _need(crop, "growth_per_stage")
		)
		_live(crop, _best_day(crop), days_left)
		assert_true(CropLife.is_ripe(crop), str(crop_id))


func _harvests(crop_id: StringName, count: int) -> Array[Dictionary]:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var crop := _crop(crop_id)
	var harvests: Array[Dictionary] = []
	for _i in count:
		harvests.append(CropLife.harvest_of(crop, rng))
	return harvests


func test_the_usual_count_is_the_most_common_and_one_more_or_less_come_at_their_chances() -> void:
	const HARVESTS := 4000
	for crop_id in CropRules.default_rules().crop_ids():
		var crop_type := _crop(crop_id).type_data()
		var usual: int = crop_type["yield"]
		var counts := {}
		for harvest in _harvests(crop_id, HARVESTS):
			var count: int = harvest[crop_type["produce"]]
			counts[count] = counts.get(count, 0) + 1
		for count: int in counts:
			assert_between(count, maxi(usual - 1, 1), usual + 1, str(crop_id))
			assert_gte(count, 1, str(crop_id))
		var poor: float = crop_type["poor_harvest_chance"] if usual > 1 else 0.0
		var good: float = crop_type["good_harvest_chance"]
		assert_almost_eq(counts.get(usual + 1, 0) / float(HARVESTS), good, 0.03, str(crop_id))
		assert_almost_eq(counts.get(usual - 1, 0) / float(HARVESTS), poor, 0.03, str(crop_id))
		assert_gt(counts[usual], counts.get(usual + 1, 0), str(crop_id))


func test_carrots_give_two_mostly_and_a_pumpkin_never_less_than_one() -> void:
	assert_eq(CropRules.default_rules().crop(&"carrot")["yield"], 2)
	for harvest in _harvests(&"pumpkin", 500):
		assert_gte(harvest["pumpkin"], 1)


func test_the_seed_comes_back_by_the_crops_seed_chance() -> void:
	for crop_id in CropRules.default_rules().crop_ids():
		var crop_type := _crop(crop_id).type_data()
		var with_seed := 0
		for harvest in _harvests(crop_id, 4000):
			with_seed += harvest.get(crop_type["seed"], 0)
		assert_almost_eq(with_seed / 4000.0, crop_type["seed_chance"], 0.04, str(crop_id))


func test_crops_planted_in_season_ripen_in_a_fortnight_or_so_under_the_real_weather() -> void:
	var weather := Weather.new(SEED)
	for crops_and_day in [[COOL_CROPS, MID_SPRING], [WARM_CROPS, MIDSUMMER]]:
		for crop_id: StringName in crops_and_day[0]:
			var crop := _crop(crop_id)
			var day_number: int = crops_and_day[1]
			# Watered every day, so that the soil is damp (a little under its best) all day.
			var moisture := _best_moisture(crop)
			while not CropLife.is_ripe(crop) and not CropLife.is_dead(crop):
				_live_through_day(crop, weather.day_summary(Vector2i.ZERO, day_number), moisture)
				day_number += 1
			var days: int = day_number - crops_and_day[1]
			assert_false(CropLife.is_dead(crop), "%s died" % crop_id)
			assert_between(days, 8, 20, "%s ripe after %d days" % [crop_id, days])


func test_a_day_summary_matches_the_hourly_weather() -> void:
	var weather := Weather.new(SEED)
	var summary := weather.day_summary(Vector2i.ZERO, 20)
	var coldest := INF
	var strongest := 0.0
	for hour in 24:
		var sample := weather.at(Vector2i.ZERO, 20, hour * GameClock.MINUTES_PER_HOUR)
		coldest = minf(coldest, sample.temperature)
		strongest = maxf(strongest, sample.wind_speed)
	assert_eq(summary.min_temperature, coldest)
	assert_eq(summary.max_wind_speed, strongest)
	assert_true(summary.min_temperature < summary.mean_temperature)
	assert_true(summary.mean_temperature < summary.max_temperature)
	assert_gt(summary.sunlight_hours, 0.0)
	assert_same(weather.day_summary(Vector2i(5, 5), 20), summary, "cached for the region")
	assert_ne(weather.day_summary(Vector2i.ZERO, 21), summary)
