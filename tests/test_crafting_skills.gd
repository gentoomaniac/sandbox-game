extends GutTest
## Recipes made at a station and with a skill: the keys and their checks, the lock below a
## recipe's level and the practice each craft gives.

const RECIPES := {
	"stew":
	{
		"result": "turnip",
		"count": 1,
		"materials": {"berries": 2},
		"station": "hearth",
		"skill": "cooking",
	},
	"feast":
	{
		"result": "turnip",
		"count": 1,
		"materials": {"berries": 2},
		"station": "hearth",
		"skill": "cooking",
		"level": 25,
	},
	"box": {"result": "chest", "count": 1, "materials": {"logs": 1}},
}

var _state: GameState
var _crafting: Crafting


func before_each() -> void:
	_state = GameState.new_game(7)
	_crafting = Crafting.new(_state, RecipeRules.new(RECIPES))
	_state.player.inventory.add(ItemTypes.BERRIES, 10)


func _problems_of(recipe: Dictionary) -> Array[String]:
	var base := {"result": "chest", "count": 1, "materials": {"logs": 1}}
	return RecipeRules.new({"thing": base.merged(recipe)}).problems()


# --- The keys ---


func test_a_recipe_names_its_station_skill_and_level() -> void:
	var rules := RecipeRules.new(RECIPES)
	assert_true(rules.is_valid(), str(rules.problems()))
	assert_eq(rules.station_of(&"stew"), &"hearth")
	assert_eq(rules.skill(&"stew"), &"cooking")
	assert_eq(rules.level(&"stew"), 0.0)
	assert_eq(rules.level(&"feast"), 25.0)
	assert_eq(rules.station_of(&"box"), &"", "made by hand")
	assert_eq(rules.skill(&"box"), &"")


func test_the_recipes_of_a_station_are_in_the_order_of_the_file() -> void:
	var rules := RecipeRules.new(RECIPES)
	assert_eq(rules.recipes_at(&"hearth"), [&"stew", &"feast"] as Array[StringName])
	assert_eq(rules.recipes_at(&""), [&"box"] as Array[StringName])


func test_bad_stations_skills_and_levels_are_reported() -> void:
	assert_eq(
		_problems_of({"station": "forge"}),
		["[thing] station is not a station: forge"] as Array[String]
	)
	assert_eq(
		_problems_of({"skill": "smithing"}),
		["[thing] skill is not a skill: smithing"] as Array[String]
	)
	assert_eq(_problems_of({"level": 5}), ["[thing] a level needs a skill"] as Array[String])
	assert_eq(_problems_of({"skill": "cooking", "level": "high"}).size(), 1, "not a number")
	assert_eq(_problems_of({"skill": "cooking", "level": 101}).size(), 1, "above the cap")
	assert_eq(_problems_of({"skill": "cooking", "level": -1}).size(), 1, "below 0")
	var good := {"station": "hearth", "skill": "cooking", "level": 30.5}
	assert_eq(_problems_of(good), [] as Array[String])


# --- Crafting ---


func test_a_recipe_below_its_level_is_locked_and_refused() -> void:
	assert_true(_crafting.is_locked(&"feast"))
	assert_eq(_crafting.craft(&"feast"), Crafting.Result.LOCKED)
	assert_eq(_state.player.inventory.count_of(ItemTypes.BERRIES), 10)
	_state.player.skills.set_points(&"cooking", 25.0)
	assert_false(_crafting.is_locked(&"feast"))
	assert_eq(_crafting.craft(&"feast"), Crafting.Result.CRAFTED)


func test_a_recipe_without_a_skill_is_never_locked() -> void:
	assert_false(_crafting.is_locked(&"box"))


func test_a_craft_practises_its_skill_and_says_so() -> void:
	watch_signals(_crafting)
	assert_eq(_crafting.craft(&"stew"), Crafting.Result.CRAFTED)
	assert_eq(_state.player.skills.points(&"cooking"), 2.0)
	assert_signal_emitted_with_parameters(_crafting, "practised", [&"cooking", 2.0, 2.0])


func test_a_craft_at_the_total_cap_says_what_it_would_have_taught() -> void:
	var skills := _state.player.skills
	skills.set_points(&"woodworking", 100.0)
	skills.set_points(&"masonry", 100.0)
	watch_signals(_crafting)
	_crafting.craft(&"stew")
	assert_eq(skills.points(&"cooking"), 0.0)
	assert_signal_emitted_with_parameters(_crafting, "practised", [&"cooking", 0.0, 2.0])


func test_a_craft_without_a_skill_practises_nothing() -> void:
	_state.player.inventory.add(ItemTypes.LOGS, 1)
	watch_signals(_crafting)
	assert_eq(_crafting.craft(&"box"), Crafting.Result.CRAFTED)
	assert_signal_not_emitted(_crafting, "practised")


func test_a_refused_craft_practises_nothing() -> void:
	_state.player.inventory.remove(ItemTypes.BERRIES, 10)
	assert_eq(_crafting.craft(&"stew"), Crafting.Result.MISSING_MATERIALS)
	assert_eq(_state.player.skills.points(&"cooking"), 0.0)


# --- The real recipes ---


func test_every_skill_has_a_recipe_that_teaches_it_up_to_its_cap() -> void:
	var rules := RecipeRules.default_rules()
	var skill_rules := SkillRules.default_rules()
	for skill in skill_rules.skill_ids():
		var top := -1.0
		for recipe_id in rules.recipe_ids():
			if rules.skill(recipe_id) == skill:
				top = maxf(top, rules.level(recipe_id))
		assert_gte(top + skill_rules.trivial_above() - 1.0, skill_rules.skill_cap(), str(skill))
		var skills := Skills.new(skill_rules)
		skills.set_points(skill, top)
		for craft in 1000:
			if skills.practise(skill, top) == 0.0:
				break
		assert_eq(skills.points(skill), skill_rules.skill_cap(), "%s reaches the top" % skill)
