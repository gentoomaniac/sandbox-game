extends GutTest
## The feature flows of the game scene register the words and the opening of their own kind of E
## (see InteractionRegistry), so the hint and the interact flow need not know them.

var _state: GameState
var _interactions := InteractionRegistry.new()


func before_each() -> void:
	_state = GameState.new_game(7)


func _words(kind: Interaction.Kind) -> String:
	return _interactions.label_of(
		Interaction.Choice.new(kind, WorldObject.new(&"chest", Vector2i.ZERO))
	)


func test_the_stall_flow_registers_the_cart() -> void:
	add_child_autofree(StallFlow.new(_state, _interactions))

	assert_eq(_words(Interaction.Kind.OPEN_CART), "Tend the cart")


func test_the_campfire_flow_registers_the_fire() -> void:
	var hotbar: HotbarHud = add_child_autofree(HotbarCase.new_hotbar())
	var crafting_screen: CraftingScreen = add_child_autofree(CraftingScreen.new())
	var sounds: GameSounds = add_child_autofree(GameSounds.new())
	add_child_autofree(CampfireFlow.new(_state, hotbar, crafting_screen, _interactions, sounds))

	assert_eq(_words(Interaction.Kind.OPEN_FIRE), "Tend the fire")


func test_the_storage_flow_registers_the_chest() -> void:
	var hotbar: HotbarHud = add_child_autofree(HotbarCase.new_hotbar())
	var sounds: GameSounds = add_child_autofree(GameSounds.new())
	add_child_autofree(StorageFlow.new(_state, hotbar, _interactions, sounds))

	assert_eq(_words(Interaction.Kind.OPEN_CHEST), "Open chest")


func test_the_process_flow_registers_the_stations() -> void:
	var hotbar: HotbarHud = add_child_autofree(HotbarCase.new_hotbar())
	var sounds: GameSounds = add_child_autofree(GameSounds.new())
	add_child_autofree(ProcessFlow.new(_state, hotbar, _interactions, sounds))

	assert_eq(_words(Interaction.Kind.OPEN_STATION_GRID), "Use chest")


func test_the_crafting_flow_registers_the_stations() -> void:
	var sounds: GameSounds = add_child_autofree(GameSounds.new())
	add_child_autofree(CraftingFlow.new(_state, _interactions, sounds))

	assert_eq(_words(Interaction.Kind.OPEN_CRAFTING), "Craft at chest")


func test_the_chat_and_trade_flows_make_their_screens() -> void:
	var settings := GameSettings.new("user://test_feature_flows/settings.cfg")
	var notifications: NotificationHud = add_child_autofree(NotificationHud.new())
	var sounds: GameSounds = add_child_autofree(GameSounds.new())
	var chat_flow: ChatFlow = add_child_autofree(
		ChatFlow.new(settings, notifications, func() -> void: pass, sounds)
	)
	var trade_flow: TradeFlow = add_child_autofree(TradeFlow.new(sounds))

	assert_eq(chat_flow.screen.dialogue, chat_flow.dialogue)
	assert_true(chat_flow.screen.is_inside_tree())
	assert_true(trade_flow.screen.is_inside_tree())


func test_the_quest_flow_registers_the_notice_board() -> void:
	var settings := GameSettings.new("user://test_feature_flows/settings.cfg")
	var dialogue: NpcDialogue = add_child_autofree(NpcDialogue.new(settings))
	var entities: Node2D = add_child_autofree(Node2D.new())
	var notifications: NotificationHud = add_child_autofree(NotificationHud.new())
	add_child_autofree(QuestFlow.new(_state, dialogue, notifications, entities, _interactions))

	assert_eq(_words(Interaction.Kind.READ_BOARD), "Read the notice board")


func test_every_kind_of_e_but_nothing_is_registered_as_main_does() -> void:
	var settings := GameSettings.new("user://test_feature_flows/settings.cfg")
	var dialogue: NpcDialogue = add_child_autofree(NpcDialogue.new(settings))
	var entities: Node2D = add_child_autofree(Node2D.new())
	var notifications: NotificationHud = add_child_autofree(NotificationHud.new())
	var hotbar: HotbarHud = add_child_autofree(HotbarCase.new_hotbar())
	var crafting_screen: CraftingScreen = add_child_autofree(CraftingScreen.new())
	var sounds: GameSounds = add_child_autofree(GameSounds.new())
	var interact := InteractFlow.new()
	interact.state = _state
	interact.register_kinds(_interactions)
	add_child_autofree(StallFlow.new(_state, _interactions))
	add_child_autofree(StorageFlow.new(_state, hotbar, _interactions, sounds))
	add_child_autofree(ProcessFlow.new(_state, hotbar, _interactions, sounds))
	add_child_autofree(CraftingFlow.new(_state, _interactions, sounds))
	add_child_autofree(CampfireFlow.new(_state, hotbar, crafting_screen, _interactions, sounds))
	add_child_autofree(QuestFlow.new(_state, dialogue, notifications, entities, _interactions))

	for kind: Interaction.Kind in Interaction.Kind.values():
		if kind != Interaction.Kind.NOTHING:
			assert_true(_interactions.is_registered(kind), Interaction.Kind.find_key(kind))
