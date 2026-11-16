class_name QuestFlow
extends Node
## What the game scene shows of the quests besides the character window's tab: the notice board's
## window, the "!" over the boards, the lines that tell the player a quest was posted or went
## away and the voice of the givers. Main creates it with the game it shows and gives `voice` to
## what handles E; the board's words and opening it registers itself.

## Has the givers say their lines.
var voice: QuestVoice


## `entities` is where the world's things are drawn, so the marks stand among them.
func _init(
	state: GameState,
	dialogue: NpcDialogue,
	notifications: NotificationHud,
	entities: Node2D,
	interactions: InteractionRegistry
) -> void:
	voice = QuestVoice.new(dialogue)
	var board_screen := NoticeBoardScreen.new()
	add_child(board_screen)
	interactions.register(
		Interaction.Kind.READ_BOARD,
		"Read the notice board",
		func(_board: WorldObject) -> void: board_screen.open_board(state)
	)
	entities.add_child(QuestMarkView.new(state))
	state.quests.noticed.connect(notifications.post_line)
