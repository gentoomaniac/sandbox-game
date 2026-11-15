class_name QuestFlow
extends Node
## What the game scene shows of the quests besides the character window's tab: the notice board's
## window, the "!" over the boards and the lines that tell the player a quest was posted or went
## away. Main creates it with the game it shows and gives `board_screen` to what handles E.

var board_screen := NoticeBoardScreen.new()


## `entities` is where the world's things are drawn, so the marks stand among them.
func _init(state: GameState, notifications: NotificationHud, entities: Node2D) -> void:
	add_child(board_screen)
	entities.add_child(QuestMarkView.new(state))
	state.quests.noticed.connect(notifications.post_line)
