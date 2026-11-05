class_name GameSettings
extends RefCounted
## The player's settings: key bindings and the display mode. Bindings live in Godot's
## InputMap (that is what the game reads); this class edits them, remembers the project's
## defaults and keeps them in a ConfigFile, written on every change. It has no UI code.
##
## The file only holds what differs from the defaults, so an action added later, or one the
## file doesn't mention, keeps its default binding.

const DEFAULT_PATH := "user://settings.cfg"
const MAX_BINDINGS := 2
## An action's last binding can't go, or the player could lock themselves out of the menu
## that fixes bindings.
const ALWAYS_BOUND: Array[StringName] = [&"pause"]

const CONTROLS_SECTION := "controls"
const DISPLAY_SECTION := "display"
const FULLSCREEN_KEY := "fullscreen"

const ACTION_LABELS := {
	&"use": "Use",
	&"use_click": "Use (mouse)",
	&"toggle_build": "Build mode",
	&"toggle_fast_forward": "Fast forward",
	&"pause": "Pause menu",
}
const MOUSE_BUTTON_LABELS := {
	MOUSE_BUTTON_LEFT: "Left mouse",
	MOUSE_BUTTON_RIGHT: "Right mouse",
	MOUSE_BUTTON_MIDDLE: "Middle mouse",
	MOUSE_BUTTON_XBUTTON1: "Mouse 4",
	MOUSE_BUTTON_XBUTTON2: "Mouse 5",
}
## Arrow keys are called just "Left" and so on by Godot, which reads like an action.
const ARROW_LABELS := {
	"Left": "Left arrow", "Right": "Right arrow", "Up": "Up arrow", "Down": "Down arrow"
}

var is_fullscreen := false

var _path: String
## Action -> its events in the project's input map, taken before anything is changed.
var _defaults := {}


## Create it before the input map is changed, as it takes the defaults from it.
func _init(path: String = DEFAULT_PATH) -> void:
	_path = path
	for action in actions():
		_defaults[action] = InputMap.action_get_events(action)
	var mode := DisplayServer.window_get_mode()
	is_fullscreen = (
		mode == DisplayServer.WINDOW_MODE_FULLSCREEN
		or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
	)


## The game's actions: everything in the input map except Godot's own `ui_*` ones.
static func actions() -> Array[StringName]:
	var game_actions: Array[StringName] = []
	for action in InputMap.get_actions():
		if not action.begins_with("ui_"):
			game_actions.append(action)
	return game_actions


## A readable name for an action; actions without a table entry get their id tidied.
static func action_label(action: StringName) -> String:
	if ACTION_LABELS.has(action):
		return ACTION_LABELS[action]
	var text := String(action).replace("_", " ")
	return text[0].to_upper() + text.substr(1)


## A key or mouse button as text, e.g. "W", "Space", "Left mouse".
static func binding_text(event: InputEvent) -> String:
	if event is InputEventMouseButton:
		return MOUSE_BUTTON_LABELS.get(event.button_index, "Mouse %d" % event.button_index)
	if event is InputEventKey:
		var text := OS.get_keycode_string(_key_code(event))
		return ARROW_LABELS.get(text, text)
	return "?"


func bindings(action: StringName) -> Array[InputEvent]:
	return InputMap.action_get_events(action)


## Whether `event` is one the player can bind: a key or a mouse button (not the wheel).
static func is_bindable(event: InputEvent) -> bool:
	if event is InputEventKey:
		return event.pressed and not event.echo
	if event is InputEventMouseButton:
		return event.pressed and MOUSE_BUTTON_LABELS.has(event.button_index)
	return false


## Makes `event` the binding in `slot` (0 or 1) of `action`. The same key or button on any
## other binding is removed. Returns a note to show the player ("W removed from Move up"),
## or "" if there is nothing to say; a refusal is also a note.
func bind(action: StringName, slot: int, event: InputEvent) -> String:
	var new_event := _normalised(event)
	var own := bindings(action)
	var replaced: InputEvent = own[slot] if slot < own.size() else null
	if replaced != null and _is_same(replaced, new_event):
		return ""
	var note := ""
	for other in actions():
		var kept := bindings(other).filter(
			func(existing: InputEvent) -> bool:
				return existing == replaced or not _is_same(existing, new_event)
		)
		if kept.size() == bindings(other).size():
			continue
		if other != action and ALWAYS_BOUND.has(other) and kept.is_empty():
			return "%s needs a key" % action_label(other)
		if other != action:
			note = "%s removed from %s" % [binding_text(new_event), action_label(other)]
		_set_bindings(other, kept)
	var target := bindings(action)
	var index := target.find(replaced)
	if index >= 0:
		target[index] = new_event
	else:
		target.append(new_event)
	_set_bindings(action, target)
	_save()
	return note


## Removes the binding in `slot`. Returns a note if that is refused, else "".
func clear(action: StringName, slot: int) -> String:
	var events := bindings(action)
	if slot >= events.size():
		return ""
	if ALWAYS_BOUND.has(action) and events.size() == 1:
		return "%s needs a key" % action_label(action)
	events.remove_at(slot)
	_set_bindings(action, events)
	_save()
	return ""


func reset_bindings() -> void:
	for action in _defaults:
		_set_bindings(action, _defaults[action])
	_save()


func set_fullscreen(value: bool) -> void:
	is_fullscreen = value
	_apply_display()
	_save()


## Reads the file and applies it. A file that can't be read or understood is ignored (with a
## warning), as is any single entry that isn't understood. A missing file is normal.
func load_file() -> void:
	if not FileAccess.file_exists(_path):
		return
	var file := ConfigFile.new()
	var error := file.load(_path)
	if error != OK:
		push_warning("Ignoring settings file %s: %s" % [_path, error_string(error)])
		return
	if file.has_section(CONTROLS_SECTION):
		for action in file.get_section_keys(CONTROLS_SECTION):
			_load_action(file, StringName(action))
	if file.has_section_key(DISPLAY_SECTION, FULLSCREEN_KEY):
		var value: Variant = file.get_value(DISPLAY_SECTION, FULLSCREEN_KEY)
		if value is bool:
			is_fullscreen = value
			_apply_display()
		else:
			push_warning("Ignoring display setting in %s: not true or false" % _path)


func _load_action(file: ConfigFile, action: StringName) -> void:
	if not _defaults.has(action):
		push_warning("Ignoring unknown action '%s' in %s" % [action, _path])
		return
	var texts: Variant = file.get_value(CONTROLS_SECTION, action)
	if not texts is Array:
		push_warning("Ignoring bindings of '%s' in %s: not a list" % [action, _path])
		return
	var events: Array[InputEvent] = []
	for text in texts:
		var event := _decode(text)
		if event == null:
			push_warning("Ignoring bindings of '%s' in %s: can't read '%s'" % [action, _path, text])
			return
		events.append(event)
	_set_bindings(action, events.slice(0, MAX_BINDINGS))


func _save() -> void:
	var file := ConfigFile.new()
	for action in actions():
		var events := bindings(action)
		if not _is_default(action, events):
			file.set_value(CONTROLS_SECTION, action, events.map(_encode))
	file.set_value(DISPLAY_SECTION, FULLSCREEN_KEY, is_fullscreen)
	var error := DirAccess.make_dir_recursive_absolute(_path.get_base_dir())
	if error == OK:
		error = file.save(_path)
	if error != OK:
		push_error("Can't write %s: %s" % [_path, error_string(error)])


func _is_default(action: StringName, events: Array[InputEvent]) -> bool:
	var defaults: Array = _defaults[action]
	if events.size() != defaults.size():
		return false
	for index in events.size():
		if not _is_same(events[index], defaults[index]):
			return false
	return true


func _apply_display() -> void:
	DisplayServer.window_set_mode(
		(
			DisplayServer.WINDOW_MODE_FULLSCREEN
			if is_fullscreen
			else DisplayServer.WINDOW_MODE_WINDOWED
		)
	)


static func _set_bindings(action: StringName, events: Array) -> void:
	InputMap.action_erase_events(action)
	for event in events:
		InputMap.action_add_event(action, event)


## The key's physical code, which is what the project's own bindings use; a key with none
## is matched by its code as typed.
static func _key_code(event: InputEventKey) -> Key:
	return event.physical_keycode if event.physical_keycode != KEY_NONE else event.keycode


## A fresh event with only what identifies the key or button, so modifiers or the press
## state never leak into a binding.
static func _normalised(event: InputEvent) -> InputEvent:
	if event is InputEventKey:
		var key := InputEventKey.new()
		key.physical_keycode = _key_code(event)
		return key
	var button := InputEventMouseButton.new()
	button.button_index = (event as InputEventMouseButton).button_index
	return button


static func _is_same(first: InputEvent, second: InputEvent) -> bool:
	if first is InputEventKey and second is InputEventKey:
		return _key_code(first) == _key_code(second)
	if first is InputEventMouseButton and second is InputEventMouseButton:
		return first.button_index == second.button_index
	return false


static func _encode(event: InputEvent) -> String:
	if event is InputEventKey:
		return "key:%d" % _key_code(event)
	return "mouse:%d" % (event as InputEventMouseButton).button_index


## The event a file entry stands for, or null if it isn't one.
static func _decode(text: Variant) -> InputEvent:
	if not text is String:
		return null
	var parts: PackedStringArray = text.split(":")
	if parts.size() != 2 or not parts[1].is_valid_int():
		return null
	var number := parts[1].to_int()
	if parts[0] == "key" and number > 0:
		var key := InputEventKey.new()
		key.physical_keycode = number as Key
		return key
	if parts[0] == "mouse" and MOUSE_BUTTON_LABELS.has(number):
		var button := InputEventMouseButton.new()
		button.button_index = number as MouseButton
		return button
	return null
