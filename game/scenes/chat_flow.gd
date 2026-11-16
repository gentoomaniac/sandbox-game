class_name ChatFlow
extends Node
## What the game scene shows of the talk with villagers: the chat window with the dialogue that
## speaks for them, the notices of the language model's state and the sounds of the window. Opening
## a chat is InteractFlow's (E, the console and the debug flags use it). Main creates it and gives
## `dialogue` to the features that make the villagers speak.

var screen := ChatScreen.new()
var dialogue: NpcDialogue


## `toggle_art_set` is what the chat's art switch does.
func _init(
	settings: GameSettings,
	notifications: NotificationHud,
	toggle_art_set: Callable,
	sounds: GameSounds
) -> void:
	dialogue = NpcDialogue.new(settings)
	screen.dialogue = dialogue
	add_child(dialogue)
	add_child(ModelNotices.new(dialogue, notifications))
	add_child(screen)
	screen.art_set_switch_pressed.connect(toggle_art_set)
	sounds.click_on_press_in(screen)
	sounds.watch_panel(screen.is_open)
