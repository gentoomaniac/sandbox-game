class_name TradeFlow
extends Node
## What the game scene shows of trade: the window of a shop and the click of its buttons. Opening
## it is InteractFlow's (E, the console and the debug flags use it). Main creates it.

var screen := TradeScreen.new()


func _init(sounds: GameSounds) -> void:
	add_child(screen)
	sounds.click_on_press_in(screen)
