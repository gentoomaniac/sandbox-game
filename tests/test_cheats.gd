extends EnergyCase
## The cheats the console switches on, and what they change.

var _console: Console


func before_each() -> void:
	super.before_each()
	_console = Console.new(_state)


func test_each_toggle_switches_on_and_off() -> void:
	assert_eq(_console.run("god"), ["God mode on"] as Array[String])
	assert_eq(_console.run("god"), ["God mode off"] as Array[String])
	assert_eq(_console.run("nodrain"), ["No drain on"] as Array[String])
	assert_eq(_console.run("noweight"), ["No weight on"] as Array[String])
	assert_eq(_state.cheats.active_names(), ["No drain", "No weight"] as Array[String])


func test_the_hud_names_every_cheat_that_is_on_including_no_cost() -> void:
	_console.run("nocost")
	assert_eq(_state.cheats.active_names(), ["No cost"] as Array[String])
	_console.run("god")
	assert_eq(_state.cheats.active_names(), ["God", "No cost"] as Array[String])


func test_nodrain_makes_actions_free() -> void:
	_console.run("nodrain")
	_hit(ItemTypes.HOE, 1)
	assert_eq(_state.player.energy, PlayerState.MAX_ENERGY)


func test_noweight_drops_the_weight_surcharge() -> void:
	_state.player.inventory.add(ItemTypes.STONE, 50)
	_hit(ItemTypes.HOE, 1)
	var heavy_cost := PlayerState.MAX_ENERGY - _state.player.energy
	assert_gt(heavy_cost, RULES["cost"]["till"])
	_state.player.energy = PlayerState.MAX_ENERGY
	_console.run("noweight")
	_world.set_terrain(_tile, Tile.Terrain.GRASS)
	_state.use_tile(_tile)
	assert_almost_eq(PlayerState.MAX_ENERGY - _state.player.energy, 4.0, 0.001)


func test_god_keeps_the_health_through_a_pass_out() -> void:
	_console.run("god")
	_state.pass_out()
	assert_eq(_state.player.health, PlayerState.MAX_HEALTH)
	assert_true(_state.player.is_debuffed)


func test_without_god_a_pass_out_costs_health() -> void:
	_state.pass_out()
	assert_eq(_state.player.health, RULES["debuff"]["health"])
