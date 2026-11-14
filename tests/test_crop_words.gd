extends CropCase
## The plain words crops tell the player: what the seeds' crops like (in the seed tooltips) and how
## a crop is doing (in the hover box).

## Per crop: the weather it likes, the water it needs, the wind it stands and its days.
const CROP_LIKES := {
	&"turnip": ["cool", "middle", "hardy", "About 9 days in good weather"],
	&"potato": ["cool", "middle", "hardy", "About 11 days in good weather"],
	&"carrot": ["cool", "middle", "hardy", "About 11 days in good weather"],
	&"cabbage": ["cool", "high", "hardy", "About 11 days in good weather"],
	&"onion": ["cool", "middle", "hardy", "About 12 days in good weather"],
	&"wheat": ["cool", "middle", "hardy", "About 12 days in good weather"],
	&"rye": ["cool", "low", "hardy", "About 13 days in good weather"],
	&"buckwheat": ["warm", "low", "tender", "About 8 days in good weather"],
	&"peas": ["cool", "high", "tender", "About 11 days in good weather, then about 4 again"],
	&"beans": ["warm", "middle", "tender", "About 10 days in good weather, then about 3 again"],
	&"flax": ["cool", "high", "tender", "About 11 days in good weather"],
	&"strawberries": ["cool", "high", "hardy", "About 10 days in good weather, then about 3 again"],
	&"pumpkin": ["warm", "high", "hardy", "About 14 days in good weather"],
}


func test_every_crop_has_its_words_in_the_tests() -> void:
	var crop_ids := CropRules.default_rules().crop_ids()
	crop_ids.sort()
	var tested_ids := CROP_LIKES.keys()
	tested_ids.sort()
	assert_eq(tested_ids, crop_ids)


func test_seeds_say_what_their_crop_likes() -> void:
	for crop_id: StringName in CROP_LIKES:
		var seed_id: StringName = CropRules.default_rules().crop(crop_id)["seed"]
		var lines := ItemTooltip.text_for(seed_id).split("\n")
		var likes: Array = CROP_LIKES[crop_id]
		assert_has(lines, "Likes %s weather" % likes[0], crop_id)
		assert_has(lines, "Water need: " + likes[1], crop_id)
		assert_has(lines, "Wind: " + likes[2], crop_id)
		assert_has(lines, likes[3], crop_id)


func test_tree_seeds_say_nothing_about_weather() -> void:
	assert_false("Wind:" in ItemTooltip.text_for(ItemTypes.ACORN))


func _text(crop: WorldObject, day: WeatherDay = null, moisture := -1.0) -> String:
	return CropWords.state_text(
		crop,
		_best_day(crop) if day == null else day,
		_best_moisture(crop) if moisture < 0.0 else moisture
	)


func _ripe_crop(type: StringName) -> WorldObject:
	var crop := _crop(type)
	crop.state["growth"] = (CropRules.STAGES - 1) * _need(crop, "growth_per_stage")
	return crop


func test_every_crop_grows_well_in_its_best_weather() -> void:
	for crop_id in CropRules.default_rules().crop_ids():
		var crop := _crop(crop_id)
		var lines := _text(crop).split("\n")
		assert_eq(lines[0], "%s, growing" % crop.type_data()["name"], crop_id)
		assert_eq(lines.size(), 2, crop_id)
		assert_eq(lines[1], "Soil moisture %.2f, good" % _best_moisture(crop), crop_id)


func test_every_crop_says_when_ripe_that_it_will_wither() -> void:
	for crop_id in CropRules.default_rules().crop_ids():
		var crop := _ripe_crop(crop_id)
		var lines := _text(crop).split("\n")
		assert_eq(lines[0], "%s, ripe" % crop.type_data()["name"], crop_id)
		assert_eq(
			lines[1], "Pick it: it will wither in %d days" % CropLife.days_until_withering(crop)
		)


func test_a_dead_crop_says_so_and_how_to_clear_it() -> void:
	for crop_id in CropRules.default_rules().crop_ids():
		var crop := _crop(crop_id)
		crop.state["crop_damage"] = 1.0
		assert_eq(
			_text(crop),
			"%s, dead\nClear it with the hand or the hoe." % crop.type_data()["name"],
			crop_id
		)


func test_a_crop_that_withers_tonight_says_tonight() -> void:
	var crop := _ripe_crop(&"turnip")
	crop.state["ripe_at_dawn"] = 1
	crop.state["days_growing"] = 9
	crop.state["days_ripe"] = 9
	assert_string_contains(_text(crop), "it will wither tonight")


func test_the_days_a_ripe_crop_has_left_are_the_nights_until_it_withers() -> void:
	for ripe_at_dawn in [0, 1]:
		var crop := _ripe_crop(&"turnip")
		crop.state["days_growing"] = 9
		crop.state["ripe_at_dawn"] = ripe_at_dawn
		var nights_left := CropLife.days_until_withering(crop)
		var nights := 0
		while not CropLife.is_dead(crop):
			CropLife.end_day(crop)
			nights += 1
		assert_eq(nights, nights_left, "ripe at dawn: %d" % ripe_at_dawn)


func test_cold_slows_a_crop() -> void:
	for crop_id in CropRules.default_rules().crop_ids():
		var crop := _crop(crop_id)
		var day := _best_day(crop)
		day.mean_temperature = _need(crop, "temperature_min") + 0.1
		assert_string_contains(_text(crop, day), "Slowed by cold", crop_id)


func test_heat_slows_a_crop() -> void:
	for crop_id in CropRules.default_rules().crop_ids():
		var crop := _crop(crop_id)
		var day := _best_day(crop)
		day.mean_temperature = _need(crop, "temperature_max") - 0.1
		assert_string_contains(_text(crop, day), "Slowed by heat", crop_id)


func test_dry_soil_slows_a_crop_before_it_hurts() -> void:
	for crop_id in CropRules.default_rules().crop_ids():
		var crop := _crop(crop_id)
		var text := _text(crop, null, _need(crop, "moisture_min") + 0.01)
		assert_string_contains(text, "Slowed by dry soil", crop_id)
		assert_string_contains(text, "a little dry", crop_id)


func test_too_little_sun_slows_a_crop() -> void:
	for crop_id in CropRules.default_rules().crop_ids():
		var crop := _crop(crop_id)
		var day := _best_day(crop)
		day.sunlight_hours = _need(crop, "sunlight_min") + 0.01
		assert_string_contains(_text(crop, day), "Slowed by too little sun", crop_id)


func test_a_bad_day_says_what_hurts_the_crop_and_not_what_slows_it() -> void:
	for crop_id in CropRules.default_rules().crop_ids():
		var crop := _crop(crop_id)
		var frost := _best_day(crop)
		frost.min_temperature = _need(crop, "temperature_min") - 1.0
		var windy := _best_day(crop)
		windy.max_wind_speed = _need(crop, "wind_max") + 1.0
		var dark := _best_day(crop)
		dark.sunlight_hours = _need(crop, "sunlight_min") - 0.5
		var dry := _text(crop, null, _need(crop, "moisture_min") - 0.05)
		assert_string_contains(_text(crop, frost), "Frost is hurting it", crop_id)
		assert_string_contains(_text(crop, windy), "Wind is hurting it", crop_id)
		assert_string_contains(_text(crop, dark), "Too little sun is hurting it", crop_id)
		assert_string_contains(dry, "Dry soil is hurting it", crop_id)
		assert_string_contains(dry, "too dry", crop_id)
		assert_false("Slowed" in dry, crop_id)


func test_a_ripe_crop_is_not_slowed_as_it_grows_no_more() -> void:
	var crop := _ripe_crop(&"turnip")
	var day := _best_day(crop)
	day.mean_temperature = _need(crop, "temperature_min") + 0.1
	assert_false("Slowed" in _text(crop, day))


func test_a_damaged_crop_says_how_many_bad_days_it_has_left() -> void:
	var crop := _crop(&"turnip")
	crop.state["crop_damage"] = 0.5
	assert_string_contains(_text(crop), "Damaged: 2 more bad days kill it")


func test_the_soil_is_told_by_its_moisture_not_by_the_rain_on_its_surface() -> void:
	var crop := _crop(&"turnip")
	assert_string_contains(_text(crop, null, 0.35), "Soil moisture 0.35, a little dry")
