extends GutTest
## The chat window shows the level of friendship under the villager's name, and a villager who has
## shunned the player turns away when it opens.

var _state: GameState
var _antje: Npc
var _screen: ChatScreen
var _friendship := FriendshipRules.default_rules()


func before_each() -> void:
	_state = GameState.new_game(7)
	_antje = Npc.create_villager("antje", Vector2(2.5, 2.5), _state.npcs.villagers)
	_state.npcs.add(_antje)
	_screen = ChatScreen.new()
	var settings := GameSettings.new("user://test_chat_level/settings.cfg")
	_screen.dialogue = NpcDialogue.new(settings, FakeChat.new())
	add_child_autofree(_screen.dialogue)
	add_child_autofree(_screen)


func after_each() -> void:
	get_tree().paused = false


func test_the_name_has_the_level_under_it_and_no_points() -> void:
	_antje.opinion = _friendship.first_point_of(6) + 7

	_screen.open_chat(_antje, _state)

	assert_eq(_screen._npc_name.text, "Antje Boysen\nGood neighbour")
	assert_false(_screen._npc_name.text.contains("7"))


func test_a_gift_that_crosses_a_level_shows_the_new_one() -> void:
	_antje.opinion = _friendship.first_point_of(4) - 5
	_state.player.inventory.add(ItemTypes.BERRY_TART, 1)
	_state.player.inventory.hold(ItemTypes.BERRY_TART)
	_screen.open_chat(_antje, _state)
	assert_string_ends_with(_screen._npc_name.text, "Stranger")

	_screen._on_give_pressed()

	assert_string_ends_with(_screen._npc_name.text, "Acquaintance")


func test_a_villager_who_has_shunned_the_player_turns_away_once_when_spoken_to() -> void:
	_antje.opinion = _friendship.first_point_of(1)

	TalkFriendship.greet(_state, _antje)
	TalkFriendship.greet(_state, _antje)

	assert_eq(_antje.chat_history.size(), 1, "not said again")
	var lines: Array = NpcTalkRules.default_rules().value("scripted", "turn_away")
	assert_has(lines, _antje.chat_history[0]["text"])


func test_one_who_talks_says_nothing_when_spoken_to() -> void:
	_antje.opinion = _friendship.first_point_of(2)

	TalkFriendship.greet(_state, _antje)

	assert_true(_antje.chat_history.is_empty())
