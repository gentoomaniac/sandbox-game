class_name SaveValidationCase
extends SaveUpgradeCase
## What the tests of the save validator share: a damaged or incomplete save to write, and what
## reading it comes to.


func _slots(game: Dictionary) -> Array:
	return game["player"]["inventory"]["slots"]


func _kiln_object(work: Variant) -> Dictionary:
	return {
		"type": "kiln",
		"pos": [3, 4],
		"state": {} if work == null else {"work": work},
	}


func _with_object_edit(game: Dictionary, object: Dictionary) -> void:
	game["world"]["object_edits"].append({"pos": object["pos"], "object": object})


func _refusal_of(game: Dictionary) -> LoadResult:
	_write_save(SaveFile.VERSION, game)
	var result := SaveFile.load_game(SAVE_PATH)
	assert_eq(result.outcome, LoadResult.Outcome.REFUSED, "refused")
	assert_null(result.state)
	assert_true(FileAccess.file_exists(SAVE_PATH), "the file is left as it is")
	assert_eq(SaveFile.backups_of(SAVE_PATH).size(), 0)
	return result


func _question_about(game: Dictionary) -> LoadResult:
	_write_save(SaveFile.VERSION, game)
	var result := SaveFile.load_game(SAVE_PATH)
	assert_eq(result.outcome, LoadResult.Outcome.ASK, "asked")
	assert_null(result.state, "nothing is built before the player agrees")
	assert_true(FileAccess.file_exists(SAVE_PATH), "the file is left as it is")
	assert_eq(SaveFile.backups_of(SAVE_PATH).size(), 0)
	return result
