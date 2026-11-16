extends SaveValidationCase
## What the player takes out of a chest is told when it is taken, as each move is done (see
## ChestTransfers), not when the screen closes: a harm to a villager's chest costs the villagers who
## saw it then, and a game saved with the chest still open keeps it. Run in the village of seed 1.

var _state: GameState
var _antje: Npc
var _chest: WorldObject
var _screen: StorageScreen
var _views: Array[SlotView] = []
var _taken: Array[Dictionary] = []
var _stealing := FriendshipRules.default_rules().harm_points(GossipRules.STOLE)


func before_each() -> void:
	_taken.clear()
	_state = GameFactory.new_game(1, true)
	_antje = _state.npcs.find("antje")
	_state.clock.minute_of_day = 12 * GameClock.MINUTES_PER_HOUR
	for npc in _state.npcs.all():
		npc.position = Vector2(9000, 9000)
	_state.action_done.connect(
		func(outcome: ActionOutcome) -> void:
			if outcome.kind == ActionOutcome.TAKE_FROM_CHEST:
				_taken.append(outcome.items)
	)
	# A chest by Antje's house, so that it is hers.
	_chest = WorldObject.new(WorldObjectTypes.CHEST, Vector2i(_antje.anchor))
	_chest.storage.add(ItemTypes.LOGS, 5)
	# The player starts with a kit; the tests want an empty backpack.
	_state.player.inventory = Inventory.new()
	_state.player.inventory.select(Inventory.HOTBAR_SIZE - 1)
	var hotbar: HotbarHud = autofree(HotbarCase.new_hotbar())
	hotbar.show_inventory(_state.player.inventory)
	_screen = StorageScreen.new(hotbar)
	add_child_autofree(_screen)
	_screen.open_chest(_chest, _state)
	var in_screen: Array[SlotView] = []
	in_screen.assign(_screen.find_children("*", "SlotView", true, false))
	in_screen.erase(_screen._trash_can._slot)
	_views = in_screen.slice(0, Inventory.BACKPACK_SIZE)
	for slot in Inventory.HOTBAR_SIZE:
		_views.append(hotbar._slot_views[slot])
	_views.append_array(in_screen.slice(Inventory.BACKPACK_SIZE))


func after_each() -> void:
	_views.clear()


func _chest_view(slot: int) -> SlotView:
	return _views[Inventory.SLOT_COUNT + slot]


## The view of an inventory slot: the views list the backpack first, then the hotbar.
func _inventory_view(slot: int) -> SlotView:
	return _views[
		slot - Inventory.HOTBAR_SIZE
		if slot >= Inventory.HOTBAR_SIZE
		else slot + Inventory.BACKPACK_SIZE
	]


func _drag(from: SlotView, to: SlotView) -> void:
	var data := {"from": from}
	if to._can_drop_data(Vector2.ZERO, data):
		to._drop_data(Vector2.ZERO, data)


func _stand_by_the_chest(npc: Npc) -> void:
	npc.position = Vector2(_chest.pos) + Vector2(1.5, 0.5)


func test_dragging_goods_out_tells_what_was_taken_at_once() -> void:
	_drag(_chest_view(0), _inventory_view(Inventory.HOTBAR_SIZE))

	assert_eq(_taken, [{ItemTypes.LOGS: 5}] as Array[Dictionary])


func test_a_shift_transfer_tells_what_was_taken_at_once() -> void:
	_chest_view(0).quick_move_requested.emit()

	assert_eq(_taken, [{ItemTypes.LOGS: 5}] as Array[Dictionary])


func test_closing_the_screen_tells_nothing_more() -> void:
	_chest_view(0).quick_move_requested.emit()

	_screen.close()

	assert_eq(_taken.size(), 1)


func test_a_swap_tells_only_what_left_the_chest() -> void:
	_state.player.inventory.add(ItemTypes.STONE, 2)

	_drag(_inventory_view(0), _chest_view(0))

	assert_eq(_taken, [{ItemTypes.LOGS: 5}] as Array[Dictionary])
	assert_eq(_chest.storage.slots[0], {"item": ItemTypes.STONE, "count": 2})


func test_putting_goods_in_and_moving_them_inside_the_chest_tell_nothing() -> void:
	_state.player.inventory.add(ItemTypes.STONE, 2)

	_inventory_view(0).quick_move_requested.emit()
	_drag(_chest_view(0), _chest_view(3))

	assert_eq(_taken, [] as Array[Dictionary])


func test_a_move_that_is_refused_tells_nothing() -> void:
	var inventory := _state.player.inventory
	for slot in inventory.slots.size():
		inventory.slots[slot] = {"item": ItemTypes.STONE, "count": 1}

	_chest_view(0).quick_move_requested.emit()

	assert_eq(_taken, [] as Array[Dictionary])
	assert_eq(_chest.storage.count_of(ItemTypes.LOGS), 5)


func test_goods_put_back_do_not_undo_what_was_seen_being_taken() -> void:
	_stand_by_the_chest(_antje)

	_chest_view(0).quick_move_requested.emit()
	_inventory_view(Inventory.HOTBAR_SIZE).quick_move_requested.emit()

	assert_eq(_taken, [{ItemTypes.LOGS: 5}] as Array[Dictionary])
	assert_eq(_antje.opinion, _stealing)


func test_who_sees_it_is_who_is_there_when_the_goods_are_taken() -> void:
	_stand_by_the_chest(_antje)

	_chest_view(0).quick_move_requested.emit()
	_antje.position = Vector2(9000, 9000)
	_screen.close()

	assert_eq(_antje.opinion, _stealing)


func test_nobody_there_when_it_is_taken_means_nobody_charged() -> void:
	_chest_view(0).quick_move_requested.emit()
	_stand_by_the_chest(_antje)
	_screen.close()

	assert_eq(_antje.opinion, 0)


func test_saving_with_the_chest_still_open_keeps_the_theft() -> void:
	_stand_by_the_chest(_antje)
	_chest_view(0).quick_move_requested.emit()
	assert_true(SaveFile.write(_state, SAVE_PATH))

	var loaded := SaveFile.read(SAVE_PATH)

	assert_eq(loaded.npcs.find("antje").opinion, _stealing)
	var kinds := loaded.deeds.entries.map(
		func(entry: Dictionary) -> StringName: return entry["kind"]
	)
	assert_has(kinds, GossipRules.STOLE)
