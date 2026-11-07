extends ResourceCase
## Villagers written by hand, spawned by id from the console: `spawn npc antje` or `spawn antje`.

var _console: Console


func before_each() -> void:
	super.before_each()
	_console = Console.new(_state)


func test_family_and_friends_can_be_spawned() -> void:
	assert_eq(_console.run("spawn npc hinrich"), ["Spawned Hinrich Boysen"] as Array[String])
	assert_eq(_console.run("spawn npc inken"), ["Spawned Inken Ketels"] as Array[String])


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


func test_spawn_takes_a_villager_s_id_without_npc() -> void:
	assert_eq(_console.run("spawn kerrin"), ["Spawned Kerrin Paulsen"] as Array[String])
	assert_not_null(_state.npcs.find("kerrin"))


func test_tab_completes_a_villager_s_id_right_after_spawn() -> void:
	assert_eq(_console.complete("spawn ke"), "spawn kerrin ")
	assert_eq(_console.complete("spawn co"), "spawn cow ")


func test_tab_on_an_empty_line_offers_the_commands() -> void:
	assert_eq(_console.complete(""), "")
	assert_eq(_console.complete("sp"), "spawn ")


func test_no_villager_s_id_is_taken_by_an_animal_or_npc() -> void:
	var animals := _console.candidates(&"animal")
	for id in _state.npcs.villagers.ids():
		assert_false(animals.has(id), "%s is also an animal" % id)
