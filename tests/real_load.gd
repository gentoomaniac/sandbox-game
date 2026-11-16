class_name RealLoad
extends RefCounted
## A game saved and loaded the way the player's is: written as a current save and read back by
## SaveFile.load_game, so that a save the loader refuses fails the test that made it. Tests of
## what a feature saves use this; only a test of the codec itself calls from_dict directly.

const SAVE_DIR := "user://test_real_load"
const SAVE_PATH := SAVE_DIR + "/world.json"


## The game as the loader gives it back. Fails `test` with the problems if it is not READY.
static func of(test: GutTest, state: GameState) -> GameState:
	var error := SaveFile.write_text(SaveFile.encode(state), SAVE_PATH)
	test.assert_eq(error, "", "the save is written")
	var result := SaveFile.load_game(SAVE_PATH)
	DirAccess.remove_absolute(SAVE_PATH)
	test.assert_eq(result.outcome, LoadResult.Outcome.READY, str(result.problems))
	return result.state
