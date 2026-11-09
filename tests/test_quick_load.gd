extends GutTest
## The handoff of F8 (QuickLoad) and what the restarted scene keeps of the command line.

const DIR := "user://test_quick_load"
const PATH := DIR + "/world.json"


func after_each() -> void:
	QuickLoad.take()
	for file_name in DirAccess.get_files_at(DIR):
		DirAccess.remove_absolute(DIR.path_join(file_name))


func test_without_a_save_file_there_is_no_save_to_load() -> void:
	assert_eq(QuickLoad.prepare(PATH), QuickLoad.Outcome.NO_SAVE)
	assert_null(QuickLoad.take())


func test_a_save_that_cannot_be_read_leaves_nothing_waiting_and_is_moved_aside() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	file.store_string("not a save")
	file.close()
	assert_eq(QuickLoad.prepare(PATH), QuickLoad.Outcome.UNREADABLE)
	assert_null(QuickLoad.take())
	assert_push_error_count(1)


func test_the_saved_game_is_kept_for_the_new_scene_and_given_once() -> void:
	var state := GameState.new_game(7)
	state.player.position = Vector2(12.5, 9.5)
	assert_true(SaveFile.write(state, PATH))
	assert_eq(QuickLoad.prepare(PATH), QuickLoad.Outcome.READY)
	assert_eq(QuickLoad.take().player.position, Vector2(12.5, 9.5))
	assert_null(QuickLoad.take())


func test_a_failed_prepare_drops_a_game_kept_before() -> void:
	SaveFile.write(GameState.new_game(7), PATH)
	QuickLoad.prepare(PATH)
	DirAccess.remove_absolute(PATH)
	QuickLoad.prepare(PATH)
	assert_null(QuickLoad.take())


func test_the_restarted_scene_keeps_the_view_flags_and_drops_the_rest() -> void:
	var options := (
		StartupOptions
		. new(
			PackedStringArray(
				[
					"--new-game",
					"--save-path=a.json",
					"--settings-path=b.cfg",
					"--mute",
					"--coordinates",
					"--zoom=2",
					"--at=3,4",
					"--day=5",
					"--time=6:30",
					"--energy=10",
					"--weather=rain",
					"--inventory",
					"--field=1,1",
				]
			)
		)
	)
	var kept := options.kept_for_quick_load()
	assert_eq(kept.save_path, "a.json")
	assert_eq(kept.settings_path, "b.cfg")
	assert_true(kept.mute)
	assert_true(kept.coordinates)
	assert_eq(kept.zoom, options.zoom)
	assert_false(kept.new_game)
	assert_eq(kept.at, StartupOptions.NO_TILE)
	assert_eq(kept.day, 0)
	assert_eq(kept.time_hour, -1)
	assert_eq(kept.energy, -1.0)
	assert_eq(kept.weather, &"")
	assert_false(kept.inventory)
	assert_eq(kept.field, StartupOptions.NO_TILE)
