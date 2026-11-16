class_name TradeFlow
extends Node
## What the game scene shows of trade: the window of a shop and the sounds of its buttons and
## opening. Opening it is InteractFlow's (E, the console and the debug flags use it). Main creates
## it.

var screen := TradeScreen.new()


func _init(sounds: GameSounds) -> void:
	add_child(screen)
	sounds.click_on_press_in(screen)
	sounds.watch_panel(screen.is_open)
