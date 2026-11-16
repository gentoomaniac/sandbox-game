class_name BarterFlow
extends Node
## What the game scene shows of barter: the window of the swap, opened from the chat's [Barter]
## button and giving back to the chat with [Talk]. Main creates it with the game it shows.

var barter_screen := BarterScreen.new()


func _init(state: GameState, chat_screen: ChatScreen, open_chat: Callable) -> void:
	add_child(barter_screen)
	chat_screen.barter_requested.connect(
		func(npc: Npc) -> void: barter_screen.open_barter(npc, state)
	)
	barter_screen.talk_requested.connect(open_chat)
