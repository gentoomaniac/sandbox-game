extends GutTest
## The switches of a language model profile for what the model is asked besides chats: random
## speech, day plans and quest lines (`LanguageModelProfiles.uses_model_for`), and what is stored.

const DIR := "user://test_language_model_uses"
const PATH := DIR + "/settings.cfg"

var _settings: GameSettings


func before_each() -> void:
	_settings = GameSettings.new(PATH)


func after_each() -> void:
	if not DirAccess.dir_exists_absolute(DIR):
		return
	for file_name in DirAccess.get_files_at(DIR):
		DirAccess.remove_absolute(DIR.path_join(file_name))


func _reloaded() -> GameSettings:
	var settings := GameSettings.new(PATH)
	settings.load_file()
	return settings


func _write_file(text: String) -> void:
	DirAccess.make_dir_recursive_absolute(DIR)
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	file.store_string(text)
	file.close()


func test_every_use_of_the_model_is_on_by_default_and_stored_only_when_switched() -> void:
	for use in LanguageModelProfiles.USES:
		assert_true(_settings.profiles.uses_model_for(use), use)
	_settings.profiles.set_uses_model_for(&"day_plans", true)
	assert_false(FileAccess.get_file_as_string(PATH).contains("day_plans"))
	_settings.profiles.set_uses_model_for(&"day_plans", false)
	var reloaded := _reloaded().profiles
	assert_false(reloaded.uses_model_for(&"day_plans"))
	assert_true(reloaded.uses_model_for(&"random_speech"))
	assert_true(reloaded.uses_model_for(&"quest_lines"))


func test_the_uses_are_each_profiles_own_and_a_copy_keeps_them() -> void:
	_settings.profiles.set_uses_model_for(&"random_speech", false)
	_settings.profiles.copy()
	assert_false(_settings.profiles.uses_model_for(&"random_speech"))
	_settings.profiles.select("Claude")
	assert_true(_settings.profiles.uses_model_for(&"random_speech"))


func test_a_profile_saved_before_the_uses_loads_with_them_on() -> void:
	_write_file('[language_model]\nprofiles=[{"name": "A", "provider": "openai"}]\n')
	for use in LanguageModelProfiles.USES:
		assert_true(_reloaded().profiles.uses_model_for(use), use)
	_write_file("[language_model]\nchat_history_lines=30\n")
	for use in LanguageModelProfiles.USES:
		assert_true(_reloaded().profiles.uses_model_for(use), use)


func test_a_use_that_is_not_true_or_false_is_ignored() -> void:
	_write_file(
		'[language_model]\nprofiles=[{"name": "A", "provider": "openai", "day_plans": 0}]\n'
	)
	assert_true(_reloaded().profiles.uses_model_for(&"day_plans"))
	assert_push_warning_count(1)
