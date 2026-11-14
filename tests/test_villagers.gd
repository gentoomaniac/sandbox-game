extends ResourceCase
## Who the villagers are: those written by hand in data/villagers.cfg and the background a
## made-up villager draws from the tables of data/npcs.cfg. Spawning them by id is tested in
## test_spawn_villagers.

# --- The villagers written by hand ---


func test_the_data_file_is_valid() -> void:
	var villagers := VillagerRules.default_rules()
	assert_true(villagers.is_valid(), "problems: %s" % [villagers.problems()])
	assert_has(villagers.ids(), "antje")


func test_what_is_missing_or_wrong_is_reported() -> void:
	var villagers := (
		VillagerRules
		. new(
			{
				"anna": {"name": "Anna", "sex": "female", "age": 30, "look": {"body": "green"}},
				"boy": {"sex": "boy", "age": "old", "look": {}},
			}
		)
	)
	var problems := villagers.problems()
	assert_has(problems, "[anna] trade is not a text")
	assert_has(problems, "[anna] look: no body green")
	assert_has(problems, "[boy] name is not a text")
	assert_has(problems, "[boy] sex is not one of %s" % [NpcRules.SEXES])
	assert_has(problems, "[boy] age is not a whole number of years")
	assert_has(problems, "[boy] look has no body")
	assert_has(problems, "[anna] samples is not a list of 2 or more lines")
	assert_has(problems, "[anna] people is not a dictionary of [kind, what they think]")
	assert_eq(VillagerRules.new({}).problems(), ["no villagers"] as Array[String])


func test_family_and_friends_are_villagers_who_name_each_other_back() -> void:
	var villagers := VillagerRules.default_rules()
	for id in villagers.ids():
		for other: String in villagers.villager(id)["people"]:
			assert_true(villagers.has(other), "%s names %s" % [id, other])
			assert_has(villagers.villager(other)["people"], id, "%s names %s back" % [other, id])
	assert_eq(villagers.villager("antje")["people"]["hinrich"][0], "husband")
	assert_eq(villagers.villager("hinrich")["people"]["antje"][0], "wife")
	assert_eq(villagers.villager("gesche")["people"]["kerrin"][0], "aunt")


func test_relations_that_disagree_are_reported() -> void:
	var villagers := (
		VillagerRules
		. new(
			{
				"antje":
				_villager(
					"female",
					38,
					"the farm",
					{
						"hinrich": ["husband", "Steady."],
						"boy": ["son", "Her pride."],
						"nobody": ["friend", "Who?"],
					}
				),
				"hinrich": _villager("male", 42, "the mill", {"antje": ["sister", "Odd."]}),
				"boy": _villager("female", 30, "the farm", {"antje": ["mother", "Kind."]}),
			}
		)
	)
	var problems := villagers.problems()
	assert_has(problems, '[antje] people: hinrich does not name antje back as one of ["wife"]')
	assert_has(problems, "[antje] people: hinrich does not have the same home as their wife")
	assert_has(problems, "[antje] people: boy is not of the sex of a son")
	assert_has(problems, "[antje] people: nobody is not another villager")
	assert_has(problems, "[boy] people: antje is not 15 years older than their child")
	assert_eq(
		problems.size(), 6, "and antje does not name hinrich back as her brother: %s" % [problems]
	)


func test_the_sheets_name_the_house_and_the_workplace_they_have() -> void:
	var villagers := VillagerRules.default_rules()
	assert_eq(villagers.villager("antje")[VillagerRules.HOME_BUILDING_KEY], "hall_house")
	assert_eq(villagers.villager("hinrich")[VillagerRules.WORKPLACE_BUILDING_KEY], "barn")
	assert_eq(
		villagers.villager("momme")[VillagerRules.WORKPLACE_SPOT_KEY], "the landing at the sluice"
	)
	assert_false(villagers.villager("ocke").has(VillagerRules.HOME_BUILDING_KEY))


func test_a_house_or_workplace_that_is_not_a_building_is_reported() -> void:
	var anna := _villager("female", 30, "the farm", {})
	anna[VillagerRules.HOME_BUILDING_KEY] = "barn"
	anna[VillagerRules.WORKPLACE_BUILDING_KEY] = "castle"
	anna[VillagerRules.WORKPLACE_SPOT_KEY] = "the landing"
	var problems := VillagerRules.new({"anna": anna}).problems()
	assert_has(problems, "[anna] home_building is not a building with room for residents")
	assert_has(problems, "[anna] workplace_building is not a building")
	assert_has(problems, "[anna] has both a workplace_building and a workplace_spot")


func test_a_couple_names_the_same_house() -> void:
	var antje := _villager("female", 38, "the farm", {"hinrich": ["husband", "Steady."]})
	var hinrich := _villager("male", 42, "the farm", {"antje": ["wife", "Warm."]})
	antje[VillagerRules.HOME_BUILDING_KEY] = "hall_house"
	hinrich[VillagerRules.HOME_BUILDING_KEY] = "kate"
	var problems := VillagerRules.new({"antje": antje, "hinrich": hinrich}).problems()
	assert_has(
		problems, "[antje] people: hinrich does not have the same home_building as their wife"
	)


func test_a_missing_file_is_reported() -> void:
	var villagers := VillagerRules.from_file("res://data/no_such_file.cfg")
	assert_push_error_count(2)
	assert_false(villagers.is_valid())


func test_antje_is_the_farmer_s_wife_as_written() -> void:
	var antje := Npc.create_villager("antje", Vector2(1, 2), VillagerRules.default_rules())
	assert_eq(antje.id, "antje")
	assert_eq(antje.name, "Antje Boysen")
	assert_eq(antje.sex, NpcRules.FEMALE)
	assert_eq(antje.age, 38)
	assert_eq(antje.trade, "a farmer's wife")
	assert_string_contains(antje.background, "Hinrich")
	assert_false(antje.personality.is_empty())
	assert_false(antje.habits.is_empty())
	assert_eq(antje.position, Vector2(1, 2))
	var slots := antje.appearance.layers.map(
		func(layer: Dictionary) -> StringName: return layer.slot
	)
	assert_eq(slots, [&"body", &"legs", &"feet", &"clothes", &"apron", &"hair", &"head"])


# --- Made up from the tables ---


func test_a_made_up_villager_has_a_trade_of_their_sex_and_a_sheet() -> void:
	var file := ConfigFile.new()
	file.load(NpcRules.DEFAULT_PATH)
	for seed_value in 30:
		var npc := Npc.create(seed_value, Vector2.ZERO, _state.npcs.rules)
		assert_eq(npc.id, "")
		assert_has(file.get_value(str(npc.sex), "trades"), [npc.trade, npc.day])
		assert_between(npc.age, 18, 70)
		for text in [npc.personality, npc.home, npc.speech, npc.likes, npc.wants, npc.habits]:
			assert_false(text.is_empty())
		assert_false(npc.avoids.is_empty())
		assert_false(npc.secrets.is_empty())
		assert_gte(npc.samples.size(), 2)
		assert_eq(npc.people, {}, "no kin among the villagers written by hand")
		assert_false(npc.background.contains("{"), "the spouse's name is filled in")
		assert_string_contains(npc.background, "Worries")


func test_a_made_up_spouse_has_the_villager_s_surname() -> void:
	for seed_value in 30:
		var npc := Npc.create(seed_value, Vector2.ZERO, _state.npcs.rules)
		if npc.background.contains(" to "):
			assert_string_contains(npc.background, npc.name.get_slice(" ", 1))


func test_no_made_up_villager_has_a_surname_of_the_village_sheet() -> void:
	var village := VillageSheet.default_sheet().text(
		true, VillageSheet.default_sheet().topic_names()
	)
	var file := ConfigFile.new()
	file.load(NpcRules.DEFAULT_PATH)
	for surname: String in file.get_value("everyone", "surnames"):
		assert_false(village.contains(surname), "%s is a family of the village" % surname)


func test_the_same_seed_gives_the_same_background() -> void:
	var first := Npc.create(7, Vector2.ZERO, _state.npcs.rules)
	var second := Npc.create(7, Vector2.ZERO, _state.npcs.rules)
	assert_eq(first.to_dict(), second.to_dict())


func test_missing_background_tables_are_reported() -> void:
	var problems := NpcRules.new({"background": {"ages": [40, 20]}}).problems()
	assert_has(problems, "[background] worries is not a list of at least one")
	assert_has(problems, "[female] trades is not a list of at least one")
	assert_has(problems, "[background] ages is not [youngest, oldest]")


func test_trades_without_their_day_and_speeches_without_samples_are_reported() -> void:
	var values := DataFile.read_sections(NpcRules.DEFAULT_PATH)
	values["male"]["trades"] = ["a farmhand"]
	values["background"]["speeches"] = [["Talks fast.", ["Moin!"]]]
	assert_eq(
		NpcRules.new(values).problems(),
		(
			[
				"[male] trades is not a list of [trade, day]",
				"[background] speeches is not a list of [manner, [2 or more lines]]",
			]
			as Array[String]
		)
	)


## A villager written by hand with every key, of that sex, age, home and people.
func _villager(sex: String, age: int, home: String, people: Dictionary) -> Dictionary:
	var villager := {"sex": sex, "age": age, "look": {"body": "0"}, "samples": ["Moin.", "Hm."]}
	for key in VillagerRules.TEXT_KEYS:
		villager[key] = "Some words."
	villager["home"] = home
	villager["people"] = people
	return villager
