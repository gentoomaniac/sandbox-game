extends GutTest
## The sheets the system line of a reply carries (NpcPrompt `system_text`): the village's
## (data/village.cfg) and the villager's, in full for a hosted model and cut down for a local one.

var _rules := NpcTalkRules.default_rules()
var _antje := Npc.create_villager("antje", Vector2.ZERO, VillagerRules.default_rules())


func test_the_system_line_has_the_village_sheet_and_the_villager_s() -> void:
	var system := NpcPrompt.system_text(_antje, true, _rules)
	assert_string_contains(system, "Never make up relatives, friends, names or places")
	assert_string_contains(system, VillageSheet.default_sheet().text(true))
	assert_string_contains(system, "The villager's sheet:\nAntje Boysen, a farmer's wife, 38 years")
	assert_string_contains(system, "Home: The Boysen farm on its Warft")
	assert_string_contains(system, "Family and friends: Hinrich Boysen, husband, 42: Steady")
	assert_string_contains(system, "Boy Boysen, son, 19: ")
	assert_string_contains(
		system,
		(
			'Sample lines, for the manner only: "Rain again? Then the hay waits, and so do I."'
			+ ' "My Hinrich says the dyke will hold'
		),
		"the lines quoted, one after the other"
	)
	assert_string_contains(system, "Secrets, at most hinted at: She has put")


func test_the_cut_down_sheets_keep_the_essentials_and_are_much_shorter() -> void:
	var full := NpcPrompt.system_text(_antje, true, _rules)
	var cut_down := NpcPrompt.system_text(_antje, false, _rules)
	assert_lt(cut_down.length() * 2, full.length())
	assert_string_contains(cut_down, VillageSheet.default_sheet().text(false))
	assert_string_contains(
		cut_down,
		"Family and friends: Hinrich Boysen (husband), Boy Boysen (son), Gesche Hansen (friend)\n"
	)
	assert_string_contains(cut_down, "How Antje talks: Talks quickly and warmly")
	assert_string_contains(
		cut_down, 'for the manner only: "Rain again? Then the hay waits, and so do I."'
	)
	assert_false(cut_down.contains("My Hinrich says the dyke"), "only one sample line")
	assert_false(cut_down.contains("Secrets"))


func test_a_made_up_villager_has_no_people_of_the_village() -> void:
	var npc := Npc.create(7, Vector2.ZERO, NpcRules.default_rules())
	var system := NpcPrompt.system_text(npc, false, _rules)
	assert_string_contains(
		system,
		(
			"Family and friends: none in the village; %s knows its families only by sight"
			% npc.name.get_slice(" ", 0)
		)
	)
	assert_string_contains(system, npc.speech)


func test_people_no_longer_written_are_left_out() -> void:
	var npc := Npc.create_villager("antje", Vector2.ZERO, VillagerRules.default_rules())
	npc.people = {"nobody": ["friend", "Gone."], "boy": ["son", "Proud."]}
	assert_eq(NpcPrompt.people_text(npc, false, _rules), "Family and friends: Boy Boysen (son)")


func test_a_line_of_people_all_gone_from_the_data_file_is_left_out() -> void:
	var npc := Npc.create_villager("antje", Vector2.ZERO, VillagerRules.default_rules())
	npc.people = {"nobody": ["friend", "Gone."]}
	assert_eq(NpcPrompt.people_text(npc, true, _rules), "")
	var sheet := NpcPrompt.system_text(npc, true, _rules).split("\n\n")[2]
	assert_false(sheet.contains("Family and friends"))
	assert_false(sheet.contains("\n\n"), "no empty line where it was")
	assert_string_contains(sheet, "sandy lanes.\nHome: ")
