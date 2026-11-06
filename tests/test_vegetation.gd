extends GutTest
## The yearly curves of the vegetation and the thresholds that make plants come and go one by
## one.

const DATA_DIR := "user://test_vegetation"
const DATA_FILE := DATA_DIR + "/vegetation.cfg"
const SEED := 3
const SPOTS := 2000
const DAYS_PER_YEAR := GameClock.DAYS_PER_YEAR

var _vegetation := Vegetation.default_vegetation()


func after_each() -> void:
	for file_name in DirAccess.get_files_at(DATA_DIR):
		DirAccess.remove_absolute(DATA_DIR.path_join(file_name))


# --- The curves ---


func test_a_curve_hits_its_anchors_and_eases_between_them() -> void:
	var vegetation := Vegetation.from_curves({&"tuft": [Vector2(15, 0.2), Vector2(45, 1.0)]})
	assert_almost_eq(vegetation.density(&"tuft", 15), 0.2, 0.0001)
	assert_almost_eq(vegetation.density(&"tuft", 45), 1.0, 0.0001)
	assert_almost_eq(vegetation.density(&"tuft", 30), 0.6, 0.0001)
	assert_lt(vegetation.density(&"tuft", 20), 0.2 + 0.8 * 5.0 / 30.0, "eases in")


func test_a_curve_wraps_around_the_new_year() -> void:
	var vegetation := Vegetation.from_curves({&"tuft": [Vector2(15, 0.2), Vector2(45, 1.0)]})
	# Halfway from the last anchor (day 45) to the first of the next year (day 135).
	assert_almost_eq(vegetation.density(&"tuft", 90), 0.6, 0.0001)
	assert_almost_eq(vegetation.density(&"tuft", 1), vegetation.density(&"tuft", 121), 0.0001)
	assert_almost_eq(vegetation.density(&"tuft", 135), 0.2, 0.0001)
	assert_almost_eq(vegetation.density(&"tuft", 120), vegetation.density(&"tuft", 240), 0.0001)
	# No jump at the turn of the year.
	assert_lt(absf(vegetation.density(&"tuft", 120) - vegetation.density(&"tuft", 121)), 0.05)


func test_every_curve_of_the_data_file_stays_between_0_and_1() -> void:
	for section: Dictionary in Vegetation.KIND_SALTS.values():
		for kind: StringName in section:
			for day in range(1, 2 * DAYS_PER_YEAR + 1):
				var density := _vegetation.density(kind, day)
				assert_between(density, 0.0, 1.0, "%s on day %d" % [kind, day])


func test_the_data_file_follows_the_seasons() -> void:
	var summer := 45
	var winter := 105
	assert_lt(_vegetation.density(&"tuft", 1), _vegetation.density(&"tuft", summer))
	assert_eq(_vegetation.density(&"tuft", summer), 1.0)
	assert_lt(_vegetation.density(&"tuft", 80), _vegetation.density(&"tuft", summer))
	assert_gt(_vegetation.density(&"tuft", winter), 0.0, "a few stalks in winter")
	assert_lt(_vegetation.density(&"tuft", winter), 0.1)
	assert_gt(_vegetation.density(&"flower", 20), 0.4)
	assert_gt(_vegetation.density(&"flower", summer), 0.4)
	assert_eq(_vegetation.density(&"flower", winter), 0.0)
	assert_gt(_vegetation.density(&"leaves", 85), 0.8)
	assert_eq(_vegetation.density(&"leaves", summer), 0.0)
	assert_eq(_vegetation.density(&"fern_bush", winter), 0.0)
	assert_eq(_vegetation.density(&"fern_bush", 2), 0.0)
	assert_eq(_vegetation.density(&"fern_bush", summer), 1.0)
	assert_eq(_vegetation.density(&"berry_bush", 20), 0.0)
	assert_eq(_vegetation.density(&"berry_bush", 50), 1.0)
	assert_eq(_vegetation.density(&"berry_bush", winter), 0.0)


# --- Thresholds ---


func test_a_threshold_is_fixed_and_between_0_and_1() -> void:
	for x in 50:
		var pos := Vector2i(x, -x)
		var threshold := _vegetation.threshold(&"tuft", SEED, pos)
		assert_between(threshold, 0.0, 0.9999)
		assert_eq(_vegetation.threshold(&"tuft", SEED, pos), threshold)


func test_thresholds_differ_between_kinds_and_seeds() -> void:
	var differing_kinds := 0
	var differing_seeds := 0
	for x in 50:
		var pos := Vector2i(x, 7)
		var tuft := _vegetation.threshold(&"tuft", SEED, pos)
		if tuft != _vegetation.threshold(&"flower", SEED, pos):
			differing_kinds += 1
		if tuft != _vegetation.threshold(&"tuft", SEED + 1, pos):
			differing_seeds += 1
	assert_gt(differing_kinds, 40)
	assert_gt(differing_seeds, 40)


func test_a_spot_shows_while_the_density_is_above_its_threshold() -> void:
	for x in 50:
		var pos := Vector2i(x, 3)
		var threshold := _vegetation.threshold(&"flower", SEED, pos)
		for day in [20, 50, 100]:
			var density := _vegetation.density(&"flower", day)
			assert_eq(_vegetation.is_present(&"flower", SEED, pos, day), density > threshold)


# --- Gradual change ---


func test_the_fraction_of_present_spots_changes_smoothly_from_day_to_day() -> void:
	for section: Dictionary in Vegetation.KIND_SALTS.values():
		for kind: StringName in section:
			var previous := _present_count(kind, 1)
			for day in range(2, DAYS_PER_YEAR + 2):
				var count := _present_count(kind, day)
				assert_lt(float(absi(count - previous)), SPOTS * 0.15, "%s on day %d" % [kind, day])
				previous = count


func test_ferns_come_back_over_weeks_not_on_one_morning() -> void:
	var first_days: Array[int] = []
	for x in 200:
		var pos := Vector2i(x, 11)
		for day in range(1, DAYS_PER_YEAR + 1):
			if _vegetation.is_present(&"fern_bush", SEED, pos, day):
				first_days.append(day)
				break
	assert_gt(first_days.max() - first_days.min(), 10)


func test_a_spot_that_shows_stays_while_the_density_rises() -> void:
	for x in 100:
		var pos := Vector2i(x, 5)
		var was_present := false
		# The tuft density rises from day 105 (0.03) to day 45 of the next year (1.0).
		for day in range(105, 45 + DAYS_PER_YEAR + 1):
			var is_present := _vegetation.is_present(&"tuft", SEED, pos, day)
			assert_true(is_present or not was_present, "%s dropped out on day %d" % [pos, day])
			was_present = is_present


# --- The data file ---


func test_the_data_file_has_every_curve() -> void:
	var vegetation := Vegetation.from_file(Vegetation.DEFAULT_PATH)
	assert_true(vegetation.is_valid(), str(vegetation.problems()))


func test_every_missing_curve_is_reported() -> void:
	DirAccess.make_dir_recursive_absolute(DATA_DIR)
	var file := FileAccess.open(DATA_FILE, FileAccess.WRITE)
	file.store_string("[decorations]\ntuft=[Vector2(1, 0.5)]\n")
	file.close()
	var vegetation := Vegetation.from_file(DATA_FILE)
	var missing := vegetation.problems()
	assert_false(vegetation.is_valid())
	assert_true(missing.has("[decorations] no flower"))
	assert_true(missing.has("[objects] no fern_bush"))
	assert_false(missing.has("[decorations] no tuft"))
	assert_push_error_count(missing.size())


# --- The decoration atlas ---


func test_every_decoration_has_a_kind_with_a_curve() -> void:
	var tileset := TerrainTileset.new()
	for layer: int in TerrainTileset.DECORATION_KINDS:
		var kinds: Array = TerrainTileset.DECORATION_KINDS[layer]
		assert_eq(kinds.size(), tileset._decoration_counts[layer], "layer %d" % layer)
		for kind: StringName in kinds:
			var has_curve: bool = Vegetation.KIND_SALTS["decorations"].has(kind)
			assert_true(kind == &"" or has_curve, "kind %s" % kind)


func test_a_decoration_without_a_listed_layer_shows_all_year() -> void:
	assert_eq(TerrainTileset.decoration_kind(Vector2i(0, TerrainTileset.Layer.WETLAND)), &"")
	assert_eq(TerrainTileset.decoration_kind(Vector2i(7, TerrainTileset.Layer.GRASS)), &"tuft")


func _present_count(kind: StringName, day: int) -> int:
	var count := 0
	for i in SPOTS:
		if _vegetation.is_present(kind, SEED, Vector2i(i % 50, i / 50), day):
			count += 1
	return count
