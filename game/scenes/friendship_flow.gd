class_name FriendshipFlow
extends Node
## What the game scene shows when a villager's opinion of the player moves (see FriendshipNotes):
## the heart or cloud over their head (FriendshipPopups) and the line at the bottom of the screen
## when a level is crossed. Main creates it with the game it shows.

## How often the villagers are looked at, in seconds.
const LOOK_SECONDS := 0.25

var _notes: FriendshipNotes
var _since_look := 0.0


## `entities` is where the world's things are drawn, so the pop-ups stand among them.
func _init(state: GameState, notifications: NotificationHud, entities: Node2D) -> void:
	_notes = FriendshipNotes.new(state.npcs)
	_notes.level_crossed.connect(
		func(_npc: Npc, text: String) -> void: notifications.post_line(text)
	)
	entities.add_child(FriendshipPopups.new(state, _notes))
	_notes.check()


func _process(delta: float) -> void:
	_since_look += delta
	if _since_look >= LOOK_SECONDS:
		_since_look = 0.0
		_notes.check()
