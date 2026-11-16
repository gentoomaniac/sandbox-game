extends GutTest
## The wear of the grass and the steps of today (see PathRules) are saved with the world and
## come back through the real loader.


func test_the_wear_and_the_steps_of_a_game_survive_the_real_load() -> void:
	var state := GameState.new_game(1)
	var tile := state.player.tile()
	state.world.set_wear_days(tile, PathRules.default_rules().path_after_days())
	state.world.wear_tile(tile + Vector2i.DOWN, 3.5)

	var restored := RealLoad.of(self, state).world

	assert_eq(restored.wear_stage(tile), PathRules.Stage.PATH)
	assert_eq(restored.wear_steps(), {tile + Vector2i.DOWN: 3.5})
