extends SaveValidationCase
## Every key the game writes into an object's state has an entry in `SaveObjectChecks`, so that a
## save with it loads, and a key without one is refused instead of passing unchecked.

## `state["key"]`, `state.get(KEY`, `state.has(Class.KEY`... : group 1 is the text of a key written
## out, group 2 the name of a constant (`KEY` or `Class.KEY`) that holds it.
const STATE_KEY_USE := (
	"\\bstate(?:\\.get\\(|\\.has\\(|\\.erase\\(|\\[)"
	+ '(?:"(\\w+)"|((?:[A-Z]\\w*\\.)?[A-Z][A-Z0-9_]*)\\b)'
)


func test_a_state_key_with_no_entry_is_refused() -> void:
	var game := _current_game()
	_with_object_edit(game, {"type": "kiln", "pos": [3, 4], "state": {"new_key": 1}})

	assert_string_contains(_refusal_of(game).reason, "new_key is not a state an object has")


func test_every_state_key_the_game_code_writes_has_an_entry() -> void:
	var keys := _state_keys_written()

	assert_gt(keys.size(), 10, "the scan finds the keys")
	for key: String in keys:
		var game := _current_game()
		_with_object_edit(game, {"type": "kiln", "pos": [3, 4], "state": {key: []}})
		var reason := _refusal_of(game).reason
		assert_false(reason.contains("is not a state"), "%s (used at %s)" % [key, keys[key]])


## The keys the game code uses on an object's state, each with where (file:line).
func _state_keys_written() -> Dictionary:
	var keys := {}
	var class_paths := {}
	for entry in ProjectSettings.get_global_class_list():
		class_paths[entry["class"]] = entry["path"]
	for path in _scripts_in("res://game/state") + _scripts_in("res://game/scenes"):
		if path.contains("/save_checks/"):
			continue
		# Elsewhere an object's state is reached through an object (`crop.state[...]`).
		var use := STATE_KEY_USE if path.ends_with("/world_object.gd") else "\\." + STATE_KEY_USE
		var code := FileAccess.get_file_as_string(path)
		for found in RegEx.create_from_string(use).search_all(code):
			var at := "%s:%d" % [path, code.left(found.get_start()).count("\n") + 1]
			var key := found.get_string(1)
			if key == "":
				key = _constant_value(found.get_string(2), path, class_paths)
			assert_ne(key, "", "the key %s at %s is no text constant" % [found.get_string(2), at])
			keys[key] = at
	return keys


## What constant `name` (`KEY` of the script at `path`, or `Class.KEY`) holds, "" if it is no text.
func _constant_value(name: String, path: String, class_paths: Dictionary) -> String:
	var script_path := path
	var constant := name
	if name.contains("."):
		var parts := name.split(".")
		script_path = class_paths.get(parts[0], "")
		constant = parts[1]
	if script_path == "":
		return ""
	var value: Variant = load(script_path).get_script_constant_map().get(constant)
	return value if value is String else ""


func _scripts_in(directory: String) -> Array[String]:
	var found: Array[String] = []
	for entry in DirAccess.get_directories_at(directory):
		found.append_array(_scripts_in(directory.path_join(entry)))
	for file in DirAccess.get_files_at(directory):
		if file.ends_with(".gd"):
			found.append(directory.path_join(file))
	return found
