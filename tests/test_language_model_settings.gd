extends GutTest
## The settings of the language model villagers talk through: none by default, what is stored in
## the settings file, and loading it; and the Settings page that edits them.

const DIR := "user://test_language_model_settings"
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


func test_by_default_there_is_no_endpoint_and_the_test_model() -> void:
	assert_eq(_settings.language_model["endpoint"], "")
	assert_eq(_settings.language_model["model"], "qwen2.5:3b-instruct")
	assert_eq(_settings.language_model["api_key"], "")


func test_the_endpoint_model_and_key_survive_a_restart() -> void:
	_settings.set_language_model("endpoint", " http://127.0.0.1:11434/v1 ")
	_settings.set_language_model("model", "llama3.2")
	_settings.set_language_model("api_key", "sk-test")
	var loaded := _reloaded()
	assert_eq(
		loaded.language_model,
		{"endpoint": "http://127.0.0.1:11434/v1", "model": "llama3.2", "api_key": "sk-test"}
	)


func test_only_what_differs_from_the_defaults_is_stored() -> void:
	_settings.set_language_model("endpoint", "http://127.0.0.1:11434/v1")
	var file := ConfigFile.new()
	file.load(PATH)
	assert_eq(
		file.get_section_keys(GameSettings.LANGUAGE_MODEL_SECTION), PackedStringArray(["endpoint"])
	)


func test_a_value_that_is_not_a_text_is_ignored() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	file.store_string('[language_model]\nendpoint=42\nmodel="phi3"\n')
	file.close()
	var loaded := _reloaded()
	assert_eq(loaded.language_model["endpoint"], "")
	assert_eq(loaded.language_model["model"], "phi3")


func test_the_page_shows_the_settings_and_stores_what_is_typed() -> void:
	_settings.set_language_model("model", "phi3")
	var page := LanguageModelPage.new(_settings)
	add_child_autofree(page)
	page.show_settings()
	var fields := page._fields
	assert_eq(fields["model"].text, "phi3")
	assert_true(fields["api_key"].secret, "the key is not shown")
	fields["endpoint"].text_changed.emit("http://localhost:1234/v1")
	assert_eq(_reloaded().language_model["endpoint"], "http://localhost:1234/v1")
