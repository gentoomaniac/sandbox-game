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


func test_by_default_the_endpoint_is_the_test_llm_with_its_model() -> void:
	assert_eq(_settings.language_model["endpoint"], "http://127.0.0.1:11434/v1")
	assert_eq(_settings.language_model["model"], "qwen2.5:7b-instruct")
	assert_eq(_settings.language_model["api_key"], "")


func test_the_endpoint_model_and_key_survive_a_restart() -> void:
	_settings.set_language_model("endpoint", " http://127.0.0.1:11434/v1 ")
	_settings.set_language_model("model", "llama3.2")
	_settings.set_language_model("api_key", "sk-test")
	var loaded := _reloaded()
	assert_eq(
		loaded.language_model,
		{
			"provider": "openai",
			"endpoint": "http://127.0.0.1:11434/v1",
			"model": "llama3.2",
			"api_key": "sk-test",
			"max_tokens": "",
			"temperature": "",
		}
	)


func test_claude_starts_with_its_endpoint_and_model_and_survives_a_restart() -> void:
	_settings.set_language_model_provider("claude")
	var loaded := _reloaded()
	assert_eq(loaded.language_model["provider"], "claude")
	assert_eq(loaded.language_model["endpoint"], "https://api.anthropic.com/v1")
	assert_eq(loaded.language_model["model"], "claude-opus-5-5")
	loaded.set_language_model_provider("openai")
	assert_eq(loaded.language_model, GameSettings.DEFAULT_LANGUAGE_MODEL)


func test_each_provider_keeps_its_own_endpoint_model_and_key() -> void:
	_settings.set_language_model("api_key", "sk-openai")
	_settings.set_language_model("endpoint", "http://localhost:1234/v1")
	_settings.set_language_model_provider("claude")
	assert_eq(_settings.language_model["api_key"], "", "the key stays with the other provider")
	assert_eq(_settings.language_model["endpoint"], "https://api.anthropic.com/v1")
	_settings.set_language_model("api_key", "sk-ant-test")
	_settings.set_language_model("model", "claude-haiku-5-5")
	for settings in [_settings, _reloaded()]:
		settings.set_language_model_provider("openai")
		assert_eq(settings.language_model["api_key"], "sk-openai")
		assert_eq(settings.language_model["endpoint"], "http://localhost:1234/v1")
		settings.set_language_model_provider("claude")
		assert_eq(settings.language_model["api_key"], "sk-ant-test")
		assert_eq(settings.language_model["model"], "claude-haiku-5-5")


func test_gemini_keeps_its_own_fields_in_its_own_section_beside_the_openai_ones() -> void:
	_settings.set_language_model("api_key", "sk-openai")
	_settings.set_language_model_provider("gemini")
	assert_eq(_settings.language_model["api_key"], "", "the key stays with the other provider")
	assert_eq(
		_settings.language_model["endpoint"],
		"https://generativelanguage.googleapis.com/v1beta/openai"
	)
	assert_eq(_settings.language_model["model"], "gemini-2.5-flash-lite")
	_settings.set_language_model("api_key", "AIza-test")
	var file := ConfigFile.new()
	file.load(PATH)
	assert_eq(file.get_section_keys("language_model.gemini"), PackedStringArray(["api_key"]))
	assert_eq(file.get_value("language_model", "api_key"), "sk-openai")
	var loaded := _reloaded()
	assert_eq(loaded.language_model["provider"], "gemini")
	assert_eq(loaded.language_model["api_key"], "AIza-test")
	loaded.set_language_model_provider("openai")
	assert_eq(loaded.language_model["api_key"], "sk-openai")


func test_the_max_tokens_are_each_providers_own_and_stored_only_when_set() -> void:
	assert_eq(_settings.language_model["max_tokens"], "", "the game's own number")
	_settings.set_language_model_provider("gemini")
	_settings.set_language_model("max_tokens", " 500 ")
	var file := ConfigFile.new()
	file.load(PATH)
	assert_eq(file.get_value("language_model.gemini", "max_tokens"), "500")
	assert_false(file.has_section_key("language_model", "max_tokens"))
	var loaded := _reloaded()
	assert_eq(loaded.language_model["max_tokens"], "500")
	loaded.set_language_model_provider("openai")
	assert_eq(loaded.language_model["max_tokens"], "")


func test_a_file_from_before_the_providers_is_the_openai_providers() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	file.store_string('[language_model]\nendpoint="http://localhost:1234/v1"\napi_key="sk-old"\n')
	file.close()
	var loaded := _reloaded()
	assert_eq(loaded.language_model["provider"], "openai")
	assert_eq(loaded.language_model["api_key"], "sk-old")
	loaded.set_language_model_provider("claude")
	assert_eq(loaded.language_model["api_key"], "")


func test_an_unknown_provider_in_the_file_is_ignored() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	file.store_string('[language_model]\nprovider="gpt"\n')
	file.close()
	assert_eq(_reloaded().language_model["provider"], "openai")
	assert_push_warning_count(1)


func test_only_what_differs_from_the_defaults_is_stored() -> void:
	_settings.set_language_model("endpoint", "http://127.0.0.1:1234/v1")
	var file := ConfigFile.new()
	file.load(PATH)
	assert_eq(
		file.get_section_keys(GameSettings.LANGUAGE_MODEL_SECTION), PackedStringArray(["endpoint"])
	)
	assert_false(file.has_section("language_model.claude"))
	_settings.set_language_model_provider("claude")
	_settings.set_language_model("api_key", "sk-ant-test")
	file.load(PATH)
	assert_eq(file.get_value("language_model", "provider"), "claude")
	assert_eq(file.get_section_keys("language_model.claude"), PackedStringArray(["api_key"]))


func test_a_value_that_is_not_a_text_is_ignored() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	file.store_string('[language_model]\nendpoint=42\nmodel="phi3"\n')
	file.close()
	var loaded := _reloaded()
	assert_eq(loaded.language_model["endpoint"], GameSettings.DEFAULT_LANGUAGE_MODEL["endpoint"])
	assert_eq(loaded.language_model["model"], "phi3")


func test_an_emptied_endpoint_stays_empty_after_a_restart_so_villagers_need_no_model() -> void:
	_settings.set_language_model("endpoint", "")
	assert_eq(_reloaded().language_model["endpoint"], "")


func test_the_page_shows_the_settings_and_stores_what_is_typed() -> void:
	_settings.set_language_model("model", "phi3")
	var page := LanguageModelPage.new(_settings)
	add_child_autofree(page)
	page.show_settings()
	var fields := page._fields
	assert_eq(fields["model"].text, "phi3")
	assert_true(fields["api_key"].secret, "the key is not shown")
	assert_eq(page._provider.selected, 0)
	fields["api_key"].text_changed.emit("sk-openai")
	page._provider.item_selected.emit(1)
	assert_eq(_reloaded().language_model["provider"], "claude")
	assert_eq(fields["endpoint"].text, "https://api.anthropic.com/v1", "the fields follow")
	assert_eq(fields["api_key"].text, "", "the key of the other provider is not shown")
	assert_eq(fields["model"].placeholder_text, "claude-opus-5-5")
	page._provider.item_selected.emit(0)
	assert_eq(fields["api_key"].text, "sk-openai")
	fields["endpoint"].text_changed.emit("http://localhost:1234/v1")
	assert_eq(_reloaded().language_model["endpoint"], "http://localhost:1234/v1")


func test_the_chat_history_lines_default_to_24_and_are_stored_only_when_changed() -> void:
	assert_eq(_settings.chat_history_lines, 24)
	_settings.set_chat_history_lines(24)
	assert_false(FileAccess.get_file_as_string(PATH).contains("chat_history_lines"))
	_settings.set_chat_history_lines(40)
	assert_eq(_reloaded().chat_history_lines, 40)


func test_the_chat_history_lines_stay_in_range_and_one_for_every_provider() -> void:
	_settings.set_chat_history_lines(0)
	assert_eq(_settings.chat_history_lines, GameSettings.MIN_CHAT_HISTORY_LINES)
	_settings.set_chat_history_lines(5000)
	assert_eq(_settings.chat_history_lines, GameSettings.MAX_CHAT_HISTORY_LINES)
	_settings.set_chat_history_lines(30)
	_settings.set_language_model_provider("claude")
	assert_eq(_settings.chat_history_lines, 30)


func test_a_chat_history_lines_value_out_of_range_is_ignored() -> void:
	var file := ConfigFile.new()
	file.set_value("language_model", "chat_history_lines", 1)
	DirAccess.make_dir_recursive_absolute(DIR)
	file.save(PATH)
	assert_eq(_reloaded().chat_history_lines, 24)
	assert_push_warning_count(1)


func test_the_page_shows_the_chat_history_lines_and_stores_a_change() -> void:
	_settings.set_chat_history_lines(10)
	var page := LanguageModelPage.new(_settings)
	add_child_autofree(page)
	page.show_settings()
	assert_eq(page._history_lines.value, 10.0)
	assert_eq(page._history_label.text, "Lines a villager keeps: 10")
	page._history_lines.value = 12
	assert_eq(_reloaded().chat_history_lines, 12)


func test_the_temperature_is_each_providers_own_and_stored_only_when_set() -> void:
	assert_eq(_settings.language_model["temperature"], "", "the game's own")
	_settings.set_language_model_provider("gemini")
	_settings.set_language_model("temperature", " 0.9 ")
	var file := ConfigFile.new()
	file.load(PATH)
	assert_eq(file.get_value("language_model.gemini", "temperature"), "0.9")
	assert_false(file.has_section_key("language_model", "temperature"))
	var loaded := _reloaded()
	assert_eq(loaded.language_model["temperature"], "0.9")
	loaded.set_language_model_provider("openai")
	assert_eq(loaded.language_model["temperature"], "")
