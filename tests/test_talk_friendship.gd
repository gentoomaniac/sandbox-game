extends GutTest
## The first chat of a day with a villager counts for their opinion, once a day, with no model.

var _state: GameState
var _antje: Npc
var _dialogue: NpcDialogue
var _friendship := FriendshipRules.default_rules()


func before_each() -> void:
	_state = GameState.new_game(7)
	_antje = Npc.create_villager("antje", Vector2(2.5, 2.5), _state.npcs.villagers)
	_state.npcs.add(_antje)
	var settings := GameSettings.new("user://test_talk_friendship/settings.cfg")
	_dialogue = NpcDialogue.new(settings, FakeChat.new())
	_dialogue.rules = NpcTalkRules.new(_quick_rules())
	add_child_autofree(_dialogue)


## The rules of the data file, with no wait before a scripted answer.
func _quick_rules() -> Dictionary:
	var values := DataFile.read_sections(NpcTalkRules.DEFAULT_PATH)
	values["scripted"]["thinking_seconds"] = 0.01
	return values


func test_the_first_chat_of_the_day_counts() -> void:
	await _dialogue.say(_antje, "Moin", _state)

	assert_eq(_antje.opinion, _friendship.value("talk", "first_chat_points"))
	assert_eq(_antje.chat_counted_day, _state.clock.day)


func test_a_second_chat_the_same_day_counts_nothing() -> void:
	await _dialogue.say(_antje, "Moin", _state)
	await _dialogue.say(_antje, "Fine weather", _state)

	assert_eq(_antje.opinion, _friendship.value("talk", "first_chat_points"))


func test_the_next_day_counts_again() -> void:
	await _dialogue.say(_antje, "Moin", _state)
	_state.clock.advance(GameClock.MINUTES_PER_DAY)
	await _dialogue.say(_antje, "Moin again", _state)

	assert_eq(_antje.opinion, 2 * _friendship.value("talk", "first_chat_points"))


func test_the_chat_counts_within_the_cap_of_the_actions() -> void:
	_antje.change_friendship(
		_friendship.action_daily_cap(), _state.clock.day, _friendship, GossipRules.default_rules()
	)
	var before := _antje.opinion

	await _dialogue.say(_antje, "Moin", _state)

	assert_eq(_antje.opinion, before, "the day's cap of the actions is used up")
