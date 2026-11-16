extends GutTest
## What the levels open at work (Benefits): who turns away, the prices and the best wares of a shop,
## the quests a villager gives and what the prompt tells.

const KEPT := "Candle is kept for friends."
const SETTINGS_PATH := "user://test_benefits/settings.cfg"

var _state: GameState
var _antje: Npc
var _chat: FakeChat
var _friendship := FriendshipRules.default_rules()
var _rules := NpcTalkRules.default_rules()


func before_each() -> void:
	_state = GameState.new_game(7)
	_antje = Npc.create_villager("antje", Vector2(2.5, 2.5), _state.npcs.villagers)
	_state.npcs.add(_antje)


func _at_level(level: int) -> void:
	_antje.opinion = _friendship.first_point_of(level)


func _prompt() -> String:
	var moment := NpcMoment.of(_state, _antje, 8.0)
	var messages := NpcPrompt.reply_messages(_antje, [], "Moin", moment, _rules, false)
	return messages[-1]["content"]


func test_a_villager_gives_what_their_level_has() -> void:
	_at_level(5)

	assert_true(Benefits.allows(_antje, &"barter"))
	assert_false(Benefits.allows(_antje, &"better_prices"))


func test_the_sheet_of_a_villager_moves_a_benefit() -> void:
	var sheets := DataFile.read_sections(VillagerRules.DEFAULT_PATH)
	sheets["antje"]["benefit_level"] = {"better_prices": 5, "barter": 8}
	var villagers := VillagerRules.new(sheets)
	_at_level(5)

	assert_true(Benefits.allows(_antje, &"better_prices", villagers))
	assert_false(Benefits.allows(_antje, &"barter", villagers))


func test_a_made_up_villager_has_the_benefits_of_the_data_file() -> void:
	var stranger := Npc.create(5, Vector2.ZERO, _state.npcs.rules)
	stranger.opinion = _friendship.first_point_of(6)

	assert_true(Benefits.allows(stranger, &"lends_tool"))


# --- Talk ---


func _dialogue(endpoint: String) -> NpcDialogue:
	var settings := GameSettings.new(SETTINGS_PATH)
	settings.profiles.active["endpoint"] = endpoint
	_chat = FakeChat.new()
	var dialogue := NpcDialogue.new(settings, _chat)
	add_child_autofree(dialogue)
	return dialogue


func test_a_villager_who_has_shunned_the_player_turns_away_without_asking_the_model() -> void:
	var dialogue := _dialogue("http://fake/v1")
	_at_level(1)

	var answer := await dialogue.reply(_antje, [], "Moin, Antje", _state)

	assert_has(_rules.value("scripted", "turn_away"), answer)
	assert_true(_chat.requests.is_empty())


func test_a_shunned_villager_counts_no_chat_and_a_mistrusting_one_still_talks() -> void:
	var dialogue := _dialogue("")
	_at_level(1)
	var opinion := _antje.opinion
	await dialogue.say(_antje, "Moin", _state)
	assert_eq(_antje.opinion, opinion, "the chat counts nothing with one who turns away")
	assert_has(_rules.value("scripted", "turn_away"), _antje.chat_history[-1]["text"])

	_at_level(2)
	assert_has(
		_rules.value("scripted", "replies"), await dialogue.reply(_antje, [], "Moin", _state)
	)


# --- Shop ---


func test_a_keeper_with_better_prices_asks_less_and_the_rest_the_full_price() -> void:
	var keeper := _state.npcs.find("antje")
	var shop_rules := ShopRules.default_rules()
	var seeds := ItemTypes.TURNIP_SEEDS
	var full := shop_rules.price("trienke", ItemTypes.CANDLE)

	_at_level(5)
	assert_eq(ShopStanding.with_keeper(keeper).price_percent, 100)
	_at_level(6)
	var standing := ShopStanding.with_keeper(keeper)
	assert_eq(standing.price_percent, _friendship.value("shop", "better_prices_percent"))
	assert_lt(shop_rules.price("trienke", ItemTypes.CANDLE, standing.price_percent), full)
	assert_eq(shop_rules.price("trienke", seeds, 100), shop_rules.price("trienke", seeds))


func test_a_deal_is_quoted_at_the_standing_of_the_player() -> void:
	var shops := Shops.new(ShopRules.default_rules(), _state.clock)
	var bag := ItemSlots.new(6)
	var want := {ItemTypes.CANDLE: 5}
	var dear := shops.quote("trienke", want, {}, bag)
	var standing := ShopStanding.new()
	standing.price_percent = 80

	assert_lt(shops.quote("trienke", want, {}, bag, standing).price, dear.price)


func test_the_best_wares_are_sold_to_those_with_the_benefit_only() -> void:
	var values := DataFile.read_sections(ShopRules.DEFAULT_PATH)
	values["shop.trienke.sells.candle"]["best"] = true
	var rules := ShopRules.new(values)
	var shops := Shops.new(rules, _state.clock)
	var bag := ItemSlots.new(6)
	bag.add(ItemTypes.EGG, 30)
	var plain := ShopStanding.new()
	var friend := ShopStanding.new()
	friend.has_best_wares = true
	var want := {ItemTypes.CANDLE: 1}
	var give := {ItemTypes.EGG: 10}

	assert_eq(shops.quote("trienke", want, give, bag, plain).problem, KEPT)
	assert_ne(shops.quote("trienke", want, give, bag, friend).problem, KEPT)
	assert_ne(shops.quote("trienke", {ItemTypes.TURNIP_SEEDS: 1}, give, bag, plain).problem, KEPT)


func test_a_best_that_is_no_true_or_false_is_a_problem() -> void:
	var values := DataFile.read_sections(ShopRules.DEFAULT_PATH)
	values["shop.trienke.sells.candle"]["best"] = "yes"

	assert_eq(ShopRules.new(values).problems().size(), 1)


# --- The prompt ---


func test_the_prompt_tells_what_the_level_gives() -> void:
	_at_level(3)
	assert_false(_prompt().contains("small news"))
	assert_string_contains(_prompt(), "does not tell this neighbour what they want")

	_at_level(4)
	assert_string_contains(_prompt(), "small news")
	assert_string_contains(_prompt(), "does not tell this neighbour what they want")

	_at_level(5)
	assert_string_contains(_prompt(), "may say what they want this year")
	assert_false(_prompt().contains("does not tell this neighbour"))
