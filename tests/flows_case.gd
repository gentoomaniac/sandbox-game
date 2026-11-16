class_name FlowsCase
extends RefCounted
## The flows of the game scene that register a kind of E, as Main makes them, for the tests that
## need what they register. They are in the tree of `test` and freed with it.


static func make(test: GutTest, state: GameState, interactions: InteractionRegistry) -> void:
	var hotbar: HotbarHud = test.add_child_autofree(HotbarCase.new_hotbar())
	var sounds: GameSounds = test.add_child_autofree(GameSounds.new())
	var interact := InteractFlow.new()
	interact.state = state
	interact.register_kinds(interactions)
	test.add_child_autofree(StorageFlow.new(state, hotbar, interactions, sounds))
	test.add_child_autofree(ProcessFlow.new(state, hotbar, interactions, sounds))
	test.add_child_autofree(CraftingFlow.new(state, interactions, sounds))
