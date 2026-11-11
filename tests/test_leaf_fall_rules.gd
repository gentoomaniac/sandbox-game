extends GutTest
## How often trees shed leaves by season and wind (data/leaf_fall.cfg), and what makes the
## data file bad.

const KINDS := HitEffect.Kind
const LOOKS := SeasonBlend.Look
const EARLY_SUMMER := 40
const LATE_SUMMER := 58
const AUTUMN := 75
const BREEZE := 6.0
const GALE := 14.0

var _rules := LeafFallRules.default_rules()


func _chance(kind: HitEffect.Kind, look: SeasonBlend.Look, day: int, speed: float) -> float:
	return _rules.shed_chance(kind, look, day, speed, 0.0)


func _rules_with(section: String, key: String, value: Variant) -> LeafFallRules:
	var values := DataFile.read_sections(LeafFallRules.DEFAULT_PATH)
	values[section][key] = value
	return LeafFallRules.new(values)


func test_the_data_file_has_no_problems() -> void:
	assert_eq(_rules.problems(), [])


func test_a_calm_day_sheds_nothing_in_any_season() -> void:
	var calm: float = _rules.value("shedding", "calm_speed")
	assert_eq(_chance(KINDS.LEAVES_AUTUMN, LOOKS.AUTUMN, AUTUMN, 0.0), 0.0)
	assert_eq(_chance(KINDS.LEAVES_AUTUMN, LOOKS.AUTUMN, AUTUMN, calm), 0.0)
	assert_eq(_rules.shed_chance(KINDS.LEAVES_AUTUMN, LOOKS.AUTUMN, AUTUMN, calm, 1.0), 0.0)
	assert_eq(_rules.carried_chance(calm), 0.0)


func test_the_stronger_the_wind_the_more_leaves_fall() -> void:
	var breeze := _chance(KINDS.LEAVES_AUTUMN, LOOKS.AUTUMN, AUTUMN, BREEZE)
	var gale := _chance(KINDS.LEAVES_AUTUMN, LOOKS.AUTUMN, AUTUMN, GALE)
	assert_gt(breeze, 0.0)
	assert_gt(gale, breeze)
	assert_lt(_rules.carried_chance(BREEZE), _rules.carried_chance(GALE))


func test_a_gust_front_over_a_tree_adds_to_the_wind() -> void:
	var steady := _rules.shed_chance(KINDS.LEAVES_AUTUMN, LOOKS.AUTUMN, AUTUMN, BREEZE, 0.0)
	var in_gust := _rules.shed_chance(KINDS.LEAVES_AUTUMN, LOOKS.AUTUMN, AUTUMN, BREEZE, 1.0)
	assert_gt(in_gust, steady)


func test_a_chance_is_never_above_one() -> void:
	assert_lte(_rules.shed_chance(KINDS.LEAVES_AUTUMN, LOOKS.AUTUMN, AUTUMN, 99.0, 1.0), 1.0)


func test_trees_in_autumn_colours_shed_most_and_green_ones_late_in_summer_a_little() -> void:
	var autumn := _chance(KINDS.LEAVES_AUTUMN, LOOKS.AUTUMN, AUTUMN, GALE)
	var late_summer := _chance(KINDS.LEAVES_GREEN, LOOKS.SUMMER, LATE_SUMMER, GALE)
	assert_gt(late_summer, 0.0)
	assert_lt(late_summer, autumn)
	assert_eq(_chance(KINDS.LEAVES_GREEN, LOOKS.SUMMER, EARLY_SUMMER, GALE), 0.0)


func test_a_tree_with_the_colours_of_autumn_still_sheds_in_early_winter() -> void:
	var early_winter := 93
	assert_gt(_chance(KINDS.LEAVES_AUTUMN, LOOKS.AUTUMN, early_winter, GALE), 0.0)
	assert_eq(_chance(KINDS.NONE, LOOKS.BARE, early_winter, GALE), 0.0, "a bare tree")


func test_a_tree_in_spring_leaf_sheds_none() -> void:
	for look in [LOOKS.BUDS, LOOKS.YOUNG_LEAVES, LOOKS.SPRING]:
		var kind := HitEffect.kind_for(WorldObjectTypes.OAK, look)
		assert_eq(_chance(kind, look, 10, GALE), 0.0, "look %d" % look)


func test_the_year_repeats() -> void:
	var next_year := AUTUMN + GameClock.DAYS_PER_YEAR
	assert_eq(
		_chance(KINDS.LEAVES_GREEN, LOOKS.SUMMER, LATE_SUMMER + GameClock.DAYS_PER_YEAR, GALE),
		_chance(KINDS.LEAVES_GREEN, LOOKS.SUMMER, LATE_SUMMER, GALE)
	)
	assert_eq(
		_chance(KINDS.LEAVES_AUTUMN, LOOKS.AUTUMN, next_year, GALE),
		_chance(KINDS.LEAVES_AUTUMN, LOOKS.AUTUMN, AUTUMN, GALE)
	)


func test_conifers_drop_a_rare_needle_and_snow_covers_it() -> void:
	var needle := _chance(KINDS.NEEDLES, LOOKS.AUTUMN, AUTUMN, GALE)
	assert_gt(needle, 0.0)
	assert_lt(needle, _chance(KINDS.LEAVES_AUTUMN, LOOKS.AUTUMN, AUTUMN, GALE) / 10.0)
	assert_eq(_chance(KINDS.SNOW, LOOKS.SNOW, AUTUMN, GALE), 0.0)


func test_a_full_wind_speed_not_above_the_calm_one_is_bad() -> void:
	var calm: float = _rules.value("shedding", "calm_speed")
	assert_false(_rules_with("shedding", "full_speed", calm).is_valid())


func test_a_missing_key_is_reported() -> void:
	var values := DataFile.read_sections(LeafFallRules.DEFAULT_PATH)
	values["carried"].erase("life")
	assert_eq(LeafFallRules.new(values).problems(), ["[carried] no life"])
