class_name SaveUpgradeCase
extends GutTest
## What the tests of old saves share: writing a save of any version, and the parts to build one.

const SAVE_DIR := "user://test_save_upgrade"
const SAVE_PATH := SAVE_DIR + "/world.json"


func after_each() -> void:
	for file_name in DirAccess.get_files_at(SAVE_DIR):
		DirAccess.remove_absolute(SAVE_DIR.path_join(file_name))


func _write_save(version: int, game: Dictionary) -> void:
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify({"version": version, "game": game}))
	file.close()


## A save as parsed JSON with the slots of version 10: its hotbar had two slots more.
func _in_version_10_layout(game: Dictionary) -> Dictionary:
	var slots: Array = game["player"]["inventory"]["slots"]
	slots.insert(Inventory.HOTBAR_SIZE, null)
	slots.insert(Inventory.HOTBAR_SIZE, null)
	return game


## A current save as parsed JSON, to take fields from.
func _current_game() -> Dictionary:
	return JSON.parse_string(JSON.stringify(GameState.new_game(7).to_dict()))
