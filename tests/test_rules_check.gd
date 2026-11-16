extends GutTest
## The rules, the catalog and the pictures that ship with the game are valid (see RulesCheck).

## What each rules family's `_default` was before a test swapped a broken one in, by class.
var _shipped := {}


func after_each() -> void:
	for family: GDScript in _shipped:
		family.set("_default", _shipped[family])
	_shipped.clear()


## The family and a broken instance of it for each rules file the check must cover.
func _broken_families() -> Array:
	var broken_plan := VillagePlan.new()
	broken_plan._parse_problems = ["no plan"] as Array[String]
	return [
		[ActivityRules, ActivityRules.new({})],
		[QuestRules, QuestRules.new({}, {}, ["no quests"] as Array[String])],
		[FriendshipRules, FriendshipRules.new({})],
		[Prices, Prices.new({})],
		[ShopRules, ShopRules.new({"stray": {}})],
		[BarterRules, BarterRules.new({})],
		[StallRules, StallRules.new({})],
		[MusicRules, MusicRules.new({})],
		[AttributeRules, AttributeRules.new({})],
		[CropRaidRules, CropRaidRules.new({})],
		[FlowerRules, FlowerRules.new({})],
		[FootprintRules, FootprintRules.new({})],
		[GossipRules, GossipRules.new({})],
		[LeafFallRules, LeafFallRules.new({})],
		[LightingRules, LightingRules.new({})],
		[SpreadRules, SpreadRules.new({})],
		[StorkNestRules, StorkNestRules.new({})],
		[ToolGradeRules, ToolGradeRules.new({})],
		[ToolSwingRules, ToolSwingRules.new({})],
		[WeatherRules, WeatherRules.new({})],
		[YardRules, YardRules.new({})],
		[WildSeeds, WildSeeds.new({"stray": {}})],
		[VillagePlan, broken_plan],
	]


func test_the_shipped_rules_catalog_and_pictures_are_valid() -> void:
	assert_true(RulesCheck.is_everything_valid())


func test_a_broken_rules_file_of_each_family_is_refused() -> void:
	for entry: Array in _broken_families():
		var family: GDScript = entry[0]
		_shipped[family] = family.get("_default")
		family.set("_default", entry[1])
		assert_false(RulesCheck.is_everything_valid(), "%s" % family.get_global_name())
		family.set("_default", _shipped[family])
