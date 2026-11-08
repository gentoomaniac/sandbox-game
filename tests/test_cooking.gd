extends GutTest
## Cooking: the recipes of the cook make food that is worth the cooking, and the first of them
## needs no skill.

const COOK_STATIONS: Array[StringName] = [&"hearth", &"oven"]


func _cooking_recipes() -> Array[StringName]:
	var rules := RecipeRules.default_rules()
	return rules.recipe_ids().filter(
		func(recipe_id: StringName) -> bool: return rules.skill(recipe_id) == &"cooking"
	)


func test_every_cooking_recipe_is_made_at_a_cooks_station() -> void:
	var rules := RecipeRules.default_rules()
	assert_false(_cooking_recipes().is_empty())
	for recipe_id in _cooking_recipes():
		assert_has(COOK_STATIONS, rules.station_of(recipe_id), str(recipe_id))


func test_a_dish_restores_more_energy_than_its_ingredients_eaten_raw() -> void:
	var rules := RecipeRules.default_rules()
	var energy := EnergyRules.default_rules()
	for recipe_id in _cooking_recipes():
		var dish := rules.result(recipe_id)
		assert_true(energy.is_food(dish), "%s is food" % dish)
		var raw := 0.0
		var materials := rules.materials(recipe_id)
		for item: StringName in materials:
			if energy.is_food(item):
				raw += energy.food_restore(item) * materials[item]
		var cooked := energy.food_restore(dish) * rules.count(recipe_id)
		assert_gt(cooked, raw, str(recipe_id))


func test_anyone_can_roast_a_turnip_at_the_campfire_and_learns_from_it() -> void:
	var state := GameState.new_game(7)
	var crafting := Crafting.new(state)
	assert_has(RecipeRules.default_rules().recipes_at(&"hearth"), &"roast_turnip")
	assert_false(crafting.is_locked(&"roast_turnip"))
	assert_eq(crafting.craft(&"roast_turnip"), Crafting.Result.MISSING_MATERIALS)
	state.player.inventory.add(ItemTypes.TURNIP, 1)
	assert_eq(crafting.craft(&"roast_turnip"), Crafting.Result.CRAFTED)
	assert_eq(state.player.inventory.count_of(ItemTypes.ROAST_TURNIP), 1)
	assert_gt(state.player.skills.points(&"cooking"), 0.0)


func test_a_cooked_dish_is_eaten_like_raw_food() -> void:
	var state := GameState.new_game(7)
	state.player.energy = 50.0
	state.player.inventory.slots[0] = {"item": ItemTypes.POTTAGE, "count": 1}
	state.player.inventory.select(0)
	assert_true(state.eat_held())
	assert_eq(
		state.player.energy, 50.0 + EnergyRules.default_rules().food_restore(ItemTypes.POTTAGE)
	)
	assert_string_contains(ItemTooltip.text_for(ItemTypes.POTTAGE), "Food")


func test_bread_is_baked_in_the_oven_from_flour_ground_by_hand() -> void:
	var rules := RecipeRules.default_rules()
	assert_has(rules.recipes_at(&""), &"flour")
	assert_has(rules.recipes_at(&"oven"), &"bread")
	assert_has(rules.recipes_at(&""), &"oven")
	assert_has(rules.materials(&"oven"), ItemTypes.BRICK, "the oven is the mason's work")


func test_buckwheat_is_fried_into_pancakes_at_the_fire() -> void:
	var rules := RecipeRules.default_rules()
	assert_has(rules.recipes_at(&"hearth"), &"buckwheat_pancakes")
	assert_eq(rules.result(&"buckwheat_pancakes"), ItemTypes.BUCKWHEAT_PANCAKES)
	assert_has(rules.materials(&"buckwheat_pancakes"), &"buckwheat")
