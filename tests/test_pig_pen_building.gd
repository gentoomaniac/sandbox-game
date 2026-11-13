extends ResourceCase
## Building a pig pen (task 165): its fence, gate and shelter are made at the workbench and put down
## outdoors piece by piece, the fence joins the gate, the use key with an empty hand opens and shuts
## the gate, which is kept so through a save, and the axe takes each piece down again.


func test_the_workbench_makes_the_pieces_of_a_pen() -> void:
	var rules := RecipeRules.default_rules()
	assert_eq(rules.materials(&"pen_fence"), {ItemTypes.LOGS: 1})
	assert_eq(rules.count(&"pen_fence"), 2, "a log splits into two pieces")
	assert_eq(rules.materials(&"pen_gate"), {ItemTypes.PLANKS: 3, ItemTypes.LOGS: 1})
	assert_eq(
		rules.materials(&"pig_shelter"),
		{ItemTypes.PLANKS: 6, ItemTypes.LOGS: 2, ItemTypes.REEDS: 6}
	)
	for recipe_id in [&"pen_fence", &"pen_gate", &"pig_shelter"]:
		assert_true(rules.recipes_at(&"workbench").has(recipe_id))
		assert_eq(rules.skill(recipe_id), &"woodworking")


func test_each_piece_is_put_down_outdoors() -> void:
	for item in [ItemTypes.PEN_FENCE, ItemTypes.PEN_GATE, ItemTypes.PIG_SHELTER]:
		_world.remove_object(_tile)
		_state.player.inventory.add(item, 1)
		_hold(item)
		assert_eq(_state.use_facing_tile(), ToolUse.Use.PLACE, str(item))
		assert_eq(_world.object_at(_tile).type, ItemTypes.TYPES[item]["places"])


func test_the_fence_joins_the_gate_and_the_gate_the_fence() -> void:
	var gate := _place(WorldObjectTypes.PEN_GATE)
	var fence := WorldObject.new(WorldObjectTypes.PEN_FENCE, _tile + Vector2i.RIGHT)
	_world.add_object(fence)
	assert_eq(_world.connections(gate), 2, "east")
	assert_eq(_world.connections(fence), 8, "west")


func test_the_fence_and_the_shelter_stop_everyone_and_the_gate_only_the_animals() -> void:
	_place(WorldObjectTypes.PEN_FENCE)
	assert_false(_world.is_walkable(_tile))
	_world.remove_object(_tile)
	_place(WorldObjectTypes.PIG_SHELTER)
	assert_false(_world.is_walkable(_tile + Vector2i.RIGHT), "two tiles wide")
	_world.remove_object(_tile)
	_place(WorldObjectTypes.PEN_GATE)
	assert_true(_world.is_walkable(_tile))
	assert_false(_world.is_walkable_for_animals(_tile))


func test_the_axe_takes_each_piece_down_and_it_drops_its_item() -> void:
	_state.player.inventory.add(ItemTypes.RUSTY_IRON_AXE, 1)
	for type in [
		WorldObjectTypes.PEN_FENCE, WorldObjectTypes.PEN_GATE, WorldObjectTypes.PIG_SHELTER
	]:
		_clear_ground()
		_place(type)
		_hit(ItemTypes.RUSTY_IRON_AXE, WorldObjectTypes.TYPES[type]["hp"])
		assert_null(_world.object_at(_tile))
		assert_eq(_dropped(ItemTypes.item_placing(type)), 1, str(type))


func test_the_use_key_with_an_empty_hand_opens_and_shuts_the_gate() -> void:
	_place(WorldObjectTypes.PEN_GATE)
	_hold(ItemTypes.NONE)
	var outcomes: Array[ActionOutcome] = []
	_state.action_done.connect(func(outcome: ActionOutcome) -> void: outcomes.append(outcome))
	assert_eq(_state.use_facing_tile(), ToolUse.Use.GATE)
	assert_eq(_world.object_at(_tile).type, WorldObjectTypes.PEN_GATE_OPEN)
	assert_true(_world.is_walkable(_tile))
	assert_true(_world.is_walkable_for_animals(_tile))
	assert_eq(_state.use_facing_tile(), ToolUse.Use.GATE)
	assert_eq(_world.object_at(_tile).type, WorldObjectTypes.PEN_GATE)
	assert_false(_world.is_walkable_for_animals(_tile))
	assert_eq(outcomes.size(), 2)
	assert_eq(outcomes[0].kind, ActionOutcome.GATE)
	assert_eq(outcomes[0].object, WorldObjectTypes.PEN_GATE_OPEN)
	assert_ne(SoundEvents.action(ActionOutcome.GATE), &"", "it is heard")


func test_an_open_gate_stays_open_through_a_save() -> void:
	_place(WorldObjectTypes.PEN_GATE_OPEN)
	assert_eq(_through_save().world.object_at(_tile).type, WorldObjectTypes.PEN_GATE_OPEN)


func test_the_axe_takes_an_open_gate_down_and_it_drops_the_gate() -> void:
	_state.player.inventory.add(ItemTypes.RUSTY_IRON_AXE, 1)
	_place(WorldObjectTypes.PEN_GATE_OPEN)
	_hit(ItemTypes.RUSTY_IRON_AXE, WorldObjectTypes.TYPES[WorldObjectTypes.PEN_GATE_OPEN]["hp"])
	assert_null(_world.object_at(_tile))
	assert_eq(_dropped(ItemTypes.PEN_GATE), 1)
