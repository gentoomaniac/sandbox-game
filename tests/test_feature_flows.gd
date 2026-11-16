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


func test_the_quest_flow_registers_the_notice_board() -> void:
	var settings := GameSettings.new("user://test_feature_flows/settings.cfg")
	var dialogue: NpcDialogue = add_child_autofree(NpcDialogue.new(settings))
	var entities: Node2D = add_child_autofree(Node2D.new())
	var notifications: NotificationHud = add_child_autofree(NotificationHud.new())
	add_child_autofree(QuestFlow.new(_state, dialogue, notifications, entities, _interactions))

	assert_eq(_words(Interaction.Kind.READ_BOARD), "Read the notice board")
