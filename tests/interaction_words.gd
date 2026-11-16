class_name InteractionWords
extends RefCounted
## What the hint over the hotbar says E does on a tile: the words the flows of the game scene
## register for the kinds of Interaction (nothing is opened).


static func e_text(test: GutTest, state: GameState, target: Vector2i) -> String:
	var interactions := InteractionRegistry.new()
	FlowsCase.make(test, state, interactions)
	return interactions.e_text(state, target)
