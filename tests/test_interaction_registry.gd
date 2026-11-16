extends GutTest
## The registry of what E is called and does (InteractionRegistry), and that it does not keep the
## game alive: its callables hold the flow, so the flow must not hold the registry back.


func test_a_registered_kind_has_words_and_is_opened_with_its_subject() -> void:
	var registry := InteractionRegistry.new()
	var opened := []
	registry.register(
		Interaction.Kind.OPEN_CHEST,
		func(subject: String) -> String: return "Open " + subject,
		func(subject: String) -> void: opened.append(subject)
	)
	var choice := Interaction.Choice.new(Interaction.Kind.OPEN_CHEST, "box")

	registry.open(choice)

	assert_eq(registry.label_of(choice), "Open box")
	assert_eq(opened, ["box"])


func test_a_second_registration_of_a_kind_is_refused_naming_both_owners() -> void:
	var registry := InteractionRegistry.new()
	var first := StallFlow.new(GameFactory.new_game(7), registry)
	var second := InteractFlow.new()
	registry.register(Interaction.Kind.OPEN_CART, "Again", second.open_chat)
	var choice := Interaction.Choice.new(Interaction.Kind.OPEN_CART)

	assert_push_error("OPEN_CART is registered by StallFlow, and again by InteractFlow")
	assert_eq(registry.label_of(choice), "Tend the cart")
	first.free()


func test_a_kind_nobody_registered_says_and_does_nothing() -> void:
	var registry := InteractionRegistry.new()
	var choice := Interaction.Choice.new(Interaction.Kind.SLEEP)

	registry.open(choice)

	assert_eq(registry.label_of(choice), "")


func test_the_flow_and_its_game_are_freed_with_the_registry() -> void:
	var state: GameState = GameFactory.new_game(7)
	var flow := InteractFlow.new()
	flow.state = state
	var registry := InteractionRegistry.new()
	flow.register_kinds(registry)
	var flow_ref: WeakRef = weakref(flow)
	var state_ref: WeakRef = weakref(state)

	flow = null
	state = null
	registry = null

	assert_null(flow_ref.get_ref())
	assert_null(state_ref.get_ref())


func test_the_feature_flows_and_their_game_are_freed_with_the_registry() -> void:
	var state: GameState = GameFactory.new_game(7)
	var registry := InteractionRegistry.new()
	var hotbar: HotbarHud = HotbarCase.new_hotbar()
	var sounds := GameSounds.new()
	var notifications := NotificationHud.new()
	var entities := Node2D.new()
	var interact := InteractFlow.new()
	interact.state = state
	var flows := FeatureFlows.new(
		state,
		GameSettings.new("user://test_interaction_registry/settings.cfg"),
		hotbar,
		sounds,
		notifications,
		entities,
		registry,
		interact,
		func() -> void: pass
	)
	var state_ref: WeakRef = weakref(state)
	var flows_ref: WeakRef = weakref(flows)
	for flow in flows.all():
		flow.free()
	for node: Node in [hotbar, sounds, notifications, entities]:
		node.free()

	flows = null
	interact = null
	registry = null
	state = null

	assert_null(flows_ref.get_ref())
	assert_null(state_ref.get_ref())
