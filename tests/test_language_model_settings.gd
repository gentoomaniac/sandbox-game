extends GutTest
## The settings of the language model villagers talk through: the profiles (a provider with its
## settings), what is stored in the settings file, and loading it, also from before there were
## profiles; and the Settings page that edits them.

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


func _write_file(text: String) -> void:
	DirAccess.make_dir_recursive_absolute(DIR)
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	file.store_string(text)
	file.close()


func test_by_default_there_is_a_profile_for_each_provider_and_the_test_llm_is_in_use() -> void:
	assert_eq(_settings.profiles.names(), ["OpenAI-compatible", "Claude", "Gemini"])
	assert_eq(_settings.profiles.active["name"], "OpenAI-compatible")
	assert_eq(_settings.profiles.active["provider"], "openai")
	assert_eq(_settings.profiles.active["endpoint"], "http://127.0.0.1:11434/v1")
	assert_eq(_settings.profiles.active["model"], "qwen2.5:7b-instruct")
	assert_eq(_settings.profiles.active["chat_history_lines"], 24)
	assert_eq(_settings.profiles.language_model()["api_key"], "")


func test_the_endpoint_model_and_key_survive_a_restart() -> void:
	_settings.profiles.set_value("endpoint", " http://127.0.0.1:11434/v1 ")
	_settings.profiles.set_value("model", "llama3.2")
	_settings.profiles.set_value("api_key", "sk-test")
	assert_eq(
		_reloaded().profiles.language_model(),
		{
			"name": "OpenAI-compatible",
			"provider": "openai",
			"endpoint": "http://127.0.0.1:11434/v1",
			"model": "llama3.2",
			"api_key": "sk-test",
			"max_tokens": "",
			"temperature": "",
			"chat_history_lines": 24,
			"memories_kept": 20,
		}
	)


func test_claude_starts_with_its_endpoint_and_model_and_survives_a_restart() -> void:
	_settings.profiles.select("Claude")
	var loaded := _reloaded()
	assert_eq(loaded.profiles.active["name"], "Claude")
	assert_eq(loaded.profiles.active["provider"], "claude")
	assert_eq(loaded.profiles.active["endpoint"], "https://api.anthropic.com/v1")
	assert_eq(loaded.profiles.active["model"], "claude-opus-5-5")
	loaded.profiles.select("OpenAI-compatible")
	assert_eq(loaded.profiles.active["endpoint"], GameSettings.DEFAULT_LANGUAGE_MODEL["endpoint"])


func test_each_profile_keeps_its_own_endpoint_model_and_the_key_is_the_providers() -> void:
	_settings.profiles.set_value("api_key", "sk-openai")
	_settings.profiles.set_value("endpoint", "http://localhost:1234/v1")
	_settings.profiles.select("Claude")
	assert_eq(
		_settings.profiles.language_model()["api_key"], "", "the key stays with the other provider"
	)
	assert_eq(_settings.profiles.active["endpoint"], "https://api.anthropic.com/v1")
	_settings.profiles.set_value("api_key", "sk-ant-test")
	_settings.profiles.set_value("model", "claude-haiku-5-5")
	for settings in [_settings, _reloaded()]:
		settings.profiles.select("OpenAI-compatible")
		assert_eq(settings.profiles.language_model()["api_key"], "sk-openai")
		assert_eq(settings.profiles.active["endpoint"], "http://localhost:1234/v1")
		settings.profiles.select("Claude")
		assert_eq(settings.profiles.language_model()["api_key"], "sk-ant-test")
		assert_eq(settings.profiles.active["model"], "claude-haiku-5-5")


func test_the_keys_are_stored_in_the_sections_of_their_providers_and_never_in_a_profile() -> void:
	_settings.profiles.set_value("api_key", "sk-openai")
	_settings.profiles.select("Gemini")
	assert_eq(
		_settings.profiles.language_model()["api_key"], "", "the key stays with the other provider"
	)
	assert_eq(_settings.profiles.active["model"], "gemini-2.5-flash-lite")
	_settings.profiles.set_value("api_key", "AIza-test")
	_settings.profiles.set_value("model", "gemini-2.5-pro")
	var file := ConfigFile.new()
	file.load(PATH)
	assert_eq(file.get_value("language_model", "api_key"), "sk-openai")
	assert_eq(file.get_value("language_model.gemini", "api_key"), "AIza-test")
	for stored: Dictionary in file.get_value("language_model", "profiles"):
		assert_false(stored.has("api_key"))
	var loaded := _reloaded()
	assert_eq(loaded.profiles.active["name"], "Gemini")
	assert_eq(loaded.profiles.language_model()["api_key"], "AIza-test")
	loaded.profiles.select("OpenAI-compatible")
	assert_eq(loaded.profiles.language_model()["api_key"], "sk-openai")


func test_profiles_of_one_provider_share_its_key_and_send_it_to_nobody_else() -> void:
	_settings.profiles.select("Gemini")
	_settings.profiles.set_value("api_key", "AIza-test")
	_settings.profiles.copy()
	_settings.profiles.set_value("model", "gemini-2.5-pro")
	assert_eq(_settings.profiles.language_model()["api_key"], "AIza-test")
	_settings.profiles.select("Claude")
	assert_eq(_settings.profiles.language_model()["api_key"], "")
	_settings.profiles.select("OpenAI-compatible")
	assert_eq(_settings.profiles.language_model()["api_key"], "")


func test_the_max_tokens_are_each_profiles_own_and_stored_only_when_set() -> void:
	assert_eq(_settings.profiles.active["max_tokens"], "", "the game's own number")
	_settings.profiles.select("Gemini")
	_settings.profiles.set_value("max_tokens", " 500 ")
	var loaded := _reloaded()
	assert_eq(loaded.profiles.active["max_tokens"], "500")
	loaded.profiles.select("OpenAI-compatible")
	assert_eq(loaded.profiles.active["max_tokens"], "")


func test_the_temperature_is_each_profiles_own_and_stored_only_when_set() -> void:
	assert_eq(_settings.profiles.active["temperature"], "", "the game's own")
	_settings.profiles.select("Gemini")
	_settings.profiles.set_value("temperature", " 0.9 ")
	var loaded := _reloaded()
	assert_eq(loaded.profiles.active["temperature"], "0.9")
	loaded.profiles.select("OpenAI-compatible")
	assert_eq(loaded.profiles.active["temperature"], "")


func test_only_what_differs_from_the_defaults_is_stored() -> void:
	assert_false(FileAccess.file_exists(PATH))
	_settings.profiles.set_chat_history_lines(24)
	assert_false(FileAccess.get_file_as_string(PATH).contains("language_model"), "all default")
	_settings.profiles.set_value("endpoint", "http://127.0.0.1:1234/v1")
	var file := ConfigFile.new()
	file.load(PATH)
	assert_eq(file.get_section_keys(LanguageModelProfiles.SECTION), PackedStringArray(["profiles"]))
	assert_false(file.has_section("language_model.claude"))
	_settings.profiles.select("Claude")
	_settings.profiles.set_value("api_key", "sk-ant-test")
	file.load(PATH)
	assert_eq(file.get_value("language_model", "active"), "Claude")
	assert_eq(file.get_section_keys("language_model.claude"), PackedStringArray(["api_key"]))


func test_a_value_that_is_not_a_text_is_ignored() -> void:
	_write_file(
		(
			'[language_model]\nprofiles=[{"name": "Mine", "provider": "openai", "endpoint": 42,'
			+ ' "model": "phi3"}]\n'
		)
	)
	var loaded := _reloaded()
	assert_eq(loaded.profiles.active["endpoint"], GameSettings.DEFAULT_LANGUAGE_MODEL["endpoint"])
	assert_eq(loaded.profiles.active["model"], "phi3")
	assert_push_warning_count(1)


func test_an_emptied_endpoint_stays_empty_after_a_restart_so_villagers_need_no_model() -> void:
	_settings.profiles.set_value("endpoint", "")
	assert_eq(_reloaded().profiles.active["endpoint"], "")


# --- Lines a villager keeps ---


func test_the_chat_history_lines_default_to_24_and_are_stored_only_when_changed() -> void:
	assert_eq(_settings.profiles.active["chat_history_lines"], 24)
	_settings.profiles.set_chat_history_lines(24)
	assert_false(FileAccess.get_file_as_string(PATH).contains("chat_history_lines"))
	_settings.profiles.set_chat_history_lines(40)
	assert_eq(_reloaded().profiles.active["chat_history_lines"], 40)


func test_the_chat_history_lines_stay_in_range_and_are_each_profiles_own() -> void:
	_settings.profiles.set_chat_history_lines(0)
	assert_eq(
		_settings.profiles.active["chat_history_lines"],
		LanguageModelProfiles.MIN_CHAT_HISTORY_LINES
	)
	_settings.profiles.set_chat_history_lines(5000)
	assert_eq(
		_settings.profiles.active["chat_history_lines"],
		LanguageModelProfiles.MAX_CHAT_HISTORY_LINES
	)
	_settings.profiles.set_chat_history_lines(30)
	_settings.profiles.select("Claude")
	assert_eq(_settings.profiles.active["chat_history_lines"], 24)


func test_a_chat_history_lines_value_out_of_range_is_ignored() -> void:
	_write_file(
		(
			'[language_model]\nprofiles=[{"name": "A", "provider": "openai",'
			+ ' "chat_history_lines": 1}]\n'
		)
	)
	assert_eq(_reloaded().profiles.active["chat_history_lines"], 24)
	assert_push_warning_count(1)


func test_an_old_chat_history_lines_value_out_of_range_is_ignored() -> void:
	_write_file("[language_model]\nchat_history_lines=1\n")
	assert_eq(_reloaded().profiles.active["chat_history_lines"], 24)
	assert_push_warning_count(1)


# --- The page ---


func test_the_page_shows_the_settings_and_stores_what_is_typed() -> void:
	_settings.profiles.set_value("model", "phi3")
	var page := LanguageModelPage.new(_settings)
	add_child_autofree(page)
	page.show_settings()
	var fields := page._fields
	assert_eq(fields["model"].text, "phi3")
	assert_true(fields["api_key"].secret, "the key is not shown")
	assert_eq(page._profiles.selected, 0)
	fields["api_key"].text_changed.emit("sk-openai")
	page._profiles.item_selected.emit(1)
	assert_eq(_reloaded().profiles.active["name"], "Claude")
	assert_eq(fields["endpoint"].text, "https://api.anthropic.com/v1", "the fields follow")
	assert_eq(fields["api_key"].text, "", "the key of the other provider is not shown")
	assert_eq(fields["model"].placeholder_text, "claude-opus-5-5")
	page._profiles.item_selected.emit(0)
	assert_eq(fields["api_key"].text, "sk-openai")
	fields["endpoint"].text_changed.emit("http://localhost:1234/v1")
	assert_eq(_reloaded().profiles.active["endpoint"], "http://localhost:1234/v1")


func test_the_page_shows_the_chat_history_lines_and_stores_a_change() -> void:
	_settings.profiles.set_chat_history_lines(10)
	var page := LanguageModelPage.new(_settings)
	add_child_autofree(page)
	page.show_settings()
	assert_eq(page._history_lines.value, 10.0)
	assert_eq(page._history_label.text, "Lines a villager keeps: 10")
	page._history_lines.value = 12
	assert_eq(_reloaded().profiles.active["chat_history_lines"], 12)
