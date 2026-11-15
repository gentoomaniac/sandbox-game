extends QuestsCase
## Handing in a bring quest (QuestTalk): speaking to the giver with the item in hand gives it over
## when there is enough, and the giver says the turn-in lines and the reward is the player's.

const FIBRE_ITEM := ItemTypes.FIBRE
const SEEDS := ItemTypes.TURNIP_SEEDS

var _antje: Npc
var _bag: Inventory


func before_each() -> void:
	super.before_each()
	_antje = _state.npcs.find(ANTJE)
	_state.player.inventory = Inventory.new()
	_bag = _state.player.inventory


## A bring quest for 5 fibre, taken from Antje (the data folder's own fibre quest, with `changes`).
func _take_the_fibre_quest(changes := {}) -> void:
	_use_rules({"a": changes})
	_quests.post("a", ANTJE)
	QuestTalk.greet(_state, _antje)
	_antje.chat_history.clear()


func _lines_said() -> Array[String]:
	var lines: Array[String] = []
	for entry in _antje.chat_history:
		lines.append(entry["text"])
	return lines


func test_with_enough_in_hand_it_is_handed_in_and_paid() -> void:
	_take_the_fibre_quest()
	_bag.add(FIBRE_ITEM, 7)
	_bag.hold(FIBRE_ITEM)

	assert_eq(QuestTalk.greet(_state, _antje), "")

	assert_eq(_bag.count_of(FIBRE_ITEM), 2, "all 5 asked for were taken and no more")
	assert_eq(_bag.count_of(SEEDS), 10)
	assert_eq(_lines_said(), ["That will hold till the autumn.", "Take these, they are good seed."])
	assert_true(_quests.is_done("a"))
	assert_false(_quests.is_open("a"))


func test_with_too_few_the_short_line_is_said_and_nothing_is_taken() -> void:
	_take_the_fibre_quest()
	_bag.add(FIBRE_ITEM, 3)
	_bag.hold(FIBRE_ITEM)

	QuestTalk.greet(_state, _antje)

	assert_eq(_lines_said(), ["Not yet five, neighbour. 3 of 5."])
	assert_eq(_bag.count_of(FIBRE_ITEM), 3)
	assert_true(_quests.is_open("a"))
	assert_false(_quests.is_done("a"))


func test_a_file_with_no_short_line_has_the_default() -> void:
	_take_the_fibre_quest()
	_quests.rules.quest("a").erase("short")
	_bag.add(FIBRE_ITEM, 1)
	_bag.hold(FIBRE_ITEM)

	QuestTalk.greet(_state, _antje)

	assert_eq(_lines_said(), ["Not yet, neighbour. 1 of 5."])


func test_the_short_line_is_not_said_again_while_it_is_the_last() -> void:
	_take_the_fibre_quest()
	_bag.add(FIBRE_ITEM, 1)
	_bag.hold(FIBRE_ITEM)

	QuestTalk.greet(_state, _antje)
	QuestTalk.greet(_state, _antje)

	assert_eq(_lines_said().size(), 1)


func test_with_the_item_not_in_hand_the_quest_is_recalled_and_nothing_is_taken() -> void:
	_take_the_fibre_quest()
	_bag.add(FIBRE_ITEM, 9)
	_bag.add(ItemTypes.LOGS, 1)
	_bag.hold(ItemTypes.LOGS)

	QuestTalk.greet(_state, _antje)

	assert_eq(_lines_said(), ["My bean rows sag, neighbour."])
	assert_eq(_bag.count_of(FIBRE_ITEM), 9)
	assert_true(_quests.is_open("a"))


func test_a_reward_that_does_not_fit_the_bag_falls_at_the_feet() -> void:
	_take_the_fibre_quest({"reward": {"items": {"turnip_seeds": 500}}})
	_bag.add(FIBRE_ITEM, 5)
	_bag.hold(FIBRE_ITEM)
	for slot in Inventory.SLOT_COUNT:
		if _bag.item_in(slot) == ItemTypes.NONE:
			_bag.slots[slot] = {"item": ItemTypes.STONE, "count": 1}
	assert_eq(_bag.count_of(SEEDS), 0)

	QuestTalk.greet(_state, _antje)

	var on_ground := 0
	for pile in _state.current_map.ground_items.near(_state.player.position, 3.0):
		if pile.item == SEEDS:
			on_ground += pile.count
	assert_eq(_bag.count_of(SEEDS) + on_ground, 500, "none was lost")
	assert_gt(on_ground, 0)


func test_the_giver_who_is_gone_still_has_the_player_paid() -> void:
	_take_the_fibre_quest()
	_state.npcs.remove(_antje)
	_bag.add(FIBRE_ITEM, 5)

	QuestTalk.complete(_state, _quests.entry_of("a"))

	assert_eq(_bag.count_of(SEEDS), 10)
	assert_true(_quests.is_done("a"))
