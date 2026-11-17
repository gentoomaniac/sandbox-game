class_name KeyBindings
extends RefCounted
## The player's key bindings. They live in Godot's InputMap (that is what the game reads); this
## class edits them, remembers the project's defaults and keeps them in the `controls` section of
## the settings file (see GameSettings), which holds only what differs from the defaults: an
## action added later, or one the file doesn't mention, keeps its default binding.
## It has no UI code.

## Emitted after every change by the player, for GameSettings to save.
signal changed

const CONTROLS_SECTION := "controls"
const MAX_BINDINGS := 2
## An action's last binding can't go, or the player could lock themselves out of the menu
## that fixes bindings.
const ALWAYS_BOUND: Array[StringName] = [&"pause"]

## Actions that may share a key because they never apply at the same time: sleeping happens
## indoors at a bed, picking a building outdoors with the hammer; while the build menu is up,
## the keys it shares with walking (the arrows) pick in it and the player walks with the others
## (see BuildMode `walk_direction`).
const SHARING_PAIRS := [
	[&"interact", &"build_next"],
	[&"move_left", &"build_previous"],
	[&"move_right", &"build_next"],
	[&"move_up", &"build_style_up"],
	[&"move_down", &"build_style_down"],
]

const ACTION_LABELS := {
	&"use": "Use",
	&"use_click": "Use (mouse)",
	&"inventory": "Open the bag",
	&"character": "Open the character window",
	&"drop_item": "Drop held item",
	&"sprint": "Sprint on horseback",
	&"build_previous": "Previous building",
	&"build_next": "Next building",
	&"build_style_up": "Next style",
	&"build_style_down": "Previous style",
	&"take_down_mode": "Build or take down",
	&"zoom_in": "Zoom in",
	&"zoom_out": "Zoom out",
	&"toggle_fast_forward": "Fast forward",
	&"toggle_coordinates": "Show coordinates",
	&"toggle_paths": "Show villagers' paths",
	&"toggle_art_set": "Classic or new art",
	&"quick_save": "Quick save",
	&"quick_load": "Quick load",
	&"pause": "Pause menu",
	&"console": "Console",
}
## What each action does, for the tooltip of its row in the controls. The hotbar slots share
## one text (see `action_description`).
const ACTION_DESCRIPTIONS := {
	&"move_left": "Walk left.",
	&"move_right": "Walk right.",
	&"move_up": "Walk up.",
	&"move_down": "Walk down.",
	&"interact":
	"Open the chest or the crafting station in front of you, or sleep in the bed next to you.",
	&"use": "Use the held item on the tile in front of you, or eat held food.",
	&"use_click": "Use the held item on the tile under the mouse, or eat held food.",
	&"build_previous": "Pick the building to the left in the build menu.",
	&"build_next": "Pick the building to the right in the build menu.",
	&"build_style_up": "Pick the style above in the build menu.",
	&"build_style_down": "Pick the style below in the build menu.",
	&"take_down_mode":
	"With the hammer, switch between building and taking down. Hold Use to take down.",
	&"inventory": "Open or close the bag with the inventory.",
	&"character": "Open or close the character window: the equipment you wear.",
	&"skills": "Open or close the skills tab of the character window.",
	&"quests": "Open or close the quests tab of the character window.",
	&"crafting": "Open or close the crafting menu.",
	&"drop_item": "Drop the held stack on the ground in front of you.",
	&"sprint": "Hold to sprint on a horse that is trotting. It uses up the horse's stamina.",
	&"zoom_in": "Zoom the camera in. Ctrl and the mouse wheel zoom too.",
	&"zoom_out": "Zoom the camera out. Ctrl and the mouse wheel zoom too.",
	&"toggle_fast_forward": "Run time faster. Only for testing.",
	&"toggle_coordinates": "Show your tile coordinates in the top right corner.",
	&"toggle_paths": "Show the way of the nearest villager on a trip, in the bottom right corner.",
	&"toggle_art_set":
	"Switch between the new art, drawn at 32 px per tile, and the classic 16 px art.",
	&"quick_save": "Save the game now, in the background.",
	&"quick_load": "Load the last save at once, without asking. What you did since is lost.",
	&"console": "Open the console for commands and cheats.",
	&"pause": "Open the pause menu.",
}
## Actions older settings files may still bind (the hotbar had ten slots; the hammer had a key
## until B became the bag's): skipped without a warning.
const RETIRED_ACTIONS: Array[StringName] = [&"hotbar_9", &"hotbar_10", &"select_hammer"]
const HOTBAR_DESCRIPTION := "Select this hotbar slot."
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

## Action -> its events in the project's input map, taken before anything is changed.
var _defaults := {}
## The settings file, for what to say of it.
var _path := ""


## Create it before the input map is changed, as it takes the defaults from it.
func _init() -> void:
	for action in actions():
		_defaults[action] = InputMap.action_get_events(action)


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
	if action.begins_with("hotbar_"):
		return "Hotbar slot " + action.trim_prefix("hotbar_")
	var text := String(action).replace("_", " ")
	return text[0].to_upper() + text.substr(1)


static func action_description(action: StringName) -> String:
	if action.begins_with("hotbar_"):
		return HOTBAR_DESCRIPTION
	return ACTION_DESCRIPTIONS[action]


## A key or mouse button as text, e.g. "W", "Space", "Left mouse".
static func binding_text(event: InputEvent) -> String:
	if event is InputEventMouseButton:
		return MOUSE_BUTTON_LABELS.get(event.button_index, "Mouse %d" % event.button_index)
	if event is InputEventKey:
		var text := OS.get_keycode_string(_key_code(event))
		text = ARROW_LABELS.get(text, text)
		return "Shift+" + text if event.shift_pressed else text
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
	# Everything that has to go is worked out first, so a refusal changes nothing.
	var kept := {}
	for other in actions():
		var events := bindings(other)
		var remaining := events.filter(
			func(existing: InputEvent) -> bool:
				return (
					existing == replaced
					or not _is_same(existing, new_event)
					or (other != action and _may_share_a_key(action, other))
				)
		)
		if remaining.size() == events.size():
			continue
		if other != action and ALWAYS_BOUND.has(other) and remaining.is_empty():
			return "%s needs a key" % action_label(other)
		kept[other] = remaining
	var note := ""
	for other in kept:
		if other != action:
			note = "%s removed from %s" % [binding_text(new_event), action_label(other)]
		_set_bindings(other, kept[other])
	var target := bindings(action)
	var index := target.find(replaced)
	if index >= 0:
		target[index] = new_event
	else:
		target.append(new_event)
	_set_bindings(action, target)
	changed.emit()
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
	changed.emit()
	return ""


func reset() -> void:
	for action in _defaults:
		_set_bindings(action, _defaults[action])
	changed.emit()


## Applies the bindings of the settings `file` (read from `path`). What is not understood is
## ignored, with a warning.
func load_from(file: ConfigFile, path: String) -> void:
	_path = path
	if not file.has_section(CONTROLS_SECTION):
		return
	for action in file.get_section_keys(CONTROLS_SECTION):
		_load_action(file, StringName(action))
	_resolve_loaded_bindings()


## Stores the bindings that differ from the defaults in the settings `file`.
func save_to(file: ConfigFile) -> void:
	for action in actions():
		var events := bindings(action)
		if not _is_default(action, events):
			file.set_value(CONTROLS_SECTION, action, events.map(_encode))


func _load_action(file: ConfigFile, action: StringName) -> void:
	if RETIRED_ACTIONS.has(action):
		return
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
		# C was crafting's key until the character window took it.
		if action == &"crafting" and _is_same(event, _plain_key(KEY_C)):
			event = _shifted_key(KEY_C)
		events.append(event)
	_set_bindings(action, events.slice(0, MAX_BINDINGS))


## A hand-edited file can bind one key twice or leave the pause menu without a key. The first
## action in the input map keeps a shared key (except for actions that may share one, see
## SHARING_PAIRS), but for the bag and the character window, which are looked at first; the pause
## menu gets its defaults back.
func _resolve_loaded_bindings() -> void:
	# Each event seen so far, with the action that has it.
	var seen: Array[Array] = []
	# The bag and the character window are first: their default keys, B and C, were the hammer's
	# and crafting's, which an old file may have given to other actions; those lose them, unless the
	# file moved the window to another key.
	var order := actions()
	for window_action in [&"character", &"inventory"]:
		order.erase(window_action)
		order.push_front(window_action)
	for action in order:
		var kept: Array[InputEvent] = []
		for event in bindings(action):
			if seen.any(
				func(owned: Array) -> bool:
					return _is_same(owned[1], event) and not _may_share_a_key(owned[0], action)
			):
				push_warning(
					"%s is bound twice in %s; %s loses it" % [binding_text(event), _path, action]
				)
			else:
				kept.append(event)
				seen.append([action, event])
		_set_bindings(action, kept)
	for action in ALWAYS_BOUND:
		if not bindings(action).is_empty():
			continue
		push_warning("'%s' has no key in %s; using its default" % [action, _path])
		for event in _defaults[action]:
			for other in actions():
				_set_bindings(
					other,
					bindings(other).filter(
						func(e: InputEvent) -> bool: return not _is_same(e, event)
					)
				)
		_set_bindings(action, _defaults[action])


func _may_share_a_key(action: StringName, other: StringName) -> bool:
	return SHARING_PAIRS.any(func(pair: Array) -> bool: return pair.has(action) and pair.has(other))


func _is_default(action: StringName, events: Array[InputEvent]) -> bool:
	var defaults: Array = _defaults[action]
	if events.size() != defaults.size():
		return false
	for index in events.size():
		if not _is_same(events[index], defaults[index]):
			return false
	return true


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
		return _key_code(first) == _key_code(second) and first.shift_pressed == second.shift_pressed
	if first is InputEventMouseButton and second is InputEventMouseButton:
		return first.button_index == second.button_index
	return false


static func _encode(event: InputEvent) -> String:
	if event is InputEventKey:
		return (
			"key:%d:shift" % _key_code(event)
			if event.shift_pressed
			else "key:%d" % _key_code(event)
		)
	return "mouse:%d" % (event as InputEventMouseButton).button_index


static func _plain_key(code: Key) -> InputEventKey:
	var key := InputEventKey.new()
	key.physical_keycode = code
	return key


static func _shifted_key(code: Key) -> InputEventKey:
	var key := _plain_key(code)
	key.shift_pressed = true
	return key


## The event a file entry stands for, or null if it isn't one.
static func _decode(text: Variant) -> InputEvent:
	if not text is String:
		return null
	var parts: PackedStringArray = text.split(":")
	if parts.size() < 2 or parts.size() > 3 or not parts[1].is_valid_int():
		return null
	var number := parts[1].to_int()
	if parts[0] == "key" and number > 0 and (parts.size() == 2 or parts[2] == "shift"):
		var key := InputEventKey.new()
		key.physical_keycode = number as Key
		key.shift_pressed = parts.size() == 3
		return key
	if parts[0] == "mouse" and parts.size() == 2 and MOUSE_BUTTON_LABELS.has(number):
		var button := InputEventMouseButton.new()
		button.button_index = number as MouseButton
		return button
	return null
