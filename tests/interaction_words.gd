class_name InteractionWords
extends RefCounted
## What the hint over the hotbar says E does on a tile: the words the game scene registers for the
## kinds of Interaction, with no screens behind them (nothing is opened).


static func e_text(state: GameState, target: Vector2i) -> String:
	var flow := InteractFlow.new()
	flow.state = state
	var interactions := InteractionRegistry.new()
	flow.register_kinds(interactions)
	return interactions.e_text(state, target)
