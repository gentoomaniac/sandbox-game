extends GutTest
## Giving a villager the item in the player's hand (Gifts): liked, neutral or disliked by the
## villager's sheet or, for a made-up villager, by their trade; one gift a day; the item leaves the
## inventory; the deed is logged; the villager answers in their chat.

const NOON := 12 * GameClock.MINUTES_PER_HOUR

var _state: GameState
var _antje: Npc
var _friendship := FriendshipRules.default_rules()


func before_each() -> void:
	_state = GameState.new_game(7)
	_antje = Npc.create_villager("antje", Vector2(2.5, 2.5), _state.npcs.villagers)
	_state.npcs.add(_antje)
	_state.player.position = Vector2(3.5, 2.5)
	_state.clock.minute_of_day = NOON


func _hold(item: StringName, count := 2) -> void:
	_state.player.inventory.add(item, count)
	_state.player.inventory.hold(item)


func _last_line() -> String:
	return _antje.chat_history[-1]["text"]


func test_a_liked_gift_raises_the_opinion_and_leaves_the_inventory() -> void:
	_hold(ItemTypes.BERRY_TART)

	var outcome := Gifts.give(_state, _antje)

	assert_eq(outcome, Gifts.LIKED)
	assert_eq(_antje.opinion, _friendship.gift_points(&"liked"))
	assert_eq(_state.player.inventory.count_of(ItemTypes.BERRY_TART), 1)
	assert_string_contains(_last_line(), "Just what I like")
	assert_string_contains(_last_line(), "berry tart")


func test_a_neutral_gift_gives_a_little() -> void:
	_hold(ItemTypes.CLAY)

	assert_eq(Gifts.give(_state, _antje), Gifts.NEUTRAL)
	assert_eq(_antje.opinion, _friendship.gift_points(&"neutral"))


func test_a_disliked_gift_costs_friendship_and_is_still_taken() -> void:
	_hold(ItemTypes.BONE)

	assert_eq(Gifts.give(_state, _antje), Gifts.DISLIKED)
	assert_eq(_antje.opinion, _friendship.gift_points(&"disliked"))
	assert_eq(_state.player.inventory.count_of(ItemTypes.BONE), 1)


func test_a_villager_takes_one_gift_a_day() -> void:
	_hold(ItemTypes.BERRY_TART)
	Gifts.give(_state, _antje)

	var outcome := Gifts.give(_state, _antje)

	assert_eq(outcome, Gifts.REFUSED_TODAY)
	assert_eq(_antje.opinion, _friendship.gift_points(&"liked"), "nothing more")
	assert_eq(_state.player.inventory.count_of(ItemTypes.BERRY_TART), 1, "the item is kept")
	assert_string_contains(_last_line(), "already")


func test_the_next_day_the_villager_takes_a_gift_again() -> void:
	_hold(ItemTypes.BERRY_TART)
	Gifts.give(_state, _antje)
	_state.clock.advance(GameClock.MINUTES_PER_DAY)

	assert_eq(Gifts.give(_state, _antje), Gifts.LIKED)
	assert_eq(_state.player.inventory.count_of(ItemTypes.BERRY_TART), 0)


func test_an_empty_hand_gives_nothing() -> void:
	_state.player.inventory.hold(ItemTypes.NONE)

	assert_eq(Gifts.give(_state, _antje), Gifts.NOTHING_HELD)
	assert_eq(_antje.opinion, 0)
	assert_eq(_antje.last_gift_day, 0)


func test_the_gift_is_logged_as_a_deed_seen_by_the_receiver() -> void:
	_hold(ItemTypes.BERRY_TART)

	Gifts.give(_state, _antje)

	var entry := _state.deeds.entries[0]
	assert_eq(entry["kind"], GossipRules.GAVE_GIFT)
	assert_eq(entry["witnesses"], ["Antje Boysen"])
	assert_eq(_antje.stories[0]["kind"], GossipRules.GAVE_GIFT)


func test_the_receiver_alone_knows_a_gift_given_indoors() -> void:
	_hold(ItemTypes.BERRY_TART)
	var bystander := Npc.create_villager("gesche", Vector2(3.5, 3.5), _state.npcs.villagers)
	_state.npcs.add(bystander)
	var house := _state.world.place_building(BuildingTypes.KATE, Vector2i(20, 20))
	_state.player.position = Vector2(house.door_tile()) + Vector2(0.5, 0.5)
	PlayerRest.pass_door(_state)

	Gifts.give(_state, _antje)

	assert_eq(_state.deeds.entries[0]["witnesses"], ["Antje Boysen"])


func test_a_gift_does_not_add_to_what_the_story_moves() -> void:
	_hold(ItemTypes.BERRY_TART)
	Gifts.give(_state, _antje)
	var story := _antje.stories[0]

	_state.judge.settle(_antje, story, _state.judge.fixed_verdict(story))

	assert_eq(_antje.opinion, _friendship.gift_points(&"liked"))


func test_a_made_up_villager_has_the_taste_of_their_trade() -> void:
	var rules := _state.npcs.rules
	var stranger := Npc.create(5, Vector2(2.5, 2.5), rules)
	var tastes := rules.gift_tastes_of_set(rules.work_set_of_trade(stranger.trade))
	_state.npcs.add(stranger)
	_hold(StringName(tastes["liked"][0]))

	assert_eq(Gifts.give(_state, stranger), Gifts.LIKED)


func test_every_sheet_and_every_trade_has_tastes_that_are_clean() -> void:
	assert_eq(VillagerRules.default_rules().problems(), [])
	assert_eq(NpcRules.default_rules().problems(), [])
	for work_set in ["farmer", "fisher", "craftsman", "keeper_of_the_house"]:
		assert_has(NpcRules.default_rules().gift_tastes_of_set(work_set), "liked")


func test_a_gift_of_no_item_or_of_both_tastes_is_a_problem() -> void:
	assert_eq(FriendshipRules.gift_taste_problems("[a]", ["bread"], ["bone"]), [])
	assert_eq(FriendshipRules.gift_taste_problems("[a]", [], []), [])
	assert_eq(FriendshipRules.gift_taste_problems("[a]", ["nothing_like_it"], []).size(), 1)
	assert_eq(FriendshipRules.gift_taste_problems("[a]", ["bread"], "bone").size(), 1)
	assert_eq(FriendshipRules.gift_taste_problems("[a]", ["bread"], ["bread"]).size(), 1)


func test_a_sheet_without_tastes_is_a_problem() -> void:
	var sheets := DataFile.read_sections(VillagerRules.DEFAULT_PATH)
	sheets["antje"].erase("gifts_liked")

	assert_eq(VillagerRules.new(sheets).problems().size(), 1)


func test_the_chat_screen_offers_the_held_item_as_a_gift() -> void:
	var screen := ChatScreen.new()
	var settings := GameSettings.new("user://test_gifts/settings.cfg")
	screen.dialogue = NpcDialogue.new(settings, FakeChat.new())
	add_child_autofree(screen.dialogue)
	add_child_autofree(screen)
	_state.player.inventory.hold(ItemTypes.NONE)
	screen.open_chat(_antje, _state)
	var button: Button = screen.find_children("*", "Button", true, false)[0]
	assert_true(button.disabled, "nothing to give")

	_hold(ItemTypes.BERRY_TART)
	screen.open_chat(_antje, _state)
	assert_false(button.disabled)
	assert_string_contains(button.text, "Berry tart")
	button.pressed.emit()

	assert_eq(_antje.opinion, _friendship.gift_points(&"liked"))
	assert_eq(_antje.chat_history.size(), 1, "the villager's answer is in the chat")
	screen.close()
	get_tree().paused = false
