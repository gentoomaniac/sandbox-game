extends GutTest
## The filter rule of a process station's grid (ProcessLoad), with recipes of test config: the
## user's example of a wood and stone recipe beside a coal and stone one (clay stands in for coal,
## which the game has not), with quantities; and the recipe `bonus` key it counts with.

## Two stone and a log, or a stone and a coal (clay): in a grid of three slots, 99 loads of each
## fit (198 or 99 stone).
const RECIPES := {
	"wood": {"result": "brick", "count": 1, "materials": {"stone": 2, "logs": 1}},
	"coal": {"result": "brick", "count": 1, "materials": {"stone": 1, "clay": 1}},
}
const SLOT_COUNT := 3

var _rules: RecipeRules
var _load: ProcessLoad


func before_each() -> void:
	_rules = RecipeRules.new(RECIPES)
	_load = ProcessLoad.new(_rules, [&"wood", &"coal"] as Array[StringName], SLOT_COUNT)


func _open(contents: Dictionary) -> Array[StringName]:
	return _load.open_recipes(contents)


# --- The bonus key ---


func _problems_of(bonus: Variant) -> Array[String]:
	var recipe := {"result": "brick", "count": 6, "materials": {"clay": 1}, "skill": "masonry"}
	recipe["bonus"] = bonus
	return RecipeRules.new({"thing": recipe}).problems()


func test_a_bonus_is_rising_steps_of_points_and_shares() -> void:
	assert_eq(_problems_of([[50, 0.25], [70, 0.5]]), [] as Array[String])
	assert_eq(_problems_of([]).size(), 1, "empty")
	assert_eq(_problems_of([[70, 0.5], [50, 0.25]]).size(), 1, "falling points")
	assert_eq(_problems_of([[50, 0.5], [70, 0.25]]).size(), 1, "falling shares")
	assert_eq(_problems_of([[50, 0]]).size(), 1, "no share")
	assert_eq(_problems_of([50, 0.25]).size(), 1, "not a list of steps")
	var without_skill := RecipeRules.new(
		{"thing": {"result": "brick", "count": 1, "materials": {"clay": 1}, "bonus": [[1, 0.5]]}}
	)
	assert_eq(without_skill.problems(), ["[thing] a bonus needs a skill"] as Array[String])


func test_the_highest_bonus_step_reached_counts_and_the_extra_is_rounded_down() -> void:
	var rules := (
		RecipeRules
		. new(
			{
				"bricks":
				{
					"result": "brick",
					"count": 6,
					"materials": {"raw_brick": 6},
					"skill": "masonry",
					"bonus": [[50, 0.25], [70, 0.5]],
				}
			}
		)
	)
	assert_eq(rules.bonus_share(&"bricks", 49.9), 0.0)
	assert_eq(rules.bonus_share(&"bricks", 50.0), 0.25)
	assert_eq(rules.bonus_share(&"bricks", 80.0), 0.5)
	assert_eq(ProcessLoad.result_count(rules, &"bricks", 1, 0.0), 6)
	assert_eq(
		ProcessLoad.result_count(rules, &"bricks", 1, 50.0), 7, "6 and a quarter of 6, rounded down"
	)
	assert_eq(ProcessLoad.result_count(rules, &"bricks", 3, 70.0), 27)
	assert_eq(ProcessLoad.result_count(_rules, &"wood", 4, 100.0), 4, "no bonus")


# --- What fits ---


func test_slots_are_counted_packed() -> void:
	assert_eq(ProcessLoad.slots_for({}), 0)
	assert_eq(ProcessLoad.slots_for({ItemTypes.STONE: 99, ItemTypes.LOGS: 1}), 2)
	assert_eq(ProcessLoad.slots_for({ItemTypes.STONE: 100}), 2)
	assert_eq(ProcessLoad.slots_for({ItemTypes.HOE: 3}), 3, "one to a slot")


func test_the_most_loads_are_those_whose_materials_fit_the_grid() -> void:
	assert_eq(_load.most_loads(&"wood"), 99, "198 stone in two slots and 99 logs in one")
	assert_eq(_load.most_loads(&"coal"), 99, "a 100th load would need four slots")


func test_the_most_loads_leave_room_for_the_result_at_the_highest_bonus() -> void:
	var rules := (
		RecipeRules
		. new(
			{
				"bricks":
				{
					"result": "brick",
					"count": 2,
					"materials": {"raw_brick": 1},
					"skill": "masonry",
					"bonus": [[50, 0.5]],
				}
			}
		)
	)
	var single := ProcessLoad.new(rules, [&"bricks"] as Array[StringName], 1)
	assert_eq(single.most_loads(&"bricks"), 33, "33 loads make 99 bricks at the bonus")


# --- The user's example: wood and stone, coal and stone ---


func test_an_empty_grid_leaves_every_recipe_open_and_takes_only_their_materials() -> void:
	assert_eq(_open({}), [&"wood", &"coal"] as Array[StringName])
	assert_eq(_load.room_for(ItemTypes.STONE, {}), 198)
	assert_eq(_load.room_for(ItemTypes.LOGS, {}), 99)
	assert_eq(_load.room_for(ItemTypes.CLAY, {}), 99)
	assert_eq(_load.room_for(ItemTypes.BERRIES, {}), 0, "in no recipe")


func test_stone_first_still_takes_wood_and_coal() -> void:
	var contents := {ItemTypes.STONE: 3}
	assert_eq(_open(contents), [&"wood", &"coal"] as Array[StringName])
	assert_gt(_load.room_for(ItemTypes.LOGS, contents), 0)
	assert_gt(_load.room_for(ItemTypes.CLAY, contents), 0)


func test_coal_first_takes_only_stone() -> void:
	var contents := {ItemTypes.CLAY: 1}
	assert_eq(_open(contents), [&"coal"] as Array[StringName])
	assert_eq(_load.room_for(ItemTypes.STONE, contents), 99)
	assert_eq(_load.room_for(ItemTypes.LOGS, contents), 0)


func test_wood_with_the_stone_shuts_the_coal_recipe() -> void:
	var contents := {ItemTypes.STONE: 4, ItemTypes.LOGS: 1}
	assert_eq(_open(contents), [&"wood"] as Array[StringName])
	assert_eq(_load.room_for(ItemTypes.CLAY, contents), 0)


func test_more_stone_than_the_coal_recipe_fits_shuts_it_and_leaves_the_wood_one() -> void:
	assert_eq(_load.room_for(ItemTypes.STONE, {ItemTypes.STONE: 90}), 108)
	var contents := {ItemTypes.STONE: 120}
	assert_eq(_open(contents), [&"wood"] as Array[StringName])
	assert_eq(_load.room_for(ItemTypes.CLAY, contents), 0)
	assert_eq(_load.room_for(ItemTypes.LOGS, contents), 99)
	assert_eq(_load.room_for(ItemTypes.STONE, contents), 78, "up to 198")


func test_more_than_any_recipe_fits_leaves_none_open() -> void:
	assert_eq(_open({ItemTypes.STONE: 199}), [] as Array[StringName])
	assert_eq(_load.room_for(ItemTypes.STONE, {ItemTypes.STONE: 199}), 0)


func test_taking_out_opens_recipes_again() -> void:
	assert_eq(_open({ItemTypes.STONE: 120, ItemTypes.LOGS: 2}), [&"wood"] as Array[StringName])
	assert_eq(_open({ItemTypes.STONE: 120}), [&"wood"] as Array[StringName])
	assert_eq(_open({ItemTypes.STONE: 60}), [&"wood", &"coal"] as Array[StringName])


func test_the_load_count_of_contents() -> void:
	assert_eq(_load.loads_holding(&"wood", {}), 0)
	assert_eq(_load.loads_holding(&"wood", {ItemTypes.STONE: 5}), 3)
	assert_eq(_load.loads_holding(&"wood", {ItemTypes.STONE: 2, ItemTypes.LOGS: 4}), 4)
	assert_eq(_load.loads_holding(&"wood", {ItemTypes.CLAY: 1}), -1, "not a material")


# --- Whole loads ---


func test_only_whole_loads_run() -> void:
	assert_eq(_load.whole_loads(&"wood", {}), 0)
	assert_eq(_load.whole_loads(&"wood", {ItemTypes.STONE: 4, ItemTypes.LOGS: 2}), 2)
	assert_eq(_load.whole_loads(&"wood", {ItemTypes.STONE: 4, ItemTypes.LOGS: 1}), 0, "part")
	assert_eq(_load.whole_loads(&"wood", {ItemTypes.STONE: 4}), 0, "no logs")
	assert_eq(_load.runnable_recipe({ItemTypes.STONE: 4}), &"")
	assert_eq(_load.runnable_recipe({ItemTypes.STONE: 3, ItemTypes.CLAY: 3}), &"coal")


func test_of_two_recipes_with_whole_loads_the_first_in_the_file_runs() -> void:
	var rules := (
		RecipeRules
		. new(
			{
				"small": {"result": "brick", "count": 1, "materials": {"clay": 1, "stone": 1}},
				"large": {"result": "brick", "count": 3, "materials": {"clay": 2, "stone": 2}},
			}
		)
	)
	var both := ProcessLoad.new(rules, [&"small", &"large"] as Array[StringName], 9)
	assert_eq(both.runnable_recipe({ItemTypes.CLAY: 2, ItemTypes.STONE: 2}), &"small")
	assert_eq(both.runnable_recipe({ItemTypes.CLAY: 1, ItemTypes.STONE: 1}), &"small")


func test_a_part_load_says_what_the_next_whole_load_lacks() -> void:
	assert_eq(_load.missing(&"wood", {}), {ItemTypes.STONE: 2, ItemTypes.LOGS: 1})
	assert_eq(_load.missing(&"wood", {ItemTypes.STONE: 3}), {ItemTypes.STONE: 1, ItemTypes.LOGS: 2})
	assert_eq(_load.missing(&"wood", {ItemTypes.STONE: 2, ItemTypes.LOGS: 1}), {})


# --- Amounts ---


func test_the_amount_is_held_to_the_materials_carried_and_the_grid() -> void:
	var carried := {ItemTypes.STONE: 10, ItemTypes.LOGS: 3}
	assert_eq(_load.least_amount(&"wood", {}), 1)
	assert_eq(_load.most_amount(&"wood", {}, carried), 3, "three logs")
	carried = {ItemTypes.STONE: 500, ItemTypes.LOGS: 500}
	assert_eq(_load.most_amount(&"wood", {}, carried), 99, "the grid")
	assert_eq(_load.most_amount(&"wood", {}, {}), 0)


func test_the_amount_counts_what_is_in_the_grid() -> void:
	var contents := {ItemTypes.STONE: 6}
	var carried := {ItemTypes.LOGS: 5}
	assert_eq(_load.least_amount(&"wood", contents), 3, "the stone is three loads")
	assert_eq(_load.most_amount(&"wood", contents, carried), 3, "no more stone")
	assert_true(_load.can_fill(&"wood", contents, carried))
	assert_false(_load.can_fill(&"wood", contents, {ItemTypes.LOGS: 2}), "a log short")
	assert_false(_load.can_fill(&"coal", {ItemTypes.STONE: 120}, {ItemTypes.CLAY: 200}), "too much")
	assert_false(_load.can_fill(&"coal", {ItemTypes.LOGS: 1}, {ItemTypes.CLAY: 9}), "shut")
