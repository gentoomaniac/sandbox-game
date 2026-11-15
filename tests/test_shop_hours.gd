extends GutTest
## The shop hours of a shopkeeper (the set `shopkeeper`, the activity `keep_shop`): the default
## day on a weekday, Saturday and Sunday. No sheet has the set until Trienke's.

const MONDAY := 1
const SATURDAY := 6
const SUNDAY := 7
const SEED := 7

var _rules: ActivityRules


func before_each() -> void:
	var values := DataFile.read_sections(ActivityRules.DEFAULT_PATH)
	# No spread, so that the entries are at their default times.
	values["rules"]["spread_minutes"] = 0
	_rules = ActivityRules.new(values)


func _day_of_a_shopkeeper(day: int) -> Array[String]:
	var npc := Npc.create_villager("antje", Vector2.ZERO, VillagerRules.default_rules())
	npc.house = Building.new(BuildingTypes.KATE, Vector2i.ZERO)
	var activities := VillagerActivities.new()
	activities.ids.assign(_rules.set_activities("base") + _rules.set_activities("shopkeeper"))
	var lines: Array[String] = []
	for entry in DefaultDay.of(npc, activities, day, SEED, _rules):
		lines.append("%02d:%02d %s" % [entry.minute / 60, entry.minute % 60, entry.activity])
	return lines


func test_the_shop_is_fixed_and_the_rest_is_not() -> void:
	assert_true(_rules.is_fixed("keep_shop"))
	assert_false(_rules.is_fixed("work"))
	var values := DataFile.read_sections(ActivityRules.DEFAULT_PATH)
	values["keep_shop"]["fixed"] = "yes"
	assert_eq(ActivityRules.new(values).problems().size(), 1, "fixed is true or false")


func test_the_shop_is_open_from_seven_to_noon_and_one_to_six() -> void:
	assert_eq(
		_day_of_a_shopkeeper(MONDAY),
		(
			[
				"05:30 breakfast",
				"07:00 keep_shop",
				"12:00 dinner",
				"13:00 keep_shop",
				"18:00 supper",
				"20:00 rest",
				"21:30 sleep",
			]
			as Array[String]
		)
	)


func test_the_shop_is_open_on_saturday_and_the_keeper_goes_to_the_krug_after() -> void:
	var lines := _day_of_a_shopkeeper(SATURDAY)
	assert_has(lines, "07:00 keep_shop")
	assert_has(lines, "13:00 keep_shop")
	assert_has(lines, "18:30 meet_at_the_krug")


func test_the_shop_is_shut_on_sunday() -> void:
	var lines := _day_of_a_shopkeeper(SUNDAY)
	assert_false(lines.any(func(line: String) -> bool: return "keep_shop" in line))
	assert_has(lines, "09:30 go_to_church")
