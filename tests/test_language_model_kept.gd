extends GutTest
## How many memories (and stories) a villager keeps: settings of a language model profile, next to
## the lines of the chat (test_language_model_settings.gd).

const DIR := "user://test_language_model_kept"
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


func test_the_memories_kept_default_to_20_stay_in_range_and_are_stored_only_when_changed() -> void:
	assert_eq(_settings.profiles.active["memories_kept"], 20)
	_settings.profiles.set_memories_kept(20)
	assert_false(FileAccess.get_file_as_string(PATH).contains("memories_kept"))
	_settings.profiles.set_memories_kept(35)
	assert_eq(_reloaded().profiles.active["memories_kept"], 35)
	_settings.profiles.set_memories_kept(0)
	assert_eq(_settings.profiles.active["memories_kept"], LanguageModelProfiles.MIN_MEMORIES_KEPT)
	_settings.profiles.set_memories_kept(5000)
	assert_eq(_settings.profiles.active["memories_kept"], LanguageModelProfiles.MAX_MEMORIES_KEPT)


func test_a_memories_kept_value_out_of_range_is_ignored() -> void:
	_write_file(
		(
			'[language_model]\nprofiles=[{"name": "A", "provider": "openai",'
			+ ' "memories_kept": 0}]\n'
		)
	)
	assert_eq(_reloaded().profiles.active["memories_kept"], 20)
	assert_push_warning_count(1)


func test_the_page_shows_the_memories_kept_and_stores_a_change() -> void:
	_settings.profiles.set_memories_kept(12)
	var page := LanguageModelPage.new(_settings)
	add_child_autofree(page)
	page.show_settings()
	assert_eq(page._memories_kept.value, 12.0)
	assert_eq(page._memories_label.text, "Memories a villager keeps: 12")
	page._memories_kept.value = 15
	assert_eq(_reloaded().profiles.active["memories_kept"], 15)


func test_the_stories_kept_default_to_10_stay_in_range_and_are_stored_only_when_changed() -> void:
	assert_eq(_settings.profiles.active["stories_kept"], 10)
	_settings.profiles.set_stories_kept(10)
	assert_false(FileAccess.get_file_as_string(PATH).contains("stories_kept"))
	_settings.profiles.set_stories_kept(15)
	assert_eq(_reloaded().profiles.active["stories_kept"], 15)
	_settings.profiles.set_stories_kept(0)
	assert_eq(_settings.profiles.active["stories_kept"], LanguageModelProfiles.MIN_STORIES_KEPT)
	_settings.profiles.set_stories_kept(5000)
	assert_eq(_settings.profiles.active["stories_kept"], LanguageModelProfiles.MAX_STORIES_KEPT)


func test_the_page_shows_the_stories_kept_and_stores_a_change() -> void:
	_settings.profiles.set_stories_kept(7)
	var page := LanguageModelPage.new(_settings)
	add_child_autofree(page)
	page.show_settings()
	assert_eq(page._stories_kept.value, 7.0)
	assert_eq(page._stories_label.text, "Stories a villager keeps: 7")
	page._stories_kept.value = 9
	assert_eq(_reloaded().profiles.active["stories_kept"], 9)
