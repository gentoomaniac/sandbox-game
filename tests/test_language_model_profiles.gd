extends GutTest
## The profiles of the language model villagers talk through: adding, copying, renaming, deleting
## and choosing them, and what is made of those of a settings file.

const DIR := "user://test_language_model_profiles"
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


func test_a_profile_is_added_with_its_providers_defaults_and_a_name_of_its_own() -> void:
	_settings.profiles.add("claude")
	assert_eq(_settings.profiles.active["name"], "Claude 2", "the name was taken")
	assert_eq(_settings.profiles.active["provider"], "claude")
	assert_eq(_settings.profiles.active["model"], "claude-opus-5-5")
	_settings.profiles.add("claude")
	assert_eq(_settings.profiles.active["name"], "Claude 3")
	assert_eq(_settings.profiles.names().size(), 5)
	assert_eq(_reloaded().profiles.names(), _settings.profiles.names())


func test_a_copy_has_the_settings_of_the_profile_it_is_made_of() -> void:
	_settings.profiles.select("Gemini")
	_settings.profiles.set_value("model", "gemini-2.5-pro")
	_settings.profiles.set_value("temperature", "0.9")
	_settings.profiles.set_chat_history_lines(40)
	_settings.profiles.copy()
	assert_eq(_settings.profiles.active["name"], "Gemini copy")
	assert_eq(_settings.profiles.active["model"], "gemini-2.5-pro")
	assert_eq(_settings.profiles.active["temperature"], "0.9")
	assert_eq(_settings.profiles.active["chat_history_lines"], 40)
	_settings.profiles.set_value("model", "gemini-2.5-flash")
	_settings.profiles.select("Gemini")
	assert_eq(_settings.profiles.active["model"], "gemini-2.5-pro", "the first is not changed")
	_settings.profiles.select("Gemini copy")
	_settings.profiles.copy()
	assert_eq(_settings.profiles.active["name"], "Gemini copy copy")


func test_a_profile_is_renamed_unless_the_name_is_empty_or_another_profiles() -> void:
	assert_true(_settings.profiles.rename("  Test LLM "))
	assert_eq(_settings.profiles.names(), ["Test LLM", "Claude", "Gemini"])
	assert_false(_settings.profiles.rename("Claude"))
	assert_false(_settings.profiles.rename("   "))
	assert_true(_settings.profiles.rename("Test LLM"), "its own name is no clash")
	assert_eq(_settings.profiles.active["name"], "Test LLM")
	var loaded := _reloaded()
	assert_eq(loaded.profiles.active["name"], "Test LLM")
	assert_eq(loaded.profiles.names(), ["Test LLM", "Claude", "Gemini"])


func test_a_profile_is_deleted_but_never_the_last_one() -> void:
	_settings.profiles.select("Claude")
	assert_true(_settings.profiles.delete())
	assert_eq(_settings.profiles.active["name"], "OpenAI-compatible", "the one before it is in use")
	assert_true(_settings.profiles.delete())
	assert_eq(_settings.profiles.active["name"], "Gemini", "no one before the first")
	assert_false(_settings.profiles.delete(), "the last stays")
	assert_eq(_settings.profiles.names(), ["Gemini"])
	var loaded := _reloaded()
	assert_eq(loaded.profiles.names(), ["Gemini"])
	assert_eq(loaded.profiles.active["name"], "Gemini")


func test_a_profile_can_change_its_provider_and_keeps_the_rest() -> void:
	_settings.profiles.set_value("temperature", "1")
	_settings.profiles.set_provider("claude")
	assert_eq(_settings.profiles.active["name"], "OpenAI-compatible")
	assert_eq(_settings.profiles.active["provider"], "claude")
	assert_eq(_settings.profiles.active["endpoint"], "https://api.anthropic.com/v1")
	assert_eq(_settings.profiles.active["model"], "claude-opus-5-5")
	assert_eq(_settings.profiles.active["temperature"], "1")
	assert_eq(_reloaded().profiles.active["provider"], "claude")


func test_an_unknown_profile_is_not_selected() -> void:
	_settings.profiles.select("Nobody")
	assert_eq(_settings.profiles.active["name"], "OpenAI-compatible")


func test_an_unknown_or_unnamed_profile_in_the_file_is_ignored() -> void:
	_write_file(
		(
			'[language_model]\nprofiles=[{"name": "A", "provider": "gpt"}, {"provider": "claude"},'
			+ ' {"name": "A", "provider": "claude"}, {"name": "A", "provider": "openai"}, 7]\n'
			+ 'active="B"\n'
		)
	)
	var loaded := _reloaded()
	assert_eq(loaded.profiles.names(), ["A"])
	assert_eq(loaded.profiles.active["provider"], "claude")
	assert_push_warning_count(5, "the four profiles and the one in use")


func test_a_file_without_a_usable_profile_has_the_default_ones() -> void:
	_write_file('[language_model]\nprofiles=[{"name": "A", "provider": "gpt"}]\n')
	assert_eq(_reloaded().profiles.names(), ["OpenAI-compatible", "Claude", "Gemini"])
	assert_push_warning_count(1)


# --- Files from before the profiles ---


func test_a_file_from_before_the_profiles_becomes_a_profile_for_each_provider() -> void:
	_write_file(
		(
			'[language_model]\nprovider="gemini"\nendpoint="http://localhost:1234/v1"\n'
			+ 'api_key="sk-old"\nmax_tokens="300"\nchat_history_lines=40\n'
			+ '[language_model.claude]\nmodel="claude-haiku-5-5"\napi_key="sk-ant-old"\n'
			+ '[language_model.gemini]\nmodel="gemini-2.5-pro"\ntemperature="0.8"\n'
		)
	)
	var loaded := _reloaded()
	assert_eq(loaded.profiles.names(), ["OpenAI-compatible", "Claude", "Gemini"])
	assert_eq(loaded.profiles.active["name"], "Gemini", "the provider in use is the profile in use")
	assert_eq(loaded.profiles.active["model"], "gemini-2.5-pro")
	assert_eq(loaded.profiles.active["temperature"], "0.8")
	assert_eq(loaded.profiles.active["chat_history_lines"], 40, "the one number went into each")
	assert_eq(loaded.profiles.language_model()["api_key"], "", "Gemini had none")
	loaded.profiles.select("OpenAI-compatible")
	assert_eq(loaded.profiles.active["endpoint"], "http://localhost:1234/v1")
	assert_eq(loaded.profiles.active["max_tokens"], "300")
	assert_eq(loaded.profiles.active["chat_history_lines"], 40)
	assert_eq(loaded.profiles.language_model()["api_key"], "sk-old")
	loaded.profiles.select("Claude")
	assert_eq(loaded.profiles.active["model"], "claude-haiku-5-5")
	assert_eq(loaded.profiles.active["endpoint"], "https://api.anthropic.com/v1")
	assert_eq(loaded.profiles.active["chat_history_lines"], 40)
	assert_eq(loaded.profiles.language_model()["api_key"], "sk-ant-old")


func test_an_upgraded_file_is_written_in_the_new_shape_and_loads_the_same() -> void:
	_write_file('[language_model]\nprovider="claude"\nchat_history_lines=10\n')
	var upgraded := _reloaded()
	upgraded.profiles.set_value("model", "claude-haiku-5-5")
	var file := ConfigFile.new()
	file.load(PATH)
	assert_false(file.has_section_key("language_model", "provider"))
	assert_false(file.has_section_key("language_model", "chat_history_lines"))
	var loaded := _reloaded()
	assert_eq(loaded.profiles.active["name"], "Claude")
	assert_eq(loaded.profiles.active["model"], "claude-haiku-5-5")
	assert_eq(loaded.profiles.active["chat_history_lines"], 10)


func test_a_file_from_before_the_providers_is_the_openai_providers() -> void:
	_write_file('[language_model]\nendpoint="http://localhost:1234/v1"\napi_key="sk-old"\n')
	var loaded := _reloaded()
	assert_eq(loaded.profiles.active["provider"], "openai")
	assert_eq(loaded.profiles.language_model()["api_key"], "sk-old")
	loaded.profiles.select("Claude")
	assert_eq(loaded.profiles.language_model()["api_key"], "")


func test_an_unknown_provider_in_an_old_file_is_ignored() -> void:
	_write_file('[language_model]\nprovider="gpt"\n')
	assert_eq(_reloaded().profiles.active["provider"], "openai")
	assert_push_warning_count(1)
