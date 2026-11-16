extends GutTest
## The barter window (BarterScreen) and the chat's [Barter] button: the rows, the counts, the line,
## [Trade] and [Talk].

const EGG := ItemTypes.EGG
const FIBRE := ItemTypes.FIBRE

var _state: GameState
var _antje: Npc
var _screen: BarterScreen
var _friendship := FriendshipRules.default_rules()


func before_each() -> void:
	_state = GameFactory.new_game(7)
	_antje = Npc.create_villager("antje", Vector2(2.5, 2.5), _state.npcs.villagers)
	_antje.opinion = _friendship.first_point_of(5)
	_state.npcs.add(_antje)
	_screen = BarterScreen.new()
	add_child_autofree(_screen)
	get_tree().paused = false


func after_each() -> void:
	get_tree().paused = false


func _carry(item: StringName, count: int) -> void:
	assert_eq(_state.player.inventory.add(item, count), 0)


func _open() -> void:
	_screen.open_barter(_antje, _state)


func test_the_rows_are_what_she_offers_and_what_she_wants() -> void:
	_carry(FIBRE, 3)
	_open()
	assert_eq(_screen._offer_rows.size(), 2)
	assert_eq(_screen._want_rows.size(), 3)
	assert_eq(_screen._offer_rows[0]._detail_label.text, "2 ß")
	assert_eq(_screen._want_rows[1]._detail_label.text, "3 ß, you have 3")
	assert_lt(_screen._want_rows[0].modulate.a, 1.0, "no flour in the bag")


func test_the_counts_stay_within_the_cap_and_the_bag() -> void:
	_carry(FIBRE, 3)
	_open()
	_screen.step_want(EGG, 99)
	assert_eq(_screen.want, {EGG: 50}, "100 Schilling at 2 each")
	_screen.step_give(FIBRE, 99)
	assert_eq(_screen.give, {FIBRE: 3}, "not above what is carried")
	_screen.step_give(FIBRE, -99)
	assert_eq(_screen.give, {})


func test_the_line_says_what_is_short_and_a_fair_trade_is_done() -> void:
	_carry(FIBRE, 2)
	_open()
	assert_eq(_screen.status_text(), "Choose what you want and what you give for it.")
	assert_true(_screen._trade_button.disabled)
	_screen.step_want(EGG, 3)
	_screen.step_give(FIBRE, 1)
	assert_eq(_screen.status_text(), "Short by 3 Schilling worth.")
	assert_eq(_screen._get_label.text, "You get: 3 Egg (6 ß)")
	assert_eq(_screen._give_label.text, "You give: 1 Fibre (3 ß)")
	_screen.step_give(FIBRE, 1)
	assert_eq(_screen.status_text(), "A fair trade.")
	assert_false(_screen._trade_button.disabled)

	_screen._trade_button.pressed.emit()

	assert_eq(_state.player.inventory.count_of(EGG), 3)
	assert_eq(_state.player.inventory.count_of(FIBRE), 0)
	assert_eq([_screen.want, _screen.give], [{}, {}])
	assert_eq(_screen.status_text(), "Done.")


func test_talk_goes_back_to_the_chat() -> void:
	var talked_to: Array[Npc] = []
	_screen.talk_requested.connect(func(npc: Npc) -> void: talked_to.append(npc))
	_open()
	_screen._talk_button.pressed.emit()
	assert_eq(talked_to, [_antje] as Array[Npc])


func test_the_chat_offers_barter_to_a_villager_with_goods_and_opens_it_to_a_neighbour() -> void:
	var chat := ChatScreen.new()
	chat.dialogue = NpcDialogue.new(
		GameSettings.new("user://test_barter/settings.cfg"), FakeChat.new()
	)
	add_child_autofree(chat.dialogue)
	add_child_autofree(chat)
	var asked: Array[Npc] = []
	chat.barter_requested.connect(func(npc: Npc) -> void: asked.append(npc))

	_antje.opinion = _friendship.first_point_of(4)
	chat.open_chat(_antje, _state)
	assert_true(chat._barter_button.visible)
	assert_true(chat._barter_button.disabled, "an acquaintance does not barter yet")

	_antje.opinion = _friendship.first_point_of(5)
	chat.open_chat(_antje, _state)
	assert_false(chat._barter_button.disabled)
	chat._barter_button.pressed.emit()
	assert_eq(asked, [_antje] as Array[Npc])
	assert_false(chat.is_open())

	var trienke := Npc.create_villager("trienke", Vector2.ZERO, _state.npcs.villagers)
	chat.open_chat(trienke, _state)
	assert_false(chat._barter_button.visible, "she has a shop")
