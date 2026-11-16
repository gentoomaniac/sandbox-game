class_name StallFlow
extends Node
## What the game scene shows of the player's stall: the window of the sales cart, which E opens on
## the cart (see InteractFlow). Main creates it and gives `cart_screen` to what handles E.

var cart_screen := CartScreen.new()


func _init() -> void:
	add_child(cart_screen)
