extends CannedHttpTest
## The model drop-down of the Settings page of the language model: filled from the list of the
## endpoint (a small server here answers it), and the saved model and a note when there is none.

const LIST := '{"data": [{"id": "qwen2.5:3b-instruct"}, {"id": "qwen2.5:7b-instruct"}]}'
const SETTINGS_PATH := "user://test_language_model_page/settings.cfg"

var _settings: GameSettings
var _page: LanguageModelPage


func before_each() -> void:
	super()
	_settings = GameSettings.new(SETTINGS_PATH)
	_settings.profiles.active["endpoint"] = "http://127.0.0.1:%d/v1" % _port
	_page = LanguageModelPage.new(_settings)
	_page._models_timeout = PATIENCE_SECONDS
	add_child_autofree(_page)


func after_each() -> void:
	super()
	DirAccess.remove_absolute(SETTINGS_PATH)


## The names in the drop-down once the page has asked for the models and `response` came.
func _listed_after(response: String) -> Array:
	var ask := func() -> Array:
		await _page.show_models()
		return _names()
	return (await _ask_and_answer(ask, response))[1]


func _names() -> Array:
	var names := []
	for index in _page._models.item_count:
		names.append(_page._models.get_item_text(index))
	return names


func test_the_models_of_the_endpoint_are_listed_with_the_saved_one_selected() -> void:
	_settings.profiles.active["model"] = "qwen2.5:7b-instruct"
	assert_eq(
		await _listed_after(_response("200 OK", LIST)),
		["qwen2.5:3b-instruct", "qwen2.5:7b-instruct"]
	)
	assert_eq(_page._models.selected, 1)
	assert_eq(_page._models_note.text, "")


func test_a_saved_model_the_list_lacks_is_still_shown() -> void:
	_settings.profiles.active["model"] = "phi3"
	var names := await _listed_after(_response("200 OK", LIST))
	assert_eq(names, ["phi3", "qwen2.5:3b-instruct", "qwen2.5:7b-instruct"])
	assert_eq(_page._models.selected, 0)


func test_picking_a_model_stores_it_and_fills_the_field() -> void:
	await _listed_after(_response("200 OK", LIST))
	_page._models.item_selected.emit(1)
	assert_eq(_settings.profiles.active["model"], "qwen2.5:7b-instruct")
	assert_eq(_page._fields["model"].text, "qwen2.5:7b-instruct")


func test_without_an_answer_the_saved_model_is_shown_with_a_note() -> void:
	var names := await _listed_after(_response("500 Internal Server Error", "{}"))
	assert_eq(names, [GameSettings.DEFAULT_LANGUAGE_MODEL["model"]])
	assert_ne(_page._models_note.text, "")


func test_claude_models_are_asked_with_the_key_and_not_without_it() -> void:
	_settings.profiles.select("Claude")
	_settings.profiles.set_value("endpoint", "http://127.0.0.1:%d/v1" % _port)
	await _page.show_models()
	assert_eq(_names(), ["claude-opus-5-5"])
	assert_string_contains(_page._models_note.text, "key")
	_settings.profiles.set_value("api_key", "sk-ant-test")
	var list := '{"data": [{"id": "claude-opus-5-5"}, {"id": "claude-haiku-5-5"}]}'
	var asked := await _ask_and_answer(_page.show_models, _response("200 OK", list))
	assert_string_contains(asked[0], "x-api-key: sk-ant-test")
	assert_eq(_names(), ["claude-opus-5-5", "claude-haiku-5-5"])


func test_switching_to_a_provider_without_a_key_sends_nothing_of_the_other_providers_key() -> void:
	_settings.profiles.set_value("api_key", "sk-openai")
	_page._list_profiles()
	_page._profiles.item_selected.emit(1)
	assert_eq(_page._fields["api_key"].text, "")
	assert_string_contains(_page._models_note.text, "key")
	await wait_frames(30)
	assert_false(_server.is_connection_available(), "no request went to Anthropic")


func test_the_max_tokens_field_shows_the_games_own_number_until_one_is_set() -> void:
	_page.show_settings()
	assert_eq(_page._fields["max_tokens"].placeholder_text, "60")
	_settings.profiles.select("Claude")
	_page.show_settings()
	assert_eq(_page._fields["max_tokens"].placeholder_text, "1000")


func test_the_temperature_field_shows_the_games_own_until_one_is_set() -> void:
	_page.show_settings()
	assert_eq(_page._fields["temperature"].placeholder_text, "0.5")
	assert_eq(_page._fields["temperature"].text, "")


func test_gemini_shows_its_own_tips_and_placeholders() -> void:
	_settings.profiles.select("Gemini")
	_page.show_settings()
	assert_eq(_page._fields["model"].placeholder_text, "gemini-2.5-flash-lite")
	var tip: String = _page._fields["api_key"].get_meta(TooltipView.TEXT_META)
	assert_string_contains(tip, "aistudio.google.com")


func test_changing_the_endpoint_asks_again_after_a_moment() -> void:
	var ask := func() -> Array:
		_page._fields["endpoint"].text_changed.emit(_settings.profiles.active["endpoint"])
		await wait_until(func() -> bool: return _names().size() == 2, PATIENCE_SECONDS)
		return _names()
	assert_eq((await _ask_and_answer(ask, _response("200 OK", LIST)))[1].size(), 2)


## Brings the page up with the Claude profile in use, which asks no endpoint for models without
## a key.
func _show_claude() -> void:
	_settings.profiles.select("Claude")
	_page.show_settings()


func _profile_list() -> Array:
	var names := []
	for index in _page._profiles.item_count:
		names.append(_page._profiles.get_item_text(index))
	return names


func test_the_profile_list_shows_every_profile_with_the_one_in_use_selected() -> void:
	_show_claude()
	assert_eq(_profile_list(), ["OpenAI-compatible", "Claude", "Gemini"])
	assert_eq(_page._profiles.selected, 1)
	assert_eq(_page._name.text, "Claude")


func test_new_adds_a_profile_of_the_same_provider_and_uses_it() -> void:
	_show_claude()
	_settings.profiles.set_value("model", "claude-haiku-5-5")
	_page._new_button.pressed.emit()
	assert_eq(_profile_list(), ["OpenAI-compatible", "Claude", "Gemini", "Claude 2"])
	assert_eq(_page._profiles.selected, 3)
	assert_eq(_page._name.text, "Claude 2")
	assert_eq(_page._fields["model"].text, "claude-opus-5-5", "with the provider's own model")


func test_copy_adds_a_profile_with_the_same_settings() -> void:
	_show_claude()
	_settings.profiles.set_value("model", "claude-haiku-5-5")
	_page._copy_button.pressed.emit()
	assert_eq(_page._name.text, "Claude copy")
	assert_eq(_page._fields["model"].text, "claude-haiku-5-5")


func test_delete_removes_the_profile_and_is_disabled_for_the_last_one() -> void:
	_show_claude()
	assert_false(_page._delete_button.disabled)
	_page._delete_button.pressed.emit()
	assert_eq(_profile_list(), ["OpenAI-compatible", "Gemini"])
	assert_eq(_page._name.text, "OpenAI-compatible")
	_settings.profiles.select("Gemini")
	_page.show_settings()
	_page._delete_button.pressed.emit()
	_page._delete_button.pressed.emit()
	assert_eq(_profile_list(), ["OpenAI-compatible"])
	assert_true(_page._delete_button.disabled)


func test_a_name_typed_renames_the_profile_unless_another_has_it() -> void:
	_show_claude()
	_page._name.text = "Haiku"
	_page._name.text_submitted.emit("Haiku")
	assert_eq(_profile_list(), ["OpenAI-compatible", "Haiku", "Gemini"])
	assert_eq(_settings.profiles.active["name"], "Haiku")
	_page._name.text_submitted.emit("Gemini")
	assert_eq(_page._name.text, "Haiku", "the name stays")
	_page._name.text_submitted.emit("  ")
	assert_eq(_page._name.text, "Haiku")
	assert_eq(_profile_list(), ["OpenAI-compatible", "Haiku", "Gemini"])


func test_choosing_another_provider_gives_the_profile_its_endpoint_and_model() -> void:
	_show_claude()
	_page._provider.item_selected.emit(2)
	assert_eq(_settings.profiles.active["provider"], "gemini")
	assert_eq(
		_page._fields["endpoint"].text, "https://generativelanguage.googleapis.com/v1beta/openai"
	)
	assert_eq(_page._fields["model"].text, "gemini-2.5-flash-lite")
	assert_eq(_page._provider.selected, 2)
	assert_eq(_page._name.text, "Claude", "the name stays")
