extends ResourceCase
## Where a recipe is made: at a station of its kind on the player's map within their reach. A
## refusal takes nothing, starts nothing and teaches nothing.

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


func _assert_refused_without_side_effects(
	station: WorldObject, result: Crafting.Result, message: String
) -> void:
	var before := _state.player.inventory.totals()
	assert_eq(_crafting.craft(&"bricks", station), result, message)
	assert_eq(_state.player.inventory.totals(), before, message)
	assert_false(StationWork.is_busy(_kiln), message)
	assert_eq(_state.player.skills.points(&"masonry"), 0.0, message)


func test_a_firing_is_refused_at_a_workbench_without_taking_anything() -> void:
	_assert_refused_without_side_effects(
		_workbench, Crafting.Result.WRONG_STATION, "a workbench is no kiln"
	)
	assert_false(StationWork.is_busy(_workbench), "nothing was started at the workbench")


func test_a_firing_is_refused_without_a_station_or_at_one_that_is_not_on_the_map() -> void:
	_assert_refused_without_side_effects(null, Crafting.Result.NO_STATION, "no station")
	var unattached := WorldObject.new(WorldObjectTypes.KILN, Vector2i(999, 999))
	_assert_refused_without_side_effects(
		unattached, Crafting.Result.NO_STATION, "a kiln that stands nowhere"
	)


func test_a_firing_is_refused_out_of_reach_and_works_again_in_reach() -> void:
	_state.player.position += Vector2(5.0, 0.0)
	_assert_refused_without_side_effects(
		_kiln, Crafting.Result.NO_STATION, "a kiln five tiles away"
	)
	_state.player.position -= Vector2(5.0, 0.0)
	assert_eq(_crafting.craft(&"bricks", _kiln), Crafting.Result.STARTED)


func test_the_menu_says_why_a_firing_is_refused_when_the_player_has_walked_off() -> void:
	var screen := CraftingScreen.new()
	add_child_autofree(screen)
	screen.show_crafting(_crafting, _state.player.inventory)
	screen.open_station(_kiln)
	_state.player.position += Vector2(5.0, 0.0)
	var before := _state.player.inventory.totals()
	screen.find_children("*", "RecipeRow", true, false)[0].pressed.emit()
	var notes := screen.find_children("*", "Label", true, false).map(
		func(label: Label) -> String: return label.text
	)
	assert_has(notes, CraftingScreen.NO_STATION_NOTE)
	assert_eq(_state.player.inventory.totals(), before)


func test_a_firing_is_refused_at_a_kiln_of_the_other_map() -> void:
	var house: Building = null
	for y in range(-12, 13):
		for x in range(-12, 13):
			var origin := _state.player.tile() + Vector2i(x, y)
			if house == null and _world.placement_blockers(BuildingTypes.KATE, origin).is_empty():
				house = _world.place_building(BuildingTypes.KATE, origin)
	_state.player.position = Vector2(house.door_tile()) + Vector2(0.5, 0.5)
	_state.pass_door()
	assert_true(_state.is_inside())
	_assert_refused_without_side_effects(_kiln, Crafting.Result.NO_STATION, "a kiln outside")


func test_the_finished_firing_stays_in_the_kiln_while_the_player_is_out_of_reach() -> void:
	_crafting.craft(&"bricks", _kiln)
	_state.simulation.advance(FIRING_MINUTES)
	_state.player.position += Vector2(5.0, 0.0)
	assert_false(_crafting.take_out(_kiln))
	assert_true(StationWork.is_busy(_kiln))
