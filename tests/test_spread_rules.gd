extends GutTest
## The numbers of how stories spread (data/gossip.cfg, SpreadRules), and what makes them bad.

var _rules := SpreadRules.default_rules()


func _rules_with(key: String, value: Variant) -> SpreadRules:
	var values := DataFile.read_sections(GossipRules.DEFAULT_PATH)
	values["meetings"][key] = value
	return SpreadRules.new(values)


func test_the_data_file_has_no_problems() -> void:
	assert_eq(_rules.problems(), [])


func test_villagers_within_three_tiles_meet_a_pair_once_an_hour() -> void:
	assert_eq(_rules.meeting_radius(), 3.0)
	assert_eq(_rules.pair_wait_minutes(), 60)


func test_a_story_waits_two_hours_and_stops_after_three_hops_or_seven_days() -> void:
	assert_eq(_rules.story_wait_minutes(), 120)
	assert_eq(_rules.max_hops(), 3)
	assert_eq(_rules.max_story_days(), 7)


func test_family_tell_more_often_than_neighbours_and_neighbours_more_than_anyone() -> void:
	assert_gt(_rules.tell_chance(SpreadRules.FAMILY), _rules.tell_chance(SpreadRules.NEIGHBOUR))
	assert_gt(_rules.tell_chance(SpreadRules.NEIGHBOUR), _rules.tell_chance(SpreadRules.ANYONE))
	assert_eq(_rules.neighbour_count(), 3)


func test_a_topic_is_taught_with_its_own_chance() -> void:
	assert_eq(_rules.topic_chance(), 0.5)


func test_a_missing_key_is_a_problem() -> void:
	var values := DataFile.read_sections(GossipRules.DEFAULT_PATH)
	values["meetings"].erase("max_hops")
	assert_eq(SpreadRules.new(values).problems(), ["[meetings] no max_hops"])


func test_a_chance_beyond_one_and_a_wait_of_nothing_are_problems() -> void:
	assert_eq(_rules_with("chance_family", 1.5).problems().size(), 1)
	assert_eq(_rules_with("chance_topic", -0.1).problems().size(), 1)
	assert_eq(_rules_with("story_wait_minutes", 0).problems().size(), 1)
	assert_eq(_rules_with("max_hops", 0).problems().size(), 1)


func test_a_count_grows_to_the_next_step_and_stays_past_the_last() -> void:
	assert_eq(_rules.next_count(1), 2)
	assert_eq(_rules.next_count(7), 10)
	assert_eq(_rules.next_count(11), 12)
	assert_eq(_rules.next_count(100), 100)


func test_a_kind_turns_into_another_one_by_the_table() -> void:
	assert_eq(_rules.similar_kind(GossipRules.BUILT), GossipRules.FENCED)
	assert_eq(_rules.similar_kind(GossipRules.FELLED), GossipRules.MOWED)
	assert_eq(_rules.whisper_chance(), 0.1)


func test_a_kind_that_turns_into_itself_or_has_no_entry_is_a_problem() -> void:
	var values := DataFile.read_sections(GossipRules.DEFAULT_PATH)
	values["whisper_kinds"]["felled"] = "felled"
	assert_eq(SpreadRules.new(values).problems().size(), 1)
	values["whisper_kinds"].erase("mowed")
	assert_eq(SpreadRules.new(values).problems(), ["[whisper_kinds] no mowed"])


func test_steps_that_do_not_rise_are_a_problem() -> void:
	var values := DataFile.read_sections(GossipRules.DEFAULT_PATH)
	values["whispers"]["count_steps"] = [5, 3]
	assert_eq(SpreadRules.new(values).problems(), ["[whispers] count_steps must rise"])
