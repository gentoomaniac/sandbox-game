extends CropCase
## A ripe crop left unharvested withers (see CropLife).


func test_a_ripe_crop_withers_after_as_many_days_as_it_took_to_ripen() -> void:
	var crop := _crop()
	var days_needed := ceili(3.0 * _need(crop, "growth_per_stage"))
	_live(crop, _best_day(crop), days_needed)
	assert_true(CropLife.is_ripe(crop))
	assert_eq(CropLife.days_growing(crop), days_needed)
	_live(crop, _best_day(crop), days_needed)
	assert_true(CropLife.is_ripe(crop), "still waits on its last day")
	_live(crop, _best_day(crop))
	assert_true(CropLife.is_dead(crop), "withered one day later")
	assert_eq(CropLife.look(crop), int(_need(crop, "growth_stages")), "shows the dead stage")


func test_a_slow_crop_waits_longer() -> void:
	var crop := _crop()
	var poor_day := _best_day(crop)
	poor_day.sunlight_hours = _need(crop, "sunlight_best") / 2.0
	var days := 0
	while not CropLife.is_ripe(crop):
		_live(crop, poor_day)
		days += 1
	assert_eq(CropLife.days_growing(crop), days)
	_live(crop, poor_day, days)
	assert_false(CropLife.is_dead(crop))


func test_a_regrown_crop_counts_its_days_again() -> void:
	var crop := _crop(&"peas")
	_live(crop, _best_day(crop), 40)
	assert_true(CropLife.is_dead(crop), "left ripe too long")
	crop = _crop(&"peas")
	crop.state["growth"] = 3.0 * _need(crop, "growth_per_stage")
	crop.state["days_ripe"] = 5
	CropLife.regrow(crop)
	assert_eq([CropLife.days_growing(crop), CropLife.days_ripe(crop)], [0, 0])


func test_a_crop_from_an_old_save_counts_as_grown_on_perfect_days() -> void:
	var crop := _crop()
	crop.state["growth"] = 3.0 * _need(crop, "growth_per_stage")
	assert_eq(CropLife.days_growing(crop), ceili(3.0 * _need(crop, "growth_per_stage")))
