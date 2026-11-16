class_name FlowsCase
extends RefCounted
## The feature flows as Main makes them, for the tests that need what they register. They are in
## the tree of `test` and freed with it.


static func make(
	test: GutTest, state: GameState, interactions: InteractionRegistry
) -> FeatureFlows:
	var hotbar: HotbarHud = test.add_child_autofree(HotbarCase.new_hotbar())
	var sounds: GameSounds = test.add_child_autofree(GameSounds.new())
	var notifications: NotificationHud = test.add_child_autofree(NotificationHud.new())
	var entities: Node2D = test.add_child_autofree(Node2D.new())
	var interact := InteractFlow.new()
	interact.state = state
	var flows := FeatureFlows.new(
		state,
		GameSettings.new("user://flows_case/settings.cfg"),
		hotbar,
		sounds,
		notifications,
		entities,
		interactions,
		interact,
		func() -> void: pass
	)
	for flow in flows.all():
		test.add_child_autofree(flow)
	return flows
