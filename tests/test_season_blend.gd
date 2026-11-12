extends GutTest
## The blend of the seasons' looks: a share of the tiles has changed over around each boundary,
## growing gradually; snow and frost against a tile's threshold.

const SEED := 3
const TILES := 4000
const L := SeasonBlend.Look
## The first day of each season, and the look its boundary changes to.
const SEASON_STARTS := [[1, L.SPRING], [31, L.SUMMER], [61, L.AUTUMN], [91, L.BARE]]

var _blend := SeasonBlend.new(SEED)


func _threshold_of(i: int) -> Vector2:
	return _blend.thresholds(Vector2i(i % 64, i / 64))


## The share of the tiles (a grid of them) that have a look on a day, by the season alone.
func _share(look: SeasonBlend.Look, day: int, is_foliage := false) -> float:
	var conditions := _blend.conditions(day)
	var count := 0
	for i in TILES:
		var x := _threshold_of(i).x
		var found := (
			conditions.foliage_season_look(x) if is_foliage else conditions.ground_season_look(x)
		)
		if found == look:
			count += 1
	return float(count) / TILES


func test_the_thresholds_are_stable_and_spread_evenly() -> void:
	var total := 0.0
	for i in TILES:
		var thresholds := _threshold_of(i)
		assert_eq(thresholds, _threshold_of(i))
		assert_between(thresholds.x, 0.0, 0.9999)
		assert_between(thresholds.y, 0.0, 0.9999)
		total += thresholds.x
	assert_almost_eq(total / TILES, 0.5, 0.03)


func test_the_two_thresholds_of_a_tile_are_independent() -> void:
	var equal := 0
	for i in 500:
		var thresholds := _threshold_of(i)
		if absf(thresholds.x - thresholds.y) < 0.01:
			equal += 1
	assert_lt(equal, 30)


func test_the_looks_follow_the_year() -> void:
	assert_eq(_share(L.SUMMER, 45), 1.0)
	assert_eq(_share(L.BARE, 110), 1.0, "winter is bare")
	assert_eq(_share(L.SPRING, 20), 1.0, "spring has leafed out")
	assert_eq(_share(L.SPRING, 20, true), 1.0)
	assert_eq(_share(L.BARE, 120), 1.0, "winter ends bare")
	assert_eq(_share(L.BARE, 120, true), 1.0)


func test_each_change_spreads_over_the_first_three_days_of_its_season() -> void:
	for start: Array in SEASON_STARTS:
		for is_foliage in [false, true]:
			var first_day: int = start[0]
			var look: SeasonBlend.Look = start[1]
			if look == L.SPRING and is_foliage:
				continue  # see the leaf-out test
			var label := "%s from day %d" % [L.keys()[look], first_day]
			assert_eq(_share(look, first_day - 1, is_foliage), 0.0, label + ": not before")
			var last := 0.0
			for day in range(first_day, first_day + 3):
				var now := _share(look, day, is_foliage)
				assert_between(now, 0.05, 0.95, label + ": a mix on day %d" % day)
				assert_gt(now, last, label + ": grows on day %d" % day)
				assert_lt(now - last, 0.5, label + ": not on one morning, day %d" % day)
				last = now
			assert_eq(_share(look, first_day + 3, is_foliage), 1.0, label + ": done")


func test_trees_leaf_out_step_by_step_over_the_first_days_of_spring() -> void:
	assert_eq(_share(L.BARE, 120, true), 1.0, "bare before spring")
	assert_eq(_share(L.SPRING, 4, true), 1.0, "in full leaf on the fourth day")
	for look_on_day in [[L.BUDS, 1], [L.BUDS, 2], [L.YOUNG_LEAVES, 2], [L.YOUNG_LEAVES, 3]]:
		var look: SeasonBlend.Look = look_on_day[0]
		var day: int = look_on_day[1]
		assert_gt(_share(look, day, true), 0.05, "%s on day %d" % [L.keys()[look], day])
	for i in 300:
		var threshold := _threshold_of(i).x
		var step := 0
		for day in [120, 1, 2, 3, 4]:
			var look := _blend.conditions(day).foliage_season_look(threshold)
			var now := SeasonBlend.LEAF_OUT.find(look)
			assert_between(now - step, 0, 1, "one step a day at most, tree %d day %d" % [i, day])
			step = now
		assert_eq(step, SeasonBlend.LEAF_OUT.size() - 1)


func test_grass_has_no_leaf_out_steps() -> void:
	for day in [1, 2, 3]:
		assert_eq(_share(L.BARE, day) + _share(L.SPRING, day), 1.0)


func test_a_tree_in_leaf_does_not_go_back_to_summer_while_autumn_comes() -> void:
	for i in 300:
		var threshold := _threshold_of(i).x
		var was_autumn := false
		for day in range(58, 68):
			var look := _blend.conditions(day).foliage_season_look(threshold)
			assert_false(was_autumn and look != L.AUTUMN, "no going back")
			was_autumn = look == L.AUTUMN


func test_the_data_file_is_complete() -> void:
	var rules := SeasonRules.default_rules()
	assert_true(rules.is_valid(), str(rules.problems()))
	assert_false(SeasonRules.new({}).is_valid())


func test_the_ground_colour_holds_between_windows_and_mixes_in_them() -> void:
	var summer := _blend.ground_mix(45)
	assert_eq([summer.to, summer.share], [L.SUMMER, 1.0])
	var winter := _blend.ground_mix(110)
	assert_eq([winter.to, winter.share], [L.BARE, 1.0])
	var into_autumn := _blend.ground_mix(66)
	assert_eq([into_autumn.from, into_autumn.to], [L.SUMMER, L.AUTUMN])
	assert_between(into_autumn.share, 0.01, 0.99)
	var into_spring := _blend.ground_mix(5)
	assert_eq([into_spring.from, into_spring.to], [L.BARE, L.SPRING])


func test_the_ground_colour_changes_a_little_every_day_without_a_jump() -> void:
	# The place in the cycle of looks as one number: 0 is spring, 1 summer, 2 autumn, 3 winter.
	var previous := -1.0
	for day in range(1, GameClock.DAYS_PER_YEAR + 1):
		var mix := _blend.ground_mix(day)
		var at := fposmod(SeasonBlend.YEAR_LOOKS.find(mix.to) - 1 + mix.share, 4.0)
		if previous >= 0.0:
			assert_between(fposmod(at - previous, 4.0), 0.0, 0.25, "day %d" % day)
		previous = at


func test_the_ground_colour_is_one_for_the_whole_year_cycle() -> void:
	var first := _blend.ground_mix(31)
	var next_year := _blend.ground_mix(31 + GameClock.DAYS_PER_YEAR)
	assert_eq([first.from, first.to, first.share], [next_year.from, next_year.to, next_year.share])


func test_leaves_build_up_in_autumn_and_thin_out_in_winter() -> void:
	assert_eq(_blend.litter(45), 0.0, "none in summer")
	assert_between(_blend.litter(75), 0.1, 0.9)
	assert_gt(_blend.litter(85), _blend.litter(75))
	assert_eq(_blend.litter(96), 1.0)
	assert_lt(_blend.litter(110), 1.0)
	assert_eq(_blend.litter(119), 0.0, "swept away by spring")
	assert_eq(_blend.litter(1), 0.0)
