extends GutTest
## The day a villager has when no model planned one (DefaultDay), the kinds of a day, and the entry
## that is on (DayEntry `on`).

const MONDAY := 1
const SATURDAY := 6
const SUNDAY := 7
const EASTER := 14
const CHRISTMAS := 140
const SUMMER_MONDAY := 36
const AUTUMN_MONDAY := 71
const SEED := 7

var _villagers := VillagerRules.default_rules()
var _rules := ActivityRules.default_rules()
## The same without the spread, so that the entries are at their default times.
var _exact_rules: ActivityRules


func before_each() -> void:
	var values := DataFile.read_sections(ActivityRules.DEFAULT_PATH)
	values["rules"]["spread_minutes"] = 0
	_exact_rules = ActivityRules.new(values)


func _written(id: String) -> Npc:
	var npc := Npc.create_villager(id, Vector2.ZERO, _villagers)
	npc.house = Building.new(BuildingTypes.KATE, Vector2i.ZERO)
	return npc


func _activities_of(npc: Npc) -> VillagerActivities:
	return VillagerActivities.of(npc, _villagers, NpcRules.default_rules(), _rules)


func _day_of(npc: Npc, day: int, rules := _exact_rules) -> Array[DayEntry]:
	return DefaultDay.of(npc, _activities_of(npc), day, SEED, rules)


## "05:30 breakfast" for each entry.
func _text_of(entries: Array[DayEntry]) -> Array[String]:
	var lines: Array[String] = []
	for entry in entries:
		lines.append("%02d:%02d %s" % [entry.minute / 60, entry.minute % 60, entry.activity])
	return lines


# --- The day of each kind of villager ---


func test_a_farmer_s_weekday_in_spring() -> void:
	assert_eq(
		_text_of(_day_of(_written("hinrich"), MONDAY)),
		(
			[
				"05:30 breakfast",
				"06:30 work",
				"12:00 dinner",
				"13:00 work",
				"17:00 water_field",
				"18:00 supper",
				"20:00 rest",
				"21:30 sleep",
			]
			as Array[String]
		)
	)


func test_a_farmer_s_saturday_ends_at_the_krug() -> void:
	var lines := _text_of(_day_of(_written("hinrich"), SATURDAY))
	assert_has(lines, "18:30 meet_at_the_krug")
	assert_does_not_have(lines, "20:00 rest", "the Krug runs till bedtime")
	assert_eq(lines.back(), "21:30 sleep")


func test_a_farmer_s_sunday_is_church_and_no_work() -> void:
	assert_eq(
		_text_of(_day_of(_written("hinrich"), SUNDAY)),
		(
			[
				"05:30 breakfast",
				"09:30 go_to_church",
				"12:00 dinner",
				"15:00 pick_flowers",
				"17:00 water_field",
				"18:00 supper",
				"20:00 rest",
				"21:30 sleep",
			]
			as Array[String]
		)
	)


func test_in_autumn_there_is_no_watering_and_no_flowers() -> void:
	assert_eq(
		_text_of(_day_of(_written("hinrich"), AUTUMN_MONDAY)),
		(
			[
				"05:30 breakfast",
				"06:30 work",
				"12:00 dinner",
				"13:00 work",
				"18:00 supper",
				"20:00 rest",
				"21:30 sleep",
			]
			as Array[String]
		)
	)
	assert_has(_text_of(_day_of(_written("hinrich"), SUMMER_MONDAY)), "17:00 water_field")


func test_a_keeper_of_the_house_milks_twice_and_picks_flowers_in_the_afternoon() -> void:
	assert_eq(
		_text_of(_day_of(_written("antje"), MONDAY)),
		(
			[
				"05:00 milk",
				"05:30 breakfast",
				"08:00 tend_animals",
				"12:00 dinner",
				"14:00 tend_animals",
				"15:00 pick_flowers",
				"17:30 milk",
				"18:00 supper",
				"20:00 rest",
				"21:30 sleep",
			]
			as Array[String]
		)
	)


func test_a_fisher_mends_nets_over_the_afternoon_s_work() -> void:
	var lines := _text_of(_day_of(_written("inken"), MONDAY))
	assert_has(lines, "14:00 mend_nets")
	assert_eq(lines.count("13:00 work"), 1)


func test_a_made_up_villager_has_the_day_of_their_trade() -> void:
	var npc := Npc.create(7, Vector2.ZERO, NpcRules.default_rules())
	npc.house = Building.new(BuildingTypes.KATE, Vector2i.ZERO)
	var lines := _text_of(_day_of(npc, MONDAY))
	assert_has(lines, "21:30 sleep")
	assert_has(lines, "05:30 breakfast")


func test_every_written_villager_has_a_sleep_and_entries_in_time_order_every_day_of_a_year(
) -> void:
	for id in _villagers.ids():
		var npc := _written(id)
		for day in GameClock.DAYS_PER_YEAR:
			var entries := _day_of(npc, day + 1, _rules)
			assert_true(
				entries.any(func(entry: DayEntry) -> bool: return entry.activity == "sleep")
			)
			assert_lte(entries.size(), int(_rules.number("max_entries")))
			for index in range(1, entries.size()):
				assert_gte(
					entries[index].minute - entries[index - 1].minute, 20, "%s %d" % [id, day]
				)


# --- Church on the feasts ---


func test_momme_goes_to_church_at_easter_and_christmas_only() -> void:
	var momme := _written("momme")
	assert_does_not_have(_text_of(_day_of(momme, SUNDAY)), "09:30 go_to_church")
	assert_has(_text_of(_day_of(momme, EASTER)), "09:30 go_to_church")
	assert_has(_text_of(_day_of(momme, CHRISTMAS)), "09:30 go_to_church")
	assert_has(_text_of(_day_of(momme, EASTER + GameClock.DAYS_PER_YEAR)), "09:30 go_to_church")


func test_the_others_go_to_church_every_sunday() -> void:
	assert_has(_text_of(_day_of(_written("antje"), SUNDAY)), "09:30 go_to_church")
	assert_does_not_have(_text_of(_day_of(_written("antje"), MONDAY)), "09:30 go_to_church")


# --- Extras and skips, no house ---


func test_an_extra_activity_is_in_the_day() -> void:
	assert_has(_text_of(_day_of(_written("kerrin"), SUNDAY)), "14:00 visit_friend")
	assert_does_not_have(_text_of(_day_of(_written("antje"), SUNDAY)), "14:00 visit_friend")


func test_a_skipped_activity_is_not_in_the_day() -> void:
	var sheets := DataFile.read_sections(VillagerRules.DEFAULT_PATH)
	sheets["antje"][VillagerRules.SKIPS_KEY] = ["go_to_church"]
	var villagers := VillagerRules.new(sheets)
	var npc := Npc.create_villager("antje", Vector2.ZERO, villagers)
	npc.house = Building.new(BuildingTypes.KATE, Vector2i.ZERO)
	var activities := VillagerActivities.of(npc, villagers, NpcRules.default_rules(), _rules)
	var entries := DefaultDay.of(npc, activities, SUNDAY, SEED, _exact_rules)
	assert_does_not_have(_text_of(entries), "09:30 go_to_church")


func test_a_day_always_has_a_sleep_even_when_the_sheet_skips_it() -> void:
	var sheets := DataFile.read_sections(VillagerRules.DEFAULT_PATH)
	sheets["antje"][VillagerRules.SKIPS_KEY] = ["sleep"]
	var villagers := VillagerRules.new(sheets)
	var npc := Npc.create_villager("antje", Vector2.ZERO, villagers)
	npc.house = Building.new(BuildingTypes.KATE, Vector2i.ZERO)
	var activities := VillagerActivities.of(npc, villagers, NpcRules.default_rules(), _rules)
	var lines := _text_of(DefaultDay.of(npc, activities, MONDAY, SEED, _exact_rules))
	assert_eq(lines.back(), "21:30 sleep")


func test_a_villager_with_no_house_has_no_entries() -> void:
	var npc := _written("antje")
	npc.house = null
	assert_eq(_day_of(npc, MONDAY), [] as Array[DayEntry])


# --- Crowding ---


func test_of_two_entries_close_together_the_higher_priority_stays() -> void:
	var values := DataFile.read_sections(ActivityRules.DEFAULT_PATH)
	values["rules"]["spread_minutes"] = 0
	values["rules"]["min_gap_minutes"] = 40
	var lines := _text_of(_day_of(_written("antje"), MONDAY, ActivityRules.new(values)))
	assert_does_not_have(lines, "05:00 milk", "breakfast is 30 minutes after it")
	assert_does_not_have(lines, "17:30 milk", "supper is 30 minutes after it")
	assert_has(lines, "05:30 breakfast")
	assert_has(lines, "18:00 supper")


# --- The spread ---


func test_the_same_inputs_give_the_same_day() -> void:
	var first := _text_of(_day_of(_written("hinrich"), MONDAY, _rules))
	assert_eq(_text_of(_day_of(_written("hinrich"), MONDAY, _rules)), first)


func test_the_offset_is_stable_and_within_the_spread() -> void:
	var offsets := {}
	for day in 60:
		var offset := DefaultDay.offset_minutes("Antje Boysen", day, SEED, _rules)
		assert_between(offset, 0, int(_rules.number("spread_minutes")))
		assert_eq(DefaultDay.offset_minutes("Antje Boysen", day, SEED, _rules), offset)
		offsets[offset] = true
	assert_gt(offsets.size(), 3, "it varies with the day")


func test_every_entry_of_a_day_is_moved_by_the_same_offset() -> void:
	var npc := _written("hinrich")
	var offset := DefaultDay.offset_minutes(npc.name, MONDAY, SEED, _rules)
	var exact := _day_of(npc, MONDAY)
	var spread := _day_of(npc, MONDAY, _rules)
	assert_eq(spread.size(), exact.size())
	for index in exact.size():
		assert_eq(spread[index].minute, exact[index].minute + offset)
		assert_eq(spread[index].activity, exact[index].activity)
