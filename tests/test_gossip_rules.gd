extends GutTest
## The words and numbers of the deed log (data/gossip.cfg), and what makes the data file bad.

var _rules := GossipRules.default_rules()


func _rules_with(section: String, key: String, value: Variant) -> GossipRules:
	var values := DataFile.read_sections(GossipRules.DEFAULT_PATH)
	values[section][key] = value
	return GossipRules.new(values)


func test_the_data_file_has_no_problems() -> void:
	assert_eq(_rules.problems(), [])


func test_the_radius_is_20_tiles_by_day_and_6_at_night() -> void:
	assert_eq(_rules.radius(false), 20.0)
	assert_eq(_rules.radius(true), 6.0)


func test_a_deed_is_kept_for_7_days() -> void:
	assert_eq(_rules.keep_days(), 7)


func test_a_deed_is_told_in_the_singular_for_one_and_with_the_count_for_more() -> void:
	assert_eq(_rules.deed_words(GossipRules.FELLED, 1), "fell a tree")
	assert_eq(_rules.deed_words(GossipRules.FELLED, 7), "fell 7 trees")


func test_the_house_and_the_ground_make_the_place() -> void:
	assert_eq(_rules.house_place("Antje"), "by Antje's house")
	assert_eq(_rules.ground_place(Tile.Terrain.SALT_MARSH), "out on the salt marsh")


func test_a_story_names_the_day_it_was_seen() -> void:
	var deed := {"kind": GossipRules.FELLED, "count": 7, "place": "by Antje's house"}
	assert_eq(
		_rules.story_line(deed, 0), "Today you saw the newcomer fell 7 trees by Antje's house."
	)
	assert_string_starts_with(_rules.story_line(deed, 1), "Yesterday you saw")
	assert_string_starts_with(_rules.story_line(deed, 3), "3 days ago you saw")


func test_a_missing_deed_kind_is_a_problem() -> void:
	var values := DataFile.read_sections(GossipRules.DEFAULT_PATH)
	values.erase("mowed")
	assert_eq(
		GossipRules.new(values).problems(),
		["[mowed] no one", "[mowed] no many", "[mowed] no change"]
	)


func test_a_night_radius_above_the_day_radius_is_a_problem() -> void:
	var rules := _rules_with("witnesses", "night_radius_tiles", 30.0)
	assert_eq(rules.problems().size(), 1)


func test_a_change_beyond_two_is_a_problem() -> void:
	var values := DataFile.read_sections(GossipRules.DEFAULT_PATH)
	values["built"]["change"] = 3
	assert_eq(GossipRules.new(values).problems().size(), 1)


func test_a_villager_is_told_every_story_they_keep_oldest_first() -> void:
	var stories: Array[Dictionary] = []
	for day in range(1, 8):
		stories.append({"day": day, "kind": GossipRules.TILLED, "count": 1, "place": "here"})

	var lines := _rules.story_lines(stories, 7)

	assert_eq(lines.size(), 7)
	assert_string_starts_with(lines[0], "6 days ago you saw")
	assert_string_starts_with(lines[-1], "Today you saw")


func test_a_story_leaves_a_dated_line_for_long_term_memory() -> void:
	var story := {"day": 4, "kind": GossipRules.FELLED, "count": 7, "place": "by Antje's house"}
	assert_eq(
		_rules.memory_line(story), "On day 4: you saw the newcomer fell 7 trees by Antje's house."
	)
