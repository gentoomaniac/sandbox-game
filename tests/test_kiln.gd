extends ResourceCase
## The kiln and the bake oven are process stations (task 199): a 3x3 grid, filled with whole loads
## of one recipe and started with the fire button; a firing takes its hours on the game clock (also
## while the player is away and through a save) and leaves what it made in the grid. The mason's
## bonus, the oven's bread, a kiln taken down, and the raw bricks at the workbench.

const FIRING_MINUTES := 12 * GameClock.MINUTES_PER_HOUR

var _kiln: ProcessStation
var _workbench: WorldObject


func before_each() -> void:
	super.before_each()
	_kiln = ProcessStation.new(_state, Crafting.new(_state), _place(WorldObjectTypes.KILN))
	_workbench = _place_beside(WorldObjectTypes.WORKBENCH)
	_state.player.inventory.add(ItemTypes.RAW_BRICK, 6)
	_state.player.inventory.add(ItemTypes.LOGS, 2)


func _grid() -> Dictionary:
	return _kiln.grid.totals()


# --- The data ---


func test_the_kiln_and_the_oven_are_process_stations_of_three_by_three_with_a_fire() -> void:
	var stations := StationRules.default_rules()
	for station: StringName in [&"kiln", &"oven"]:
		assert_true(stations.is_process(station), str(station))
		assert_eq(stations.grid_size(station), Vector2i(3, 3))
		assert_eq(stations.button_icon(station), "res://assets/ui/process_fire.png")
	assert_false(stations.is_process(&"workbench"))
	assert_false(stations.is_process(&"hearth"))
	assert_eq(WorldObject.new(WorldObjectTypes.OVEN, Vector2i.ZERO).storage.slots.size(), 9)


func test_the_kiln_fires_one_bricks_recipe_for_twelve_hours_with_logs() -> void:
	var rules := RecipeRules.default_rules()
	assert_eq(rules.recipes_at(&"kiln"), [&"bricks"] as Array[StringName])
	assert_eq(rules.hours(&"bricks"), 12.0)
	assert_eq(rules.materials(&"bricks"), {ItemTypes.RAW_BRICK: 6, ItemTypes.LOGS: 2})
	assert_eq(rules.station_of(&"raw_bricks"), &"workbench")
	assert_eq(rules.hours(&"raw_bricks"), 0.0)


func test_every_oven_recipe_bakes_for_a_time_with_a_log_and_keeps_its_level() -> void:
	var rules := RecipeRules.default_rules()
	assert_eq(
		rules.recipes_at(&"oven"), [&"bread", &"berry_tart", &"feast_cake"] as Array[StringName]
	)
	for recipe_id in rules.recipes_at(&"oven"):
		assert_gt(rules.hours(recipe_id), 0.0, str(recipe_id))
		assert_has(rules.materials(recipe_id), ItemTypes.LOGS, str(recipe_id))
	assert_eq(rules.hours(&"bread"), 1.0)
	assert_eq(rules.level(&"bread"), 30.0)
	assert_eq(rules.level(&"feast_cake"), 70.0)


func test_hours_belong_to_the_recipes_of_a_process_station_only() -> void:
	var problems_of := func(recipe: Dictionary) -> Array[String]:
		var base := {"result": "brick", "count": 1, "materials": {"clay": 1}}
		return RecipeRules.new({"thing": base.merged(recipe)}).problems()
	assert_eq(problems_of.call({"station": "kiln", "hours": 0}).size(), 1, "none")
	assert_eq(problems_of.call({"station": "kiln", "hours": "long"}).size(), 1, "not a number")
	assert_eq(problems_of.call({"station": "kiln"}).size(), 1, "a kiln recipe needs hours")
	assert_eq(problems_of.call({"station": "workbench", "hours": 2}).size(), 1, "not a process")
	assert_eq(problems_of.call({"hours": 5}).size(), 1, "by hand")
	assert_eq(problems_of.call({"station": "kiln", "hours": 1.5}), [] as Array[String])


func test_clay_makes_raw_bricks_and_a_practised_hand_more_of_them() -> void:
	var crafting := Crafting.new(_state)
	_state.player.inventory.add(ItemTypes.CLAY, 4)
	assert_eq(crafting.craft(&"raw_bricks", _workbench), Crafting.Result.CRAFTED)
	assert_eq(_count(ItemTypes.RAW_BRICK), 6 + 2)
	assert_true(crafting.is_locked(&"raw_bricks_true"))
	_state.player.skills.set_points(&"masonry", 25.0)
	assert_eq(crafting.craft(&"raw_bricks_true", _workbench), Crafting.Result.CRAFTED)
	assert_eq(_count(ItemTypes.RAW_BRICK), 6 + 2 + 3)


# --- Firing ---


func test_a_firing_takes_its_load_and_teaches_masonry() -> void:
	assert_true(_kiln.fill(&"bricks", 1))
	assert_eq(_count(ItemTypes.RAW_BRICK), 0)
	assert_eq(_count(ItemTypes.LOGS), 0)
	assert_true(_kiln.start())
	assert_eq(_kiln.minutes_left(), FIRING_MINUTES)
	assert_eq(_state.player.skills.points(&"masonry"), 2.0)


func test_the_firing_is_done_after_its_hours_and_the_bricks_are_in_the_kiln() -> void:
	_kiln.fill(&"bricks", 1)
	_kiln.start()
	_state.simulation.advance(FIRING_MINUTES - 1)
	assert_true(_kiln.is_running())
	_state.simulation.advance(1)
	assert_true(_kiln.holds_results())
	assert_eq(_grid(), {ItemTypes.BRICK: 6})
	_kiln.send_out(0)
	assert_eq(_count(ItemTypes.BRICK), 6)
	assert_false(_kiln.holds_results())


func test_a_skilled_mason_gets_more_bricks_from_the_same_fire() -> void:
	_state.player.inventory.add(ItemTypes.RAW_BRICK, 12)
	_state.player.inventory.add(ItemTypes.LOGS, 4)
	_state.player.skills.set_points(&"masonry", 50.0)
	_kiln.fill(&"bricks", 3)
	_kiln.start()
	_state.simulation.advance(FIRING_MINUTES)
	assert_true(_kiln.holds_results())
	assert_eq(_grid(), {ItemTypes.BRICK: 18 + 4}, "a quarter of 18, rounded down")
	_kiln.send_out(0)
	_state.player.inventory.add(ItemTypes.RAW_BRICK, 18)
	_state.player.inventory.add(ItemTypes.LOGS, 6)
	_state.player.skills.set_points(&"masonry", 70.0)
	_kiln.fill(&"bricks", 3)
	_kiln.start()
	_state.simulation.advance(FIRING_MINUTES)
	assert_true(_kiln.holds_results())
	assert_eq(_grid(), {ItemTypes.BRICK: 27}, "half again")


func test_the_grid_and_the_firing_go_on_through_a_save_and_while_the_player_is_away() -> void:
	_kiln.fill(&"bricks", 1)
	_kiln.start()
	_state.simulation.advance(60)
	var restored := _through_save()
	var object := restored.world.object_at(_tile)
	assert_eq(object.storage.totals(), {ItemTypes.RAW_BRICK: 6, ItemTypes.LOGS: 2})
	var kiln := ProcessStation.new(restored, Crafting.new(restored), object)
	assert_true(kiln.is_running())
	assert_eq(kiln.minutes_left(), FIRING_MINUTES - 60)
	restored.player.position += Vector2(500, 0)
	restored.simulation.advance(FIRING_MINUTES)
	assert_true(kiln.holds_results(), "done without the kiln being looked at")
	assert_eq(object.storage.totals(), {ItemTypes.BRICK: 6})


func test_an_idle_grid_is_kept_through_a_save() -> void:
	_kiln.fill(&"bricks", 1)
	var restored := _through_save()
	assert_eq(
		restored.world.object_at(_tile).storage.totals(),
		{ItemTypes.RAW_BRICK: 6, ItemTypes.LOGS: 2}
	)


func test_a_kiln_broken_down_gives_back_its_load_or_its_bricks() -> void:
	_kiln.fill(&"bricks", 1)
	_kiln.start()
	_state.player.inventory.add(ItemTypes.RUSTY_IRON_PICKAXE, 1)
	_hit(ItemTypes.RUSTY_IRON_PICKAXE, 4)
	assert_eq(_dropped(ItemTypes.RAW_BRICK), 6, "unfired, the load comes back")
	assert_eq(_dropped(ItemTypes.LOGS), 2)
	assert_eq(_dropped(ItemTypes.KILN), 1)
	_clear_ground()
	var fired := ProcessStation.new(_state, Crafting.new(_state), _place(WorldObjectTypes.KILN))
	_state.player.inventory.add(ItemTypes.RAW_BRICK, 6)
	_state.player.inventory.add(ItemTypes.LOGS, 2)
	fired.fill(&"bricks", 1)
	fired.start()
	_state.simulation.advance(FIRING_MINUTES)
	_hit(ItemTypes.RUSTY_IRON_PICKAXE, 4)
	assert_eq(_dropped(ItemTypes.BRICK), 6, "fired, unseen")
	assert_eq(_dropped(ItemTypes.RAW_BRICK), 0)


# --- The oven ---


func test_the_oven_bakes_bread_in_an_hour() -> void:
	_world.remove_object(_tile + Vector2i.RIGHT)
	var oven := ProcessStation.new(
		_state, Crafting.new(_state), _place_beside(WorldObjectTypes.OVEN)
	)
	_state.player.inventory.add(ItemTypes.FLOUR, 8)
	assert_false(oven.can_fill(&"bread"), "the cook needs level 30")
	_state.player.skills.set_points(&"cooking", 30.0)
	assert_eq(oven.amounts(&"bread"), Vector2i(1, 2), "two logs")
	oven.fill(&"bread", 2)
	assert_true(oven.start())
	_state.simulation.advance(GameClock.MINUTES_PER_HOUR)
	assert_true(oven.holds_results())
	assert_eq(oven.grid.totals(), {ItemTypes.BREAD: 4})


## Everything the player has, carried and in the grid, item id to count.
func _everything(oven: ProcessStation) -> Dictionary:
	var all := _state.player.inventory.totals()
	var held := oven.grid.totals()
	for item: StringName in held:
		all[item] = all.get(item, 0) + held[item]
	return all


func test_a_grid_left_in_small_stacks_loses_nothing_to_a_recipe_click() -> void:
	# The review's case: 692 flour put in for bread, then taken out onto stacks of one flour each,
	# seven times (each leaves a small stack behind), and a click on 9 berry tarts.
	_world.remove_object(_tile + Vector2i.RIGHT)
	var oven := ProcessStation.new(
		_state, Crafting.new(_state), _place_beside(WorldObjectTypes.OVEN)
	)
	_state.player.skills.set_points(&"cooking", 50.0)
	var inventory := _state.player.inventory
	for slot in inventory.slots.size():
		inventory.slots[slot] = {}
	for slot in 7:
		inventory.slots[slot] = {"item": ItemTypes.FLOUR, "count": 99}
	inventory.slots[7] = {"item": ItemTypes.BERRIES, "count": 99}
	inventory.slots[8] = {"item": ItemTypes.BERRIES, "count": 21}
	inventory.slots[9] = {"item": ItemTypes.LOGS, "count": 9}
	for slot in 7:
		oven.put_in(inventory, slot)
	assert_eq(
		oven.grid.totals(), {ItemTypes.FLOUR: 692}, "a 693rd flour would be a part load too many"
	)
	for slot in 7:
		inventory.slots[slot] = {"item": ItemTypes.FLOUR, "count": 1}
		oven.take_out(0, inventory, slot)
	var before := _everything(oven)
	assert_true(oven.fill(&"berry_tart", 9))
	assert_eq(_everything(oven), before, "nothing lost")
	assert_eq(oven.grid.count_of(ItemTypes.LOGS), 9)


# --- One change at a time ---


func test_a_recipe_click_tells_the_inventory_and_the_grid_once_each() -> void:
	var told := []
	var inventory := _state.player.inventory
	var tell_inventory := func() -> void: told.append(["inventory", _count(ItemTypes.RAW_BRICK)])
	var tell_grid := func() -> void: told.append(["grid", _grid().get(ItemTypes.RAW_BRICK, 0)])
	inventory.changed.connect(tell_inventory)
	_kiln.grid.changed.connect(tell_grid)
	_kiln.fill(&"bricks", 1)
	inventory.changed.disconnect(tell_inventory)
	_kiln.grid.changed.disconnect(tell_grid)
	assert_eq(told, [["grid", 6], ["inventory", 0]], "each sees the move finished")
