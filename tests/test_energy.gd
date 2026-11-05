extends EnergyCase
## Energy: what uses cost, slow walking and eating.

# --- Costs ---


func test_a_use_costs_energy_by_its_kind() -> void:
	_hold(ItemTypes.HOE)
	assert_eq(_state.use_facing_tile(), GameState.Use.TILL)
	assert_eq(_state.player.energy, 96.0)
	_hold(ItemTypes.TURNIP_SEEDS)
	assert_eq(_state.use_facing_tile(), GameState.Use.PLANT)
	assert_eq(_state.player.energy, 95.0)


func test_a_hit_and_a_pick_cost_what_the_rules_say() -> void:
	_place(WorldObjectTypes.OAK)
	_hit(ItemTypes.AXE, 1)
	assert_eq(_state.player.energy, 97.0)
	_world.remove_object(_tile)
	_place(WorldObjectTypes.BERRY_BUSH)
	_hold(ItemTypes.NONE)
	assert_eq(_state.use_facing_tile(), GameState.Use.FORAGE)
	assert_eq(_state.player.energy, 96.5)


func test_a_use_that_does_nothing_costs_nothing() -> void:
	_hold(ItemTypes.AXE)
	assert_eq(_state.use_facing_tile(), GameState.Use.NOTHING)
	assert_eq(_state.player.energy, 100.0)


func test_a_tool_too_weak_for_the_object_costs_nothing() -> void:
	_place(WorldObjectTypes.BOULDER)
	assert_eq(_hit(ItemTypes.PICKAXE, 1), GameState.Use.NEEDS_BETTER_TOOL)
	assert_eq(_state.player.energy, 100.0)


func test_a_full_inventory_costs_nothing() -> void:
	_place(WorldObjectTypes.OAK)
	_hit(ItemTypes.AXE, 4)
	var energy_before := _state.player.energy
	_fill_inventory()
	assert_eq(_hit(ItemTypes.AXE, 1), GameState.Use.INVENTORY_FULL)
	assert_eq(_state.player.energy, energy_before)


func test_the_weight_factor_is_free_up_to_the_limit_then_linear() -> void:
	var rules := EnergyRules.new(RULES)
	assert_eq(rules.weight_factor(0.0), 1.0)
	assert_eq(rules.weight_factor(15.0), 1.0)
	assert_almost_eq(rules.weight_factor(17.0), 1.2, 0.0001)
	assert_almost_eq(rules.weight_factor(20.0), 1.5, 0.0001)
	assert_almost_eq(rules.weight_factor(25.0), 2.0, 0.0001)


func test_a_heavy_load_costs_more() -> void:
	_state.player.inventory.add(ItemTypes.STONE, 10)
	var factor := _state.energy_rules.weight_factor(_state.player.carried_weight())
	assert_gt(factor, 1.0)
	_hold(ItemTypes.HOE)
	_state.use_facing_tile()
	assert_almost_eq(_state.player.energy, 100.0 - 4.0 * factor, 0.0001)


func test_the_drain_factor_scales_the_cost() -> void:
	_state.energy_drain = 1.5
	_hold(ItemTypes.HOE)
	_state.use_facing_tile()
	assert_almost_eq(_state.player.energy, 94.0, 0.0001)


func test_a_use_with_too_little_energy_left_still_happens_and_empties_the_bar() -> void:
	_state.player.energy = 1.0
	_hold(ItemTypes.HOE)
	assert_eq(_state.use_facing_tile(), GameState.Use.TILL)
	assert_eq(_world.tile_at(_tile).terrain, Tile.Terrain.SOIL)
	assert_eq(_state.player.energy, 0.0)
	assert_true(_state.is_out_of_energy())


# --- Walking ---


func test_walking_slows_down_with_low_energy() -> void:
	_state.player.energy = 30.5
	assert_eq(_state.walk_speed_factor(), 1.0)
	_state.player.energy = 30.0
	assert_eq(_state.walk_speed_factor(), 0.8)
	_state.player.energy = 15.0
	assert_eq(_state.walk_speed_factor(), 0.8)
	_state.player.energy = 14.9
	assert_eq(_state.walk_speed_factor(), 0.4)


func test_the_slowest_speed_wins_and_speeds_do_not_stack() -> void:
	_state.player.is_debuffed = true
	_state.player.energy = 40.0
	assert_eq(_state.walk_speed_factor(), 0.6, "the debuff alone")
	_state.player.energy = 20.0
	assert_eq(_state.walk_speed_factor(), 0.6, "low energy (0.8) is faster than the debuff")
	_state.player.energy = 10.0
	assert_eq(_state.walk_speed_factor(), 0.4, "very low energy is slower than the debuff")


func test_the_speed_factor_scales_how_far_the_player_walks() -> void:
	var start := _state.player.position
	_state.player.move(_world, Vector2.RIGHT, 0.1, 0.5)
	assert_almost_eq(_state.player.position.x - start.x, PlayerState.SPEED * 0.1 * 0.5, 0.0001)


# --- Eating ---


func test_eating_restores_energy_and_uses_up_one() -> void:
	_state.player.energy = 50.0
	_state.player.inventory.add(ItemTypes.TURNIP, 2)
	_hold(ItemTypes.TURNIP)
	assert_true(_state.eat_held())
	assert_eq(_state.player.energy, 58.0)
	assert_eq(_state.player.inventory.count_of(ItemTypes.TURNIP), 1)


func test_eating_stops_at_the_full_bar() -> void:
	_state.player.energy = 98.0
	_state.player.inventory.add(ItemTypes.BERRIES, 1)
	_hold(ItemTypes.BERRIES)
	assert_true(_state.eat_held())
	assert_eq(_state.player.energy, 100.0)


func test_eating_on_a_full_bar_does_nothing() -> void:
	_state.player.inventory.add(ItemTypes.BERRIES, 1)
	_hold(ItemTypes.BERRIES)
	assert_false(_state.eat_held())
	assert_eq(_state.player.inventory.count_of(ItemTypes.BERRIES), 1)


func test_eating_on_a_debuff_day_stops_at_the_debuff_cap() -> void:
	_state.pass_out()
	_state.player.energy = 38.0
	_state.player.inventory.add(ItemTypes.TURNIP, 1)
	_hold(ItemTypes.TURNIP)
	assert_true(_state.eat_held())
	assert_eq(_state.player.energy, 40.0)


func test_a_held_item_that_is_no_food_is_not_eaten() -> void:
	_state.player.energy = 50.0
	_hold(ItemTypes.HOE)
	assert_false(_state.eat_held())
	assert_eq(_state.player.energy, 50.0)
