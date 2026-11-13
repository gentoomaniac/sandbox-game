extends CropCase
## What the crows have eaten off a crop: the yield it still gives.

const SEED := 11


func _harvest(crop: WorldObject) -> int:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	return CropLife.harvest_of(crop, rng)[crop.type_data()["produce"]]


func test_a_crop_nothing_ate_gives_its_usual_yield_and_has_yield_to_eat() -> void:
	var crop := _crop(&"wheat")
	assert_eq(CropLife.eaten(crop), 0)
	assert_true(CropLife.has_yield_to_eat(crop))


func test_what_the_crows_ate_is_off_the_harvest_and_one_item_stays() -> void:
	var crop := _crop(&"wheat")
	var uneaten := _harvest(crop)
	CropLife.eat(crop, 1)
	assert_eq(_harvest(crop), uneaten - 1)
	CropLife.eat(crop, 10)
	assert_eq(_harvest(crop), 1)


func test_a_crop_with_one_item_left_to_give_has_no_yield_to_eat() -> void:
	var crop := _crop(&"wheat")
	CropLife.eat(crop, int(crop.type_data()["yield"]) - 1)
	assert_false(CropLife.has_yield_to_eat(crop))
	assert_false(CropLife.has_yield_to_eat(_crop(&"cabbage")), "a yield of 1")


func test_what_was_eaten_survives_the_save() -> void:
	var crop := _crop(&"wheat")
	CropLife.eat(crop, 1)
	var loaded := WorldObject.from_dict(crop.to_dict())
	assert_eq(CropLife.eaten(loaded), 1)


func test_a_regrown_crop_has_new_fruit() -> void:
	var crop := _crop(&"peas")
	CropLife.eat(crop, 1)
	CropLife.regrow(crop)
	assert_eq(CropLife.eaten(crop), 0)


func test_the_console_says_what_was_eaten() -> void:
	var crop := _crop(&"wheat")
	CropLife.eat(crop, 2)
	assert_string_contains(CropLife.describe(crop)[0], "2 eaten by crows")


func test_what_was_eaten_survives_a_whole_game_saved_checked_and_loaded() -> void:
	var state := GameState.new_game(SEED)
	var pos := state.player.tile() + Vector2i(3, 0)
	state.world.set_terrain(pos, Tile.Terrain.SOIL)
	var crop := WorldObject.new(&"wheat", pos)
	CropLife.eat(crop, 1)
	state.world.add_object(crop)
	var game: Dictionary = JSON.parse_string(JSON.stringify(state.to_dict()))
	var validator := SaveValidator.check(game)
	assert_eq(validator.problems, [] as Array[String])
	var loaded := GameState.from_dict(game)
	# A loaded world's chunks are not generated yet: the crop is among the edits.
	var crops := loaded.world.crops()
	assert_eq(crops.size(), 1)
	assert_eq(CropLife.eaten(crops[0]), 1)
