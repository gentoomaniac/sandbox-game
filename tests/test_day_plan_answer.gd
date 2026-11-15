extends GutTest
## What the checks make of the model's answer to "plan this villager's day" (DayPlanAnswer): good
## JSON, JSON in words, and every kind of entry that is dropped. No model is asked.

const SUNRISE := 6.0 * 60
const SUNSET := 21.0 * 60
const THURSDAY := 4
const SUNDAY := 7

var _rules := ActivityRules.default_rules()
var _offered: Array[String] = [
	"sleep", "breakfast", "work", "dinner", "supper", "rest", "pick_flowers", "tend_field"
]


func _parse(text: String, from_minute := DayPlanAnswer.EARLIEST_MINUTE) -> Array[DayEntry]:
	return DayPlanAnswer.parse(text, _offered, SUNRISE, SUNSET, from_minute, _rules)


## An answer with an entry for each `[activity, time]`.
func _answer(entries: Array) -> String:
	var items: Array[String] = []
	for entry: Array in entries:
		items.append('{"activity": "%s", "at": "%s"}' % [entry[0], entry[1]])
	return '{"day": [%s]}' % ", ".join(items)


## "05:30 breakfast" for each entry.
func _text_of(entries: Array[DayEntry]) -> Array[String]:
	var lines: Array[String] = []
	for entry in entries:
		lines.append("%02d:%02d %s" % [entry.minute / 60, entry.minute % 60, entry.activity])
	return lines


func test_a_good_answer_is_taken_as_it_is() -> void:
	var text := (
		'{"day": [{"activity": "breakfast", "at": "05:30", "why": "before the milking"},'
		+ ' {"activity": "work", "at": "06:30", "why": "the barn needs mucking out"},'
		+ ' {"activity": "sleep", "at": "21:30"}]}'
	)
	var entries := _parse(text)
	assert_eq(_text_of(entries), ["05:30 breakfast", "06:30 work", "21:30 sleep"] as Array[String])
	assert_eq(entries[0].why, "before the milking")
	assert_eq(entries[2].why, "")
	assert_eq(entries[0].minutes, 0, "until the next entry")


func test_json_in_words_or_fences_is_found() -> void:
	var json := _answer([["breakfast", "05:30"], ["work", "06:30"], ["sleep", "21:30"]])
	var expected := ["05:30 breakfast", "06:30 work", "21:30 sleep"] as Array[String]
	assert_eq(
		_text_of(_parse("Here is the day:\n```json\n%s\n```\nHope it helps." % json)), expected
	)
	assert_eq(_text_of(_parse("Sure! " + json + " Anything else?")), expected)


func test_what_is_not_json_is_no_answer() -> void:
	for text in ["", "No plan today.", "{not json}", "}{", '{"day": "work"}', '{"plan": []}', "[]"]:
		assert_eq(_parse(text), [] as Array[DayEntry], text)


func test_an_unknown_activity_or_one_the_villager_does_not_have_is_dropped() -> void:
	var entries := _parse(
		_answer(
			[
				["breakfast", "05:30"],
				["flying", "06:00"],
				["milk", "06:30"],
				["work", "07:00"],
				["dinner", "12:00"],
				["sleep", "21:30"],
			]
		)
	)
	assert_eq(
		_text_of(entries),
		["05:30 breakfast", "07:00 work", "12:00 dinner", "21:30 sleep"] as Array[String]
	)


func test_an_activity_whose_day_or_season_does_not_hold_is_not_offered() -> void:
	var hinrich := Npc.create_villager("hinrich", Vector2.ZERO, VillagerRules.default_rules())
	var activities := VillagerActivities.of(
		hinrich, VillagerRules.default_rules(), NpcRules.default_rules(), _rules
	)
	var sunday := activities.on_day(SUNDAY, _rules)
	assert_does_not_have(sunday, "work", "not on a Sunday")
	var entries := DayPlanAnswer.parse(
		_answer(
			[
				["breakfast", "05:30"],
				["work", "06:30"],
				["go_to_church", "09:30"],
				["sleep", "21:30"]
			]
		),
		sunday,
		SUNRISE,
		SUNSET,
		DayPlanAnswer.EARLIEST_MINUTE,
		_rules
	)
	assert_eq(
		_text_of(entries), ["05:30 breakfast", "09:30 go_to_church", "21:30 sleep"] as Array[String]
	)
	assert_does_not_have(activities.on_day(100, _rules), "water_field", "not in autumn")


func test_times_out_of_the_day_or_not_hh_mm_are_dropped() -> void:
	var entries := _parse(
		_answer(
			[
				["breakfast", "03:50"],
				["breakfast", "05:30"],
				["work", "6:30"],
				["work", "0700"],
				["work", "25:00"],
				["work", "noon"],
				["dinner", "12:00"],
				["rest", "23:45"],
				["supper", "18:00"],
				["rest", "23:30"],
			]
		)
	)
	assert_eq(
		_text_of(entries),
		(
			["05:30 breakfast", "12:00 dinner", "18:00 supper", "23:30 rest", "23:50 sleep"]
			as Array[String]
		),
		"the last start of the day is 23:30; a sleep goes after it"
	)


func test_entries_are_put_in_time_order() -> void:
	var entries := _parse(
		_answer([["dinner", "12:00"], ["sleep", "21:30"], ["breakfast", "05:30"]])
	)
	assert_eq(
		_text_of(entries), ["05:30 breakfast", "12:00 dinner", "21:30 sleep"] as Array[String]
	)


func test_an_entry_too_close_to_the_one_before_is_dropped() -> void:
	var entries := _parse(
		_answer(
			[
				["breakfast", "05:30"],
				["work", "05:45"],
				["work", "05:50"],
				["work", "06:30"],
				["dinner", "12:00"],
				["sleep", "21:30"],
			]
		)
	)
	assert_eq(
		_text_of(entries),
		(
			["05:30 breakfast", "05:50 work", "06:30 work", "12:00 dinner", "21:30 sleep"]
			as Array[String]
		)
	)


func test_at_most_max_entries_stay_and_the_sleep_is_among_them() -> void:
	var items: Array = []
	for hour in range(5, 20):
		items.append(["rest", "%02d:00" % hour])
	var entries := _parse(_answer(items))
	assert_eq(entries.size(), int(_rules.number("max_entries")))
	assert_eq(entries.back().activity, "sleep", "added, though the cap cut the rest")
	assert_eq(entries.front().minute, 5 * 60)


func test_fewer_than_three_valid_entries_is_no_answer() -> void:
	assert_eq(_parse(_answer([["breakfast", "05:30"], ["work", "06:30"]])), [] as Array[DayEntry])
	assert_eq(
		_parse(_answer([["breakfast", "05:30"], ["flying", "06:30"], ["work", "09:00"]])),
		[] as Array[DayEntry],
		"two valid ones"
	)
	assert_eq(
		_parse(_answer([["breakfast", "05:30"], ["work", "06:30"], ["rest", "20:00"]])).size(), 4
	)


func test_a_whole_day_gets_a_sleep_at_its_usual_time_when_there_is_none() -> void:
	var entries := _parse(_answer([["breakfast", "05:30"], ["work", "06:30"], ["rest", "18:00"]]))
	assert_eq(_text_of(entries).back(), "21:30 sleep")
	var late := _parse(_answer([["breakfast", "05:30"], ["work", "06:30"], ["rest", "21:20"]]))
	assert_eq(_text_of(late).back(), "21:40 sleep", "not closer to the rest than the gap allows")


func test_an_activity_that_needs_light_is_dropped_at_night() -> void:
	var entries := _parse(
		_answer(
			[
				["breakfast", "05:30"],
				["tend_field", "05:40"],
				["tend_field", "06:00"],
				["work", "07:00"],
				["tend_field", "21:00"],
				["tend_field", "22:30"],
				["sleep", "22:45"],
			]
		)
	)
	assert_eq(
		_text_of(entries),
		["05:30 breakfast", "06:00 tend_field", "07:00 work", "22:45 sleep"] as Array[String],
		"from sunrise to sunset, not at sunset itself"
	)


func test_the_why_is_cut_and_a_why_that_is_no_text_is_none() -> void:
	var long := "x".repeat(100)
	var text := (
		'{"day": [{"activity": "breakfast", "at": "05:30", "why": "%s"},' % long
		+ ' {"activity": "work", "at": "06:30", "why": 7},'
		+ ' {"activity": "sleep", "at": "21:30", "why": "  tired  "}]}'
	)
	var entries := _parse(text)
	assert_eq(entries[0].why.length(), DayPlanAnswer.MAX_WHY_LENGTH)
	assert_eq(entries[1].why, "")
	assert_eq(entries[2].why, "tired")


func test_items_that_are_no_entries_are_dropped() -> void:
	var text := (
		'{"day": ["work", 3, {"at": "06:30"}, {"activity": 5, "at": "06:30"},'
		+ ' {"activity": "work"}, {"activity": "breakfast", "at": "05:30"},'
		+ ' {"activity": "work", "at": "06:30"}, {"activity": "sleep", "at": "21:30"}]}'
	)
	assert_eq(
		_text_of(_parse(text)), ["05:30 breakfast", "06:30 work", "21:30 sleep"] as Array[String]
	)


# --- The rest of a day ---


func test_a_plan_for_the_rest_of_the_day_starts_no_earlier_than_it_was_asked() -> void:
	var asked_at := 14 * 60 + 20
	var entries := _parse(
		_answer(
			[["work", "13:00"], ["rest", "14:19"], ["pick_flowers", "15:00"], ["supper", "18:00"]]
		),
		asked_at
	)
	assert_eq(_text_of(entries), ["15:00 pick_flowers", "18:00 supper"] as Array[String])


func test_one_valid_entry_is_enough_for_the_rest_of_the_day_and_no_sleep_is_added() -> void:
	var entries := _parse(_answer([["supper", "18:00"]]), 14 * 60)
	assert_eq(_text_of(entries), ["18:00 supper"] as Array[String])
	assert_eq(_parse(_answer([["supper", "13:00"]]), 14 * 60), [] as Array[DayEntry])
