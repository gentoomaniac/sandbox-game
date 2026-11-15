extends GutTest
## An activity with no place for the villager is not in their default day (DefaultDay `of`).

const SUNDAY := 7
const SUMMER_MONDAY := 36
const SEED := 7

var _villagers := VillagerRules.default_rules()
var _rules: ActivityRules


func before_each() -> void:
	var values := DataFile.read_sections(ActivityRules.DEFAULT_PATH)
	values["rules"]["spread_minutes"] = 0
	_rules = ActivityRules.new(values)


## The day of the villager, as lines such as "05:30 breakfast", where `has_place` says which
## activities have a place.
func _day_of(villager_id: String, day: int, has_place: Callable) -> Array[String]:
	var npc := Npc.create_villager(villager_id, Vector2.ZERO, _villagers)
	npc.house = Building.new(BuildingTypes.KATE, Vector2i.ZERO)
	var activities := VillagerActivities.of(npc, _villagers, NpcRules.default_rules(), _rules)
	var lines: Array[String] = []
	for entry in DefaultDay.of(npc, activities, day, SEED, _rules, has_place):
		lines.append("%02d:%02d %s" % [entry.minute / 60, entry.minute % 60, entry.activity])
	return lines


func test_an_activity_with_no_place_for_the_villager_is_not_in_the_day() -> void:
	var has_place := func(activity: String) -> bool: return activity != "go_to_church"
	var lines := _day_of("antje", SUNDAY, has_place)
	assert_does_not_have(lines, "09:30 go_to_church")
	assert_has(lines, "12:00 dinner")


func test_an_activity_with_no_place_does_not_keep_another_out() -> void:
	var has_place := func(activity: String) -> bool: return activity != "work"
	var lines := _day_of("hinrich", SUMMER_MONDAY, has_place)
	assert_does_not_have(lines, "06:30 work")
	assert_has(lines, "15:00 pick_flowers", "it is no longer inside the work's time")
