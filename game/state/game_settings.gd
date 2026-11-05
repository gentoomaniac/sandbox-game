class_name GameSettings
extends RefCounted
## The player's settings: key bindings, display mode, UI scale, energy drain and day length
## variation. Bindings live in Godot's InputMap (that is what the game reads); this class edits
## them, remembers the project's defaults and keeps them in a ConfigFile, written on every
## change. It has no UI code.
##
## The file only holds what differs from the defaults, so an action added later, or one the
## file doesn't mention, keeps its default binding. The display mode is only stored once the
## player has chosen it; until then the window stays as the command line or project left it.
## The UI scale, the energy drain and the day length variation are stored when they differ
## from their defaults.

## Emitted when the player changes the energy drain; loading it does not, so whoever connects
## reads `energy_drain_factor()` once at start and then follows this.
signal drain_changed
## Emitted when the player changes the UI scale; loading it does not, so whoever applies the
## scale does it once after `load_file()` and then on this.
signal ui_scale_changed(scale: float)
## Emitted when the player changes the day length variation; loading it does not, so whoever
## uses it reads `day_length_variation_factor()` once at start and then follows this.
signal day_length_changed

enum EnergyDrain { LOW, NORMAL, HIGH }

const DEFAULT_PATH := "user://settings.cfg"
const MAX_BINDINGS := 2
## An action's last binding can't go, or the player could lock themselves out of the menu
## that fixes bindings.
const ALWAYS_BOUND: Array[StringName] = [&"pause"]

## Actions that may share a key because they never apply at the same time: sleeping happens
## indoors at a bed, picking a building outdoors with the hammer.
const SHARING_PAIRS := [[&"interact", &"build_next"]]

const CONTROLS_SECTION := "controls"
const DISPLAY_SECTION := "display"
const FULLSCREEN_KEY := "fullscreen"
const GAME_SECTION := "game"
const UI_SCALE_KEY := "ui_scale"
const ENERGY_DRAIN_KEY := "energy_drain"
const DAY_LENGTH_KEY := "day_length_variation"

const MIN_UI_SCALE := 0.5
const MAX_UI_SCALE := 2.0
const UI_SCALE_STEP := 0.25
const DEFAULT_UI_SCALE := 1.0
const DEFAULT_ENERGY_DRAIN := EnergyDrain.NORMAL
## Energy drain as stored in the file, and its multiplier.
const ENERGY_DRAIN_NAMES := {
	EnergyDrain.LOW: "low", EnergyDrain.NORMAL: "normal", EnergyDrain.HIGH: "high"
}
const ENERGY_DRAIN_FACTORS := {EnergyDrain.LOW: 0.5, EnergyDrain.NORMAL: 1.0, EnergyDrain.HIGH: 1.5}

## Day length variation in percent: how much of the yearly swing of the day length applies.
const MAX_DAY_LENGTH_VARIATION := 100
const DAY_LENGTH_VARIATION_STEP := 10
const DEFAULT_DAY_LENGTH_VARIATION := 100

const ACTION_LABELS := {
	&"use": "Use",
	&"use_click": "Use (mouse)",
	&"select_hammer": "Select hammer",
	&"build_previous": "Previous building",
	&"build_next": "Next building",
	&"toggle_fast_forward": "Fast forward",
	&"toggle_coordinates": "Show coordinates",
	&"pause": "Pause menu",
	&"console": "Console",
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
var ui_scale := DEFAULT_UI_SCALE
var energy_drain := DEFAULT_ENERGY_DRAIN
var day_length_variation := DEFAULT_DAY_LENGTH_VARIATION

var _has_chosen_fullscreen := false
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
	if action.begins_with("hotbar_"):
		return "Hotbar slot " + action.trim_prefix("hotbar_")
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
	_has_chosen_fullscreen = true
	_apply_display()
	_save()


## Scales all UI, but not the world: that is drawn on the whole window by CameraController
## whatever the scale. The value is kept in range and on the slider's steps.
func set_ui_scale(value: float) -> void:
	ui_scale = clampf(snappedf(value, UI_SCALE_STEP), MIN_UI_SCALE, MAX_UI_SCALE)
	_save()
	ui_scale_changed.emit(ui_scale)


## The drain after `drain`, wrapping round: what a button that cycles through them sets next.
static func next_drain(drain: EnergyDrain) -> EnergyDrain:
	return ((drain + 1) % EnergyDrain.size()) as EnergyDrain


func set_energy_drain(value: EnergyDrain) -> void:
	energy_drain = value
	_save()
	drain_changed.emit()


## What energy costs and drain are multiplied by.
func energy_drain_factor() -> float:
	return ENERGY_DRAIN_FACTORS[energy_drain]


## Percent, kept in range and on the slider's steps.
func set_day_length_variation(percent: int) -> void:
	day_length_variation = _clamped_variation(percent)
	_save()
	day_length_changed.emit()


## The share of the yearly day length swing that applies, 0 to 1 (see Sun).
func day_length_variation_factor() -> float:
	return day_length_variation / 100.0


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
		_resolve_loaded_bindings()
	if file.has_section_key(DISPLAY_SECTION, FULLSCREEN_KEY):
		var value: Variant = file.get_value(DISPLAY_SECTION, FULLSCREEN_KEY)
		if value is bool:
			is_fullscreen = value
			_has_chosen_fullscreen = true
			_apply_display()
		else:
			push_warning("Ignoring display setting in %s: not true or false" % _path)
	_load_game_section(file)


func _load_game_section(file: ConfigFile) -> void:
	if file.has_section_key(GAME_SECTION, UI_SCALE_KEY):
		var value: Variant = file.get_value(GAME_SECTION, UI_SCALE_KEY)
		if (value is float or value is int) and value >= MIN_UI_SCALE and value <= MAX_UI_SCALE:
			ui_scale = snappedf(value, UI_SCALE_STEP)
		else:
			push_warning("Ignoring UI scale in %s: not a number from 0.5 to 2" % _path)
	if file.has_section_key(GAME_SECTION, ENERGY_DRAIN_KEY):
		var drain: Variant = ENERGY_DRAIN_NAMES.find_key(
			file.get_value(GAME_SECTION, ENERGY_DRAIN_KEY)
		)
		if drain != null:
			energy_drain = drain
		else:
			push_warning("Ignoring energy drain in %s: not low, normal or high" % _path)
	if file.has_section_key(GAME_SECTION, DAY_LENGTH_KEY):
		var value: Variant = file.get_value(GAME_SECTION, DAY_LENGTH_KEY)
		if value is int and value >= 0 and value <= MAX_DAY_LENGTH_VARIATION:
			day_length_variation = _clamped_variation(value)
		else:
			push_warning("Ignoring day length variation in %s: not a whole number 0 to 100" % _path)


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


## A hand-edited file can bind one key twice or leave the pause menu without a key. The first
## action in the input map keeps a shared key (except for actions that may share one, see
## SHARING_PAIRS); the pause menu gets its defaults back.
func _resolve_loaded_bindings() -> void:
	# Each event seen so far, with the action that has it.
	var seen: Array[Array] = []
	for action in actions():
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


func _save() -> void:
	var file := ConfigFile.new()
	for action in actions():
		var events := bindings(action)
		if not _is_default(action, events):
			file.set_value(CONTROLS_SECTION, action, events.map(_encode))
	if _has_chosen_fullscreen:
		file.set_value(DISPLAY_SECTION, FULLSCREEN_KEY, is_fullscreen)
	if ui_scale != DEFAULT_UI_SCALE:
		file.set_value(GAME_SECTION, UI_SCALE_KEY, ui_scale)
	if energy_drain != DEFAULT_ENERGY_DRAIN:
		file.set_value(GAME_SECTION, ENERGY_DRAIN_KEY, ENERGY_DRAIN_NAMES[energy_drain])
	if day_length_variation != DEFAULT_DAY_LENGTH_VARIATION:
		file.set_value(GAME_SECTION, DAY_LENGTH_KEY, day_length_variation)
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


static func _clamped_variation(percent: int) -> int:
	return clampi(
		roundi(float(percent) / DAY_LENGTH_VARIATION_STEP) * DAY_LENGTH_VARIATION_STEP,
		0,
		MAX_DAY_LENGTH_VARIATION
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
