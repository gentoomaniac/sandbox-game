extends GutTest
## Which activities a villager has (VillagerActivities): `base`, the set of their work, the extras
## of their sheet, less its skips.

var _villagers := VillagerRules.default_rules()
var _npc_rules := NpcRules.default_rules()
var _rules := ActivityRules.default_rules()


func _activities_of(npc: Npc) -> VillagerActivities:
	return VillagerActivities.of(npc, _villagers, _npc_rules, _rules)


func _written(id: String) -> Npc:
	return Npc.create_villager(id, Vector2.ZERO, _villagers)


func test_a_farmer_has_base_and_the_farmers_activities() -> void:
	var ids := _activities_of(_written("hinrich")).ids
	for id in _rules.set_activities("base") + _rules.set_activities("farmer"):
		assert_has(ids, id)
	assert_does_not_have(ids, "milk")


func test_the_extras_of_a_sheet_are_added() -> void:
	assert_has(_activities_of(_written("kerrin")).ids, "visit_friend")
	assert_does_not_have(_activities_of(_written("antje")).ids, "visit_friend")


func test_what_a_sheet_skips_is_left_out() -> void:
	var sheets := DataFile.read_sections(VillagerRules.DEFAULT_PATH)
	sheets["antje"][VillagerRules.SKIPS_KEY] = ["go_to_church", "sleep"]
	var villagers := VillagerRules.new(sheets)
	var npc := Npc.create_villager("antje", Vector2.ZERO, villagers)
	var ids := VillagerActivities.of(npc, villagers, _npc_rules, _rules).ids
	assert_does_not_have(ids, "go_to_church")
	assert_does_not_have(ids, "sleep")
	assert_has(ids, "milk")


func test_each_activity_is_there_once() -> void:
	var ids := _activities_of(_written("hinrich")).ids
	var once := {}
	for id in ids:
		assert_false(once.has(id), "%s twice" % id)
		once[id] = true


func test_momme_goes_to_church_only_on_the_feasts() -> void:
	assert_true(_activities_of(_written("momme")).is_church_feasts_only)
	assert_false(_activities_of(_written("antje")).is_church_feasts_only)


func test_a_made_up_villager_has_the_set_of_their_trade() -> void:
	var npc := Npc.create(7, Vector2.ZERO, _npc_rules)
	var work_set := _npc_rules.work_set_of_trade(npc.trade)
	var ids := _activities_of(npc).ids
	for id in _rules.set_activities(work_set):
		assert_has(ids, id)


func test_a_trade_the_tables_do_not_have_gives_base_only() -> void:
	var npc := Npc.create(7, Vector2.ZERO, _npc_rules)
	npc.trade = "a pirate"
	assert_eq(_activities_of(npc).ids, _rules.set_activities("base"))


func test_each_of_the_eight_has_more_than_the_base() -> void:
	for id in _villagers.ids():
		var ids := _activities_of(_written(id)).ids
		assert_has(ids, "sleep")
		assert_gt(ids.size(), _rules.set_activities("base").size(), id)
