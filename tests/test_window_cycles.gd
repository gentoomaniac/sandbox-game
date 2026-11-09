extends GutTest
## Windows made, opened, closed and freed again and again leave no nodes behind: the count
## after the first round is the count after many.

const ROUNDS := 8

var _hotbar: HotbarHud
var _player: PlayerState


func before_each() -> void:
	_player = PlayerState.new()
	_hotbar = add_child_autofree(HotbarHud.new())
	_hotbar.show_inventory(_player.inventory)


func after_each() -> void:
	get_tree().paused = false


func _nodes() -> int:
	return int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))


func _orphans() -> int:
	return int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))


## Runs `cycle` once to warm caches up, then ROUNDS times, and checks the counts did not grow.
func _assert_settles(cycle: Callable) -> void:
	await cycle.call()
	var nodes := _nodes()
	var orphans := _orphans()
	for _round in ROUNDS:
		await cycle.call()
	assert_eq(_nodes(), nodes, "nodes after %d more rounds" % ROUNDS)
	assert_eq(_orphans(), orphans, "orphans after %d more rounds" % ROUNDS)


func test_storage_screens_opened_and_freed_leave_no_nodes() -> void:
	var chest := WorldObject.new(WorldObjectTypes.CHEST, Vector2i.ZERO)
	await _assert_settles(
		func() -> void:
			var screen := StorageScreen.new(_hotbar)
			add_child(screen)
			screen.open_chest(chest, _player)
			screen.close()
			screen.open_chest(chest, _player)
			remove_child(screen)
			screen.free()
	)
	assert_eq(_hotbar.layer, HotbarHud.IDLE_LAYER)


func test_character_screens_opened_and_freed_leave_no_nodes() -> void:
	await _assert_settles(
		func() -> void:
			var screen := CharacterScreen.new(_hotbar)
			add_child(screen)
			screen.show_player(_player)
			screen.open()
			remove_child(screen)
			screen.free()
	)
	assert_eq(_hotbar.layer, HotbarHud.IDLE_LAYER)


func test_chat_screens_with_an_answer_pending_leave_no_nodes() -> void:
	var state := GameState.new_game(1)
	var npc := Npc.create(5, state.player.position, state.npcs.rules)
	state.npcs.add(npc)
	var settings := GameSettings.new("user://test_chat/settings.cfg")
	var dialogue := NpcDialogue.new(settings, FakeChat.new())
	add_child_autofree(dialogue)
	await _assert_settles(
		func() -> void:
			var screen := ChatScreen.new()
			screen.dialogue = dialogue
			add_child(screen)
			screen.open_chat(npc, state)
			screen.say("Hello")
			remove_child(screen)
			screen.free()
			await wait_until(func() -> bool: return not npc.is_answering, 2.0)
	)
	assert_false(npc.is_answering)
	assert_gt(npc.chat_history.size(), 0, "the lines were answered with no window")
