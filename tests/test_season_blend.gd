extends GutTest
## The blend of the seasons' looks: a share of the tiles has changed over around each boundary,
## growing gradually; snow and frost against a tile's threshold.

const SEED := 3
const TILES := 4000
const L := SeasonBlend.Look

var _blend := SeasonBlend.new(SEED)


func _threshold_of(i: int) -> Vector2:
	return _blend.thresholds(Vector2i(i % 64, i / 64))


## The share of the tiles (a grid of them) that have a look on a day, by the season alone.
func _share(look: SeasonBlend.Look, day: int, is_foliage := false) -> float:
	var conditions := _blend.conditions(day, 0.0, 0.0)
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
	assert_eq(_share(L.BARE, 1), 1.0, "spring starts bare")


func test_the_share_changes_gradually_over_each_boundary_never_at_once() -> void:
	# Day by day over a boundary's window the share of tiles that changed over grows a little
	# at a time.
	for window in [[60, 78, L.SUMMER], [22, 38, L.SPRING], [82, 100, L.AUTUMN]]:
		var last := _share(window[2], window[0] - 1)
		var biggest_step := 0.0
		var steps_with_change := 0
		for day in range(window[0], window[1] + 1):
			var now := _share(window[2], day)
			biggest_step = maxf(biggest_step, absf(now - last))
			steps_with_change += 1 if now != last else 0
			last = now
		assert_lt(biggest_step, 0.3, "window %s changes day by day" % [window])
		assert_gt(steps_with_change, 8, "window %s" % [window])


func test_trees_colour_first_and_drop_their_leaves_one_by_one() -> void:
	assert_between(_share(L.AUTUMN, 66, true), 0.1, 0.9, "mixed in early autumn")
	var late_autumn_bare := _share(L.BARE, 85, true)
	assert_between(late_autumn_bare, 0.1, 0.9, "some trees are bare in late autumn")
	assert_lt(_share(L.BARE, 78, true), late_autumn_bare)
	assert_lt(late_autumn_bare, _share(L.BARE, 92, true))
	assert_lt(_share(L.SPRING, 5, true), _share(L.SPRING, 12, true), "leaf-out goes on in spring")


func test_a_tree_in_leaf_does_not_go_back_to_summer_while_autumn_comes() -> void:
	for i in 300:
		var threshold := _threshold_of(i).x
		var was_autumn := false
		for day in range(56, 74):
			var look := _blend.conditions(day, 0.0, 0.0).foliage_season_look(threshold)
			assert_false(was_autumn and look != L.AUTUMN, "no going back")
			was_autumn = look == L.AUTUMN


# --- Snow and frost ---


func _share_with(snow: float, frost: float, look: SeasonBlend.Look) -> float:
	var conditions := _blend.conditions(105, snow, frost)
	var count := 0
	for i in TILES:
		if conditions.weather_look(_threshold_of(i).y) == look:
			count += 1
	return float(count) / TILES


func test_the_share_of_snowy_tiles_tracks_the_cover() -> void:
	assert_eq(_share_with(0.0, 0.0, L.SNOW), 0.0)
	for cover in [0.1, 0.3, 0.5, 0.8]:
		assert_almost_eq(_share_with(cover, 0.0, L.SNOW), cover, 0.03)
	assert_eq(_share_with(1.0, 0.0, L.SNOW), 1.0)


func test_a_tile_that_is_snowy_at_a_cover_stays_snowy_at_a_higher_one() -> void:
	for i in 300:
		var threshold := _threshold_of(i).y
		var was_snowy := false
		for cover in [0.0, 0.2, 0.4, 0.6, 0.8, 1.0]:
			var is_snowy := _blend.conditions(105, cover, 0.0).weather_look(threshold) == L.SNOW
			assert_false(was_snowy and not is_snowy)
			was_snowy = is_snowy


func test_snow_has_a_dusting_as_its_fringe_and_frost_only_beyond_it() -> void:
	var band: float = SeasonRules.default_rules().value("snow", "dusting_band")
	var conditions := _blend.conditions(105, 0.3, 0.6)
	var counts := {}
	for i in TILES:
		var threshold := _threshold_of(i).y
		var look := conditions.weather_look(threshold)
		counts[look] = counts.get(look, 0) + 1
		if threshold < 0.3:
			assert_eq(look, L.SNOW)
		elif threshold < 0.3 + band:
			assert_eq(look, L.DUSTING)
		elif threshold < 0.6:
			assert_eq(look, L.FROST)
		else:
			assert_eq(look, L.SUMMER, "nothing over the season's look")
	for look in [L.SNOW, L.DUSTING, L.FROST]:
		assert_gt(counts[look], 0)


func test_there_is_no_dusting_without_snow_cover() -> void:
	assert_eq(_share_with(0.0, 0.5, L.DUSTING), 0.0)
	assert_gt(_share_with(0.05, 0.0, L.DUSTING), 0.0, "a first snowfall is a dusting")
	assert_almost_eq(_share_with(0.2, 0.0, L.DUSTING), 0.15, 0.03)


func test_a_frost_gets_stronger_as_it_gets_colder() -> void:
	assert_lt(_share_with(0.0, 0.2, L.FROST), _share_with(0.0, 0.7, L.FROST))
	assert_eq(_share_with(0.0, 0.0, L.FROST), 0.0)


func test_snow_wins_over_the_look_of_a_plant() -> void:
	assert_eq(_blend.conditions(45, 1.0, 0.0).foliage_look(0.5, 0.5), L.SNOW)
	assert_eq(_blend.conditions(45, 0.0, 0.0).foliage_look(0.5, 0.5), L.SUMMER)


func test_the_data_file_is_complete() -> void:
	var rules := SeasonRules.default_rules()
	assert_true(rules.is_valid(), str(rules.missing_keys()))
	assert_false(SeasonRules.new({}).is_valid())
