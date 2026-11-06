extends ResourceCase
## Who the villagers are: those written by hand in data/villagers.cfg, spawned by id from the
## console, and the background a made-up villager draws from the tables of data/npcs.cfg.

var _console: Console


func before_each() -> void:
	super.before_each()
	_console = Console.new(_state)


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
	assert_eq(VillagerRules.new({}).problems(), ["no villagers"] as Array[String])


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


func test_a_made_up_villager_has_a_trade_of_their_sex_and_a_background() -> void:
	var file := ConfigFile.new()
	file.load(NpcRules.DEFAULT_PATH)
	for seed_value in 30:
		var npc := Npc.create(seed_value, Vector2.ZERO, _state.npcs.rules)
		assert_eq(npc.id, "")
		assert_has(file.get_value(str(npc.sex), "trades"), npc.trade)
		assert_between(npc.age, 18, 70)
		assert_false(npc.personality.is_empty())
		assert_false(npc.habits.is_empty())
		assert_false(npc.background.contains("{"), "the spouse's name is filled in")
		assert_string_contains(npc.background, "Worries")


func test_the_same_seed_gives_the_same_background() -> void:
	var first := Npc.create(7, Vector2.ZERO, _state.npcs.rules)
	var second := Npc.create(7, Vector2.ZERO, _state.npcs.rules)
	assert_eq(
		[first.age, first.trade, first.background], [second.age, second.trade, second.background]
	)


func test_missing_background_tables_are_reported() -> void:
	var problems := NpcRules.new({"background": {"ages": [40, 20]}}).problems()
	assert_has(problems, "[background] worries is not a list of at least one")
	assert_has(problems, "[female] trades is not a list of at least one")
	assert_has(problems, "[background] ages is not [youngest, oldest]")


# --- Spawned by id ---


func test_spawn_npc_with_an_id_puts_that_villager_near_the_player() -> void:
	assert_eq(_console.run("spawn npc antje"), ["Spawned Antje Boysen"] as Array[String])
	var antje := _state.npcs.find("antje")
	assert_not_null(antje)
	assert_lte(antje.position.distance_to(_state.player.position), Npcs.SPAWN_DISTANCE.y)
	assert_eq(_state.npcs.all().size(), 1)


func test_a_villager_written_by_hand_comes_only_once() -> void:
	_console.run("spawn npc kerrin")
	assert_eq(_console.run("spawn npc kerrin"), ["Kerrin Paulsen is already here"] as Array[String])
	assert_eq(_state.npcs.all().size(), 1)


func test_an_unknown_villager_is_named_and_the_ids_follow() -> void:
	var lines := _console.run("spawn npc nobody")
	assert_eq(lines[0], "Unknown villager: nobody")
	assert_string_contains("\n".join(lines), "antje")
	assert_eq(_state.npcs.all().size(), 0)


func test_a_count_still_makes_up_villagers() -> void:
	assert_eq(_console.run("spawn npc 2"), ["Spawned 2 of 2 npc"] as Array[String])
	for npc in _state.npcs.all():
		assert_eq(npc.id, "")


func test_tab_completes_the_ids_after_spawn_npc() -> void:
	assert_eq(_console.complete("spawn npc an"), "spawn npc antje ")
	assert_eq(_console.complete("spawn npc k"), "spawn npc kerrin ")
	assert_eq(_console.complete("spawn cow a"), "spawn cow a", "a count after an animal")
	assert_string_contains("\n".join(_console.run("spawn")), "villager: antje, momme")
	assert_string_contains("\n".join(_console.run("help spawn")), "antje")
