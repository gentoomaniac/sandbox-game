extends GutTest
## The rules, the catalog and the pictures that ship with the game are valid (see RulesCheck).

## What each rules family's `_default` was before a test swapped a broken one in, by class.
var _shipped := {}


func after_each() -> void:
	for family: GDScript in _shipped:
		family.set("_default", _shipped[family])
	_shipped.clear()


## The name of the check, the family and a broken instance of it, for each rules file the checks
## must cover.
func _broken_families() -> Array:
	var broken_plan := VillagePlan.new()
	broken_plan._parse_problems = ["no plan"] as Array[String]
	return [
		[&"activities", ActivityRules, ActivityRules.new({})],
		[&"quests", QuestRules, QuestRules.new({}, {}, ["no quests"] as Array[String])],
		[&"friendship", FriendshipRules, FriendshipRules.new({})],
		[&"prices", Prices, Prices.new({})],
		[&"shops", ShopRules, ShopRules.new({"stray": {}})],
		[&"barter", BarterRules, BarterRules.new({})],
		[&"stall", StallRules, StallRules.new({})],
		[&"music", MusicRules, MusicRules.new({})],
		[&"attributes", AttributeRules, AttributeRules.new({})],
		[&"crop_raids", CropRaidRules, CropRaidRules.new({})],
		[&"flowers", FlowerRules, FlowerRules.new({})],
		[&"footprints", FootprintRules, FootprintRules.new({})],
		[&"gossip", GossipRules, GossipRules.new({})],
		[&"leaf_fall", LeafFallRules, LeafFallRules.new({})],
		[&"lighting", LightingRules, LightingRules.new({})],
		[&"spread", SpreadRules, SpreadRules.new({})],
		[&"stork_nests", StorkNestRules, StorkNestRules.new({})],
		[&"tool_grades", ToolGradeRules, ToolGradeRules.new({})],
		[&"tool_swings", ToolSwingRules, ToolSwingRules.new({})],
		[&"weather", WeatherRules, WeatherRules.new({})],
		[&"yard", YardRules, YardRules.new({})],
		[&"wild_seeds", WildSeeds, WildSeeds.new({"stray": {}})],
		[&"village_plan", VillagePlan, broken_plan],
	]


func test_the_shipped_rules_catalog_and_pictures_are_valid() -> void:
	assert_true(RulesCheck.is_everything_valid())


func test_a_broken_rules_file_of_each_family_is_refused() -> void:
	var checks := RulesCheck.checks()
	for entry: Array in _broken_families():
		var check_name: StringName = entry[0]
		var family: GDScript = entry[1]
		_shipped[family] = family.get("_default")
		family.set("_default", entry[2])
		assert_false(checks[check_name].call(), check_name)
		family.set("_default", _shipped[family])


func test_every_check_runs_even_when_an_earlier_one_fails() -> void:
	var ran: Array[String] = []
	var failing := func() -> bool:
		ran.append("failing")
		return false
	var passing := func() -> bool:
		ran.append("passing")
		return true
	assert_false(RulesCheck.all_pass([failing, passing]))
	assert_eq(ran, ["failing", "passing"] as Array[String])


func test_every_family_has_a_check() -> void:
	assert_eq(RulesCheck.missing_families(RulesCheck.checks().keys()), [] as Array[StringName])


func test_a_family_with_no_check_is_found() -> void:
	var registered := RulesCheck.checks().keys()
	registered.erase(&"quests")
	assert_eq(RulesCheck.missing_families(registered), [&"quests"] as Array[StringName])
