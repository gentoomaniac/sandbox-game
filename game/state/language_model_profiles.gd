class_name LanguageModelProfiles
extends RefCounted
## The profiles of the language model villagers talk through (see NpcDialogue), and the one in
## use. A profile has a name of its own, a provider (see GameSettings `LANGUAGE_MODEL_PROVIDERS`)
## and that provider's settings: the endpoint (such as "http://127.0.0.1:11434/v1", see
## OpenAiChat and ClaudeChat), the model, the most tokens and the temperature of an answer, and
## how many lines of a chat, stories and long-term memories a villager keeps. Several profiles may
## share a provider, say Gemini with a pro and a flash model. The key is the provider's, not the
## profile's: it is entered once and only ever sent to its own provider, and is kept out of the
## profiles.

## Emitted after every change, for GameSettings to save.
signal changed

const SECTION := "language_model"
const PROFILES_KEY := "profiles"
const ACTIVE_KEY := "active"
## Before there were profiles: the provider in use, and the lines kept, one for all providers.
const OLD_PROVIDER_KEY := "provider"
const OLD_CHAT_HISTORY_LINES_KEY := "chat_history_lines"
## What a profile sets as text. `max_tokens` and `temperature` empty are the game's own (see
## ModelChat.max_tokens_of and temperature_of).
const TEXT_KEYS: Array[String] = ["endpoint", "model", "max_tokens", "temperature"]

## How many of the latest lines of a chat a villager keeps (and tells the model); the older ones
## are compacted into a memory (see NpcDialogue `compact`).
const MIN_CHAT_HISTORY_LINES := 2
const MAX_CHAT_HISTORY_LINES := 200
const DEFAULT_CHAT_HISTORY_LINES := 24
## How many stories a villager keeps in the gossip buffer (see Npc `keep_stories`).
const MIN_STORIES_KEPT := 1
const MAX_STORIES_KEPT := 100
const DEFAULT_STORIES_KEPT := 10
## How many long-term memories a villager keeps (see Npc `keep_memories`).
const MIN_MEMORIES_KEPT := 1
const MAX_MEMORIES_KEPT := 200
const DEFAULT_MEMORIES_KEPT := 20

## The profile in use: {name, provider, endpoint, model, max_tokens, temperature,
## chat_history_lines, stories_kept, memories_kept}.
var active: Dictionary

## Every profile, with a name of its own each.
var _profiles: Array[Dictionary] = _default_profiles()
## The key of each provider (it is never sent to another), by provider.
var _api_keys := _no_api_keys()
## The settings file, for what to say of it.
var _path := ""


func _init() -> void:
	active = _profiles[0]


## What the chats are asked of: the profile in use with the key of its provider.
func language_model() -> Dictionary:
	var model := active.duplicate()
	model["api_key"] = _api_keys[active["provider"]]
	return model


## The names of the profiles, in order.
func names() -> Array[String]:
	var all: Array[String] = []
	for profile in _profiles:
		all.append(profile["name"])
	return all


## Sets the endpoint, the model, the tokens or the temperature of the profile in use, or the key
## ("api_key") of its provider, without the spaces around it.
func set_value(key: String, text: String) -> void:
	if key == "api_key":
		_api_keys[active["provider"]] = text.strip_edges()
	else:
		active[key] = text.strip_edges()
	changed.emit()


## Lines kept in range. Villagers apply it (NpcDialogue `compact_all`) once the menu is closed,
## not at every step of the Settings page's slider.
func set_chat_history_lines(lines: int) -> void:
	active["chat_history_lines"] = clampi(lines, MIN_CHAT_HISTORY_LINES, MAX_CHAT_HISTORY_LINES)
	changed.emit()


## Stories kept in range. Applied like the lines (see `set_chat_history_lines`).
func set_stories_kept(stories: int) -> void:
	active["stories_kept"] = clampi(stories, MIN_STORIES_KEPT, MAX_STORIES_KEPT)
	changed.emit()


## Memories kept in range. Applied like the lines (see `set_chat_history_lines`).
func set_memories_kept(memories: int) -> void:
	active["memories_kept"] = clampi(memories, MIN_MEMORIES_KEPT, MAX_MEMORIES_KEPT)
	changed.emit()


## Uses the profile called `profile_name`; an unknown name changes nothing.
func select(profile_name: String) -> void:
	for profile in _profiles:
		if profile["name"] == profile_name:
			active = profile
			changed.emit()


## Adds a profile for `provider` (a key of GameSettings `LANGUAGE_MODEL_PROVIDERS`), with its
## endpoint and model, and uses it.
func add(provider: String) -> void:
	var added := _new_profile(
		provider, _unused_name(GameSettings.LANGUAGE_MODEL_PROVIDERS[provider]["name"])
	)
	_profiles.append(added)
	active = added
	changed.emit()


## Adds a copy of the profile in use, with a name of its own, and uses it.
func copy() -> void:
	var copied := active.duplicate()
	copied["name"] = _unused_name("%s copy" % active["name"])
	_profiles.append(copied)
	active = copied
	changed.emit()


## Renames the profile in use, without the spaces around the name. Another profile's name or none
## is refused: the name stays and this is false.
func rename(new_name: String) -> bool:
	new_name = new_name.strip_edges()
	if new_name == active["name"]:
		return true
	if new_name == "" or new_name in names():
		return false
	active["name"] = new_name
	changed.emit()
	return true


## Removes the profile in use and uses the one before it (the first, if it was the first). The
## last profile can't be removed: this is false then.
func delete() -> bool:
	if _profiles.size() == 1:
		return false
	var index := _profiles.find(active)
	_profiles.remove_at(index)
	active = _profiles[maxi(index - 1, 0)]
	changed.emit()
	return true


## Gives the profile in use another provider, with the endpoint and model that provider starts
## with; the rest of the profile stays.
func set_provider(provider: String) -> void:
	active["provider"] = provider
	active["endpoint"] = GameSettings.LANGUAGE_MODEL_PROVIDERS[provider]["endpoint"]
	active["model"] = GameSettings.LANGUAGE_MODEL_PROVIDERS[provider]["model"]
	changed.emit()


## Applies the language model of the settings `file` (read from `path`). What is not understood
## is ignored, with a warning.
func load_from(file: ConfigFile, path: String) -> void:
	_path = path
	for provider: String in GameSettings.LANGUAGE_MODEL_PROVIDERS:
		var section := _section_of(provider)
		if file.has_section_key(section, "api_key"):
			var key: Variant = file.get_value(section, "api_key")
			if key is String:
				_api_keys[provider] = key.strip_edges()
			else:
				push_warning("Ignoring language model api_key in %s: not a text" % _path)
	if file.has_section_key(SECTION, PROFILES_KEY):
		_load_profiles(file.get_value(SECTION, PROFILES_KEY))
	else:
		_upgrade_to_profiles(file)
	_load_active(file)


## Stores what differs from the defaults in the settings `file`.
func save_to(file: ConfigFile) -> void:
	if _profiles != _default_profiles():
		file.set_value(SECTION, PROFILES_KEY, _profiles)
	if active != _profiles[0]:
		file.set_value(SECTION, ACTIVE_KEY, active["name"])
	for provider: String in GameSettings.LANGUAGE_MODEL_PROVIDERS:
		if _api_keys[provider] != "":
			file.set_value(_section_of(provider), "api_key", _api_keys[provider])


## A profile for each provider, named after it, the test LLM's first.
static func _default_profiles() -> Array[Dictionary]:
	var profiles: Array[Dictionary] = []
	for provider: String in GameSettings.LANGUAGE_MODEL_PROVIDERS:
		profiles.append(
			_new_profile(provider, GameSettings.LANGUAGE_MODEL_PROVIDERS[provider]["name"])
		)
	return profiles


static func _new_profile(provider: String, profile_name: String) -> Dictionary:
	return {
		"name": profile_name,
		"provider": provider,
		"endpoint": GameSettings.LANGUAGE_MODEL_PROVIDERS[provider]["endpoint"],
		"model": GameSettings.LANGUAGE_MODEL_PROVIDERS[provider]["model"],
		"max_tokens": "",
		"temperature": "",
		"chat_history_lines": DEFAULT_CHAT_HISTORY_LINES,
		"stories_kept": DEFAULT_STORIES_KEPT,
		"memories_kept": DEFAULT_MEMORIES_KEPT,
	}


static func _no_api_keys() -> Dictionary:
	var keys := {}
	for provider: String in GameSettings.LANGUAGE_MODEL_PROVIDERS:
		keys[provider] = ""
	return keys


## The section of the settings file a provider's key is in (and its settings, before there were
## profiles): that of the default provider is the one they were in before there were more.
static func _section_of(provider: String) -> String:
	if provider == GameSettings.DEFAULT_LANGUAGE_MODEL["provider"]:
		return SECTION
	return "%s.%s" % [SECTION, provider]


## `wanted`, or numbered ("Claude 2") if a profile has it already.
func _unused_name(wanted: String) -> String:
	var taken := names()
	var unused := wanted
	var number := 2
	while unused in taken:
		unused = "%s %d" % [wanted, number]
		number += 1
	return unused


## Replaces the profiles with those of the file that are understood (none of them: leaves the
## default ones).
func _load_profiles(stored: Variant) -> void:
	if not stored is Array:
		push_warning("Ignoring the language model profiles in %s: not a list" % _path)
		return
	var loaded: Array[Dictionary] = []
	var taken := {}
	for entry: Variant in stored:
		var checked := _checked_profile(entry)
		if checked.is_empty() or taken.has(checked["name"]):
			push_warning("Ignoring a language model profile in %s: not understood" % _path)
			continue
		taken[checked["name"]] = true
		loaded.append(checked)
	if not loaded.is_empty():
		_profiles = loaded


## The profile `entry` of the file with what is not understood left at the defaults, or none
## if it has no name or no known provider.
func _checked_profile(entry: Variant) -> Dictionary:
	if not entry is Dictionary:
		return {}
	var profile_name: Variant = entry.get("name")
	var provider: Variant = entry.get("provider")
	if not profile_name is String or profile_name.strip_edges() == "":
		return {}
	if not provider is String or not provider in GameSettings.LANGUAGE_MODEL_PROVIDERS:
		return {}
	var checked := _new_profile(provider, profile_name.strip_edges())
	for key in TEXT_KEYS:
		if not entry.has(key):
			continue
		if entry[key] is String:
			checked[key] = entry[key].strip_edges()
		else:
			push_warning("Ignoring language model %s in %s: not a text" % [key, _path])
	if entry.has("chat_history_lines"):
		checked["chat_history_lines"] = _checked_count(
			"chat history lines",
			entry["chat_history_lines"],
			MIN_CHAT_HISTORY_LINES,
			MAX_CHAT_HISTORY_LINES,
			DEFAULT_CHAT_HISTORY_LINES
		)
	if entry.has("stories_kept"):
		checked["stories_kept"] = _checked_count(
			"stories kept",
			entry["stories_kept"],
			MIN_STORIES_KEPT,
			MAX_STORIES_KEPT,
			DEFAULT_STORIES_KEPT
		)
	if entry.has("memories_kept"):
		checked["memories_kept"] = _checked_count(
			"memories kept",
			entry["memories_kept"],
			MIN_MEMORIES_KEPT,
			MAX_MEMORIES_KEPT,
			DEFAULT_MEMORIES_KEPT
		)
	return checked


## Settings files from before the profiles had each provider's endpoint, model and tokens in
## its section, and one number of lines kept for all: each provider's become a profile named
## after it (the default ones), with that number of lines.
func _upgrade_to_profiles(file: ConfigFile) -> void:
	var lines := DEFAULT_CHAT_HISTORY_LINES
	if file.has_section_key(SECTION, OLD_CHAT_HISTORY_LINES_KEY):
		lines = _checked_count(
			"chat history lines",
			file.get_value(SECTION, OLD_CHAT_HISTORY_LINES_KEY),
			MIN_CHAT_HISTORY_LINES,
			MAX_CHAT_HISTORY_LINES,
			lines
		)
	for profile in _profiles:
		var section := _section_of(profile["provider"])
		profile["chat_history_lines"] = lines
		for key in TEXT_KEYS:
			if not file.has_section_key(section, key):
				continue
			var value: Variant = file.get_value(section, key)
			if value is String:
				profile[key] = value.strip_edges()
			else:
				push_warning("Ignoring language model %s in %s: not a text" % [key, _path])


## Uses the profile the file says is in use: by its name, or the first of the provider it names
## (as before there were profiles).
func _load_active(file: ConfigFile) -> void:
	var chosen: Variant = file.get_value(
		SECTION, ACTIVE_KEY, file.get_value(SECTION, OLD_PROVIDER_KEY, "")
	)
	active = _profiles[0]
	for profile in _profiles:
		if profile["name"] == chosen:
			active = profile
			return
	for profile in _profiles:
		if profile["provider"] == chosen:
			active = profile
			return
	if chosen != "":
		push_warning("Ignoring language model profile in use in %s: not known" % _path)


## `value` of the setting `label` if it is a whole number from `low` to `high`, else `fallback`.
func _checked_count(label: String, value: Variant, low: int, high: int, fallback: int) -> int:
	if value is int and value >= low and value <= high:
		return value
	push_warning("Ignoring %s in %s: not a whole number %d to %d" % [label, _path, low, high])
	return fallback
