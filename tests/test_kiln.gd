extends ResourceCase
## The kiln fires over time: a firing takes its materials, holds them for its hours (on the game
## clock, also while the player is away and through a save), and gives the bricks when the kiln's
## menu is opened. And the mason's other recipes, the raw bricks at the workbench.

const FIRING_MINUTES := 12 * GameClock.MINUTES_PER_HOUR

var _crafting: Crafting
var _kiln: WorldObject
var _workbench: WorldObject


func before_each() -> void:
	super.before_each()
	_crafting = Crafting.new(_state)
	_kiln = _place(WorldObjectTypes.KILN)
	_workbench = _place_beside(WorldObjectTypes.WORKBENCH)
	_state.player.inventory.add(ItemTypes.RAW_BRICK, 6)
	_state.player.inventory.add(ItemTypes.LOGS, 2)


func _problems_of(recipe: Dictionary) -> Array[String]:
	var base := {"result": "brick", "count": 1, "materials": {"clay": 1}}
	return RecipeRules.new({"thing": base.merged(recipe)}).problems()


# --- The data ---


func test_bricks_are_moulded_at_the_workbench_and_fired_in_the_kiln_for_twelve_hours() -> void:
	var rules := RecipeRules.default_rules()
	assert_eq(rules.station_of(&"raw_bricks"), &"workbench")
	assert_eq(rules.hours(&"raw_bricks"), 0.0)
	assert_eq(
		rules.recipes_at(&"kiln"),
		[&"bricks", &"bricks_large", &"bricks_master"] as Array[StringName]
	)
	assert_eq(rules.hours(&"bricks"), 12.0)


func test_bad_hours_are_reported() -> void:
	assert_eq(_problems_of({"station": "kiln", "hours": 0}).size(), 1, "none")
	assert_eq(_problems_of({"station": "kiln", "hours": "long"}).size(), 1, "not a number")
	assert_eq(
		_problems_of({"hours": 5}),
		["[thing] a recipe with hours needs a station to hold it"] as Array[String]
	)
	assert_eq(_problems_of({"station": "kiln", "hours": 1.5}), [] as Array[String])


func test_clay_makes_raw_bricks_and_a_practised_hand_more_of_them() -> void:
	_state.player.inventory.add(ItemTypes.CLAY, 4)
	assert_eq(_crafting.craft(&"raw_bricks", _workbench), Crafting.Result.CRAFTED)
	assert_eq(_count(ItemTypes.RAW_BRICK), 6 + 2)
	assert_true(_crafting.is_locked(&"raw_bricks_true"))
	_state.player.skills.set_points(&"masonry", 25.0)
	assert_eq(_crafting.craft(&"raw_bricks_true", _workbench), Crafting.Result.CRAFTED)
	assert_eq(_count(ItemTypes.RAW_BRICK), 6 + 2 + 3)


# --- Firing ---


func test_a_firing_without_cost_does_not_tell_of_an_inventory_change() -> void:
	_state.cheats.is_cost_off = true
	var changes := []
	var count_change := func() -> void: changes.append(true)
	_state.player.inventory.changed.connect(count_change)
	assert_eq(_crafting.craft(&"bricks", _kiln), Crafting.Result.STARTED)
	_state.player.inventory.changed.disconnect(count_change)
	assert_eq(changes, [])


func test_a_firing_takes_the_materials_into_the_kiln_and_teaches_masonry() -> void:
	assert_eq(_crafting.craft(&"bricks", _kiln), Crafting.Result.STARTED)
	assert_eq(_count(ItemTypes.RAW_BRICK), 0)
	assert_eq(_count(ItemTypes.LOGS), 0)
	assert_eq(_count(ItemTypes.BRICK), 0, "nothing comes out yet")
	assert_true(StationWork.is_busy(_kiln))
	assert_eq(_crafting.minutes_left(_kiln), FIRING_MINUTES)
	assert_eq(_state.player.skills.points(&"masonry"), 2.0)


func test_a_busy_kiln_takes_no_second_firing() -> void:
	_crafting.craft(&"bricks", _kiln)
	_state.player.inventory.add(ItemTypes.RAW_BRICK, 6)
	_state.player.inventory.add(ItemTypes.LOGS, 2)
	assert_eq(_crafting.craft(&"bricks", _kiln), Crafting.Result.BUSY)
	assert_eq(_count(ItemTypes.RAW_BRICK), 6)


func test_the_firing_is_done_after_its_hours_and_the_bricks_come_out() -> void:
	_crafting.craft(&"bricks", _kiln)
	_state.simulation.advance(FIRING_MINUTES - 1)
	assert_false(_crafting.is_work_done(_kiln))
	_state.simulation.advance(1)
	assert_true(_crafting.is_work_done(_kiln))
	assert_eq(_crafting.take_out(_kiln), Crafting.Result.TAKEN_OUT)
	assert_eq(_count(ItemTypes.BRICK), 6)
	assert_false(StationWork.is_busy(_kiln))


func test_bricks_that_do_not_fit_are_dropped_by_the_kiln_on_the_players_side() -> void:
	_crafting.craft(&"bricks", _kiln)
	_state.simulation.advance(FIRING_MINUTES)
	_fill_inventory()
	_state.player.inventory.slots[0] = {"item": ItemTypes.BRICK, "count": 95}
	assert_eq(_crafting.take_out(_kiln), Crafting.Result.DROPPED_OUT)
	assert_false(StationWork.is_busy(_kiln))
	assert_eq(_count(ItemTypes.BRICK), 99)
	assert_eq(_world.ground_items.count_of(ItemTypes.BRICK), 2)
	var by_the_kiln := _world.ground_items.all()[0]
	assert_lt(by_the_kiln.position.distance_to(Vector2(_state.player.tile())), 2.5)


func test_the_firing_goes_on_through_a_save_and_while_the_player_is_away() -> void:
	_crafting.craft(&"bricks", _kiln)
	_state.simulation.advance(60)
	var restored := _through_save()
	var kiln := restored.world.object_at(_tile)
	assert_true(StationWork.is_busy(kiln))
	assert_eq(StationWork.recipe(kiln), &"bricks")
	var crafting := Crafting.new(restored)
	assert_eq(crafting.minutes_left(kiln), FIRING_MINUTES - 60)
	restored.player.position += Vector2(500, 0)
	restored.simulation.advance(FIRING_MINUTES)
	assert_true(crafting.is_work_done(kiln), "done without the kiln being looked at")


func test_a_kiln_broken_down_gives_back_its_load_or_its_bricks() -> void:
	_crafting.craft(&"bricks", _kiln)
	_state.player.inventory.add(ItemTypes.PICKAXE, 1)
	_hit(ItemTypes.PICKAXE, 4)
	assert_eq(_dropped(ItemTypes.RAW_BRICK), 6, "unfired, the load comes back")
	assert_eq(_dropped(ItemTypes.LOGS), 2)
	assert_eq(_dropped(ItemTypes.KILN), 1)
	_clear_ground()
	var fired := _place(WorldObjectTypes.KILN)
	StationWork.start(fired, &"bricks", _state.clock.total_minutes())
	_hit(ItemTypes.PICKAXE, 4)
	assert_eq(_dropped(ItemTypes.BRICK), 6)


# --- The menu ---


func test_the_kiln_menu_says_what_it_fires_and_takes_the_bricks_out_once_done() -> void:
	var screen := CraftingScreen.new()
	add_child_autofree(screen)
	screen.show_crafting(_crafting, _state.player.inventory)
	screen.open_station(_kiln)
	var rows := screen.find_children("*", "RecipeRow", true, false)
	rows[0].pressed.emit()
	var texts := func() -> Array:
		return screen.find_children("*", "Label", true, false).map(
			func(label: Label) -> String: return label.text if label.is_visible_in_tree() else ""
		)
	assert_has(texts.call(), "Brick x6: ready in 12 h 0 min")
	assert_true(rows[0].disabled, "busy")
	screen.close()
	_state.simulation.advance(FIRING_MINUTES)
	screen.open_station(_kiln)
	assert_has(texts.call(), CraftingScreen.TAKEN_OUT_NOTE % "brick x6")
	assert_eq(_count(ItemTypes.BRICK), 6)


# --- One change at a time ---


## What the inventory shows each time it says it changed while `action` runs.
func _seen_during(action: Callable) -> Array:
	var seen := []
	var inventory := _state.player.inventory
	var record := func() -> void:
		(
			seen
			. append(
				{
					"clay": inventory.count_of(ItemTypes.CLAY),
					"raw_bricks": _count(ItemTypes.RAW_BRICK),
					"bricks": _count(ItemTypes.BRICK),
					"busy": StationWork.is_busy(_kiln),
				}
			)
		)
	inventory.changed.connect(record)
	action.call()
	inventory.changed.disconnect(record)
	return seen


func test_a_craft_tells_of_the_materials_and_the_result_in_one_change() -> void:
	_state.player.inventory.add(ItemTypes.CLAY, 4)
	var seen := _seen_during(func() -> void: _crafting.craft(&"raw_bricks", _workbench))
	assert_eq(seen.size(), 1)
	assert_eq(seen[0]["clay"], 2, "clay paid, result in, in the one notification")
	assert_eq(seen[0]["raw_bricks"], 6 + 2)


func test_starting_a_firing_tells_of_the_materials_once() -> void:
	var seen := _seen_during(func() -> void: _crafting.craft(&"bricks", _kiln))
	assert_eq(seen.size(), 1)
	assert_eq(seen[0]["raw_bricks"], 0)


func test_taking_out_the_bricks_clears_the_kiln_before_the_inventory_tells() -> void:
	_crafting.craft(&"bricks", _kiln)
	_state.simulation.advance(FIRING_MINUTES)
	var seen := _seen_during(func() -> void: _crafting.take_out(_kiln))
	assert_eq(seen.size(), 1)
	assert_eq(seen[0]["bricks"], 6)
	assert_false(seen[0]["busy"])
