class_name StallFlow
extends Node
## What the game scene shows of the player's stall: the window of the sales cart, which E opens on
## the cart (see Interaction.Kind.OPEN_CART). Main creates it with the game it shows; it registers
## the cart's words and opening itself.

var _cart_screen := CartScreen.new()


func _init(state: GameState, interactions: InteractionRegistry) -> void:
	add_child(_cart_screen)
	interactions.register(
		Interaction.Kind.OPEN_CART,
		"Tend the cart",
		func(cart: WorldObject) -> void: _cart_screen.open_cart(cart, state.player)
	)
