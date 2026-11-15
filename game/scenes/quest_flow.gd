class_name QuestFlow
extends Node
## What the game scene shows of the quests besides the character window's tab: the notice board's
## window, the "!" over the boards, the lines that tell the player a quest was posted or went
## away and the voice of the givers. Main creates it with the game it shows and gives `board_screen`
## and `voice` to what handles E.

var board_screen := NoticeBoardScreen.new()
## Has the givers say their lines.
var voice: QuestVoice


## `entities` is where the world's things are drawn, so the marks stand among them.
func _init(
	state: GameState, dialogue: NpcDialogue, notifications: NotificationHud, entities: Node2D
) -> void:
	voice = QuestVoice.new(dialogue)
	add_child(board_screen)
	entities.add_child(QuestMarkView.new(state))
	state.quests.noticed.connect(notifications.post_line)
