class_name GameSettings
extends RefCounted
## The player's settings: key bindings (see KeyBindings), display mode, art set, UI scale, energy
## drain, day length variation, the autosave interval, the frame rate limit, audio and the
## language model villagers talk through. They are kept in a ConfigFile, written on every change.
## It has no UI code.
##
## The file only holds what differs from the defaults. The display mode is only stored once the
## player has chosen it; until then the window stays as the command line or project left it.
## The art set, the UI scale, the energy drain, the day length variation, the autosave interval,
## the frame rate limit, whether the action hint shows, the audio settings and the language model
## are stored when they differ from their defaults.
## The model's key is kept in the file as plain text (Settings says so); it is never saved with
## the game or logged.

## Emitted when the player changes the energy drain; loading it does not, so whoever connects
## reads `energy_drain_factor()` once at start and then follows this.
signal drain_changed
## Emitted when the player changes the UI scale; loading it does not, so whoever applies the
## scale does it once after `load_file()` and then on this.
signal ui_scale_changed(scale: float)
## Emitted when the player changes the day length variation; loading it does not, so whoever
## uses it reads `day_length_variation_factor()` once at start and then follows this.
signal day_length_changed
## Emitted when the player changes the frame rate limit; loading it does not, so whoever applies
## it does it once after `load_file()` and then on this.
signal max_fps_changed(fps: int)

## Emitted when the player changes a volume or "Sound in background"; loading does not, so
## whoever applies the audio settings does it once after `load_file()` and then on this.
signal audio_changed
## Emitted when the player switches between the classic and the new art; loading does not, so
## whoever shows the art reads `is_classic_art` once at start and then follows this.
signal art_set_changed

enum EnergyDrain { LOW, NORMAL, HIGH }

const DEFAULT_PATH := "user://settings.cfg"
const DISPLAY_SECTION := "display"
const FULLSCREEN_KEY := "fullscreen"
const CLASSIC_ART_KEY := "classic_art"
const GAME_SECTION := "game"
const UI_SCALE_KEY := "ui_scale"
const ENERGY_DRAIN_KEY := "energy_drain"
const DAY_LENGTH_KEY := "day_length_variation"
const AUTOSAVE_KEY := "autosave_minutes"
const MAX_FPS_KEY := "max_fps"
const ACTION_HINT_KEY := "action_hint"
const AUDIO_SECTION := "audio"
const SOUND_IN_BACKGROUND_KEY := "in_background"

const DEFAULT_ACTION_HINT := true

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

## Minutes of play between two timed autosaves, in steps.
const MIN_AUTOSAVE_MINUTES := 10
const MAX_AUTOSAVE_MINUTES := 60
const AUTOSAVE_STEP := 10
const DEFAULT_AUTOSAVE_MINUTES := 10

## The frame rate limit in frames per second, in steps. 0 means no limit: vsync alone, which drew
## 240 fps on a 240 Hz screen and ran the CPU hot for nothing.
const NO_FPS_LIMIT := 0
const MIN_MAX_FPS := 10
const MAX_MAX_FPS := 240
const MAX_FPS_STEP := 10
const DEFAULT_MAX_FPS := 60

## The volume sliders (also the keys in the file): percent, in steps.
const VOLUME_CHANNELS: Array[StringName] = [&"master", &"effects", &"ambience", &"music"]
const MAX_VOLUME := 100
const VOLUME_STEP := 5
const DEFAULT_VOLUME := 100
const DEFAULT_SOUND_IN_BACKGROUND := true

var is_fullscreen := false
## Whether the world shows the classic art, the 16 px art doubled, where it has it, instead of
## the new art drawn at 32 px per tile (see ArtSet).
var is_classic_art := false
var ui_scale := DEFAULT_UI_SCALE
var energy_drain := DEFAULT_ENERGY_DRAIN
var day_length_variation := DEFAULT_DAY_LENGTH_VARIATION
var autosave_minutes := DEFAULT_AUTOSAVE_MINUTES
var max_fps := DEFAULT_MAX_FPS
## Whether the hint over the hotbar names what E and Use will do (see ActionHint).
var is_action_hint_shown := DEFAULT_ACTION_HINT
var sound_in_background := DEFAULT_SOUND_IN_BACKGROUND
## The profiles of the language model villagers talk through, and the one in use.
var profiles := LanguageModelProfiles.new()
## The player's key bindings, which live in the input map.
var key_bindings := KeyBindings.new()

var _has_chosen_fullscreen := false
## Channel (see VOLUME_CHANNELS) -> percent.
var _volumes := {}
var _path: String


## Create it before the input map is changed, as it takes the defaults from it.
func _init(path: String = DEFAULT_PATH) -> void:
	_path = path
	profiles.changed.connect(_save)
	key_bindings.changed.connect(_save)
	for channel in VOLUME_CHANNELS:
		_volumes[channel] = DEFAULT_VOLUME
	is_fullscreen = SettingsEngine.is_fullscreen()


func set_fullscreen(value: bool) -> void:
	is_fullscreen = value
	_has_chosen_fullscreen = true
	SettingsEngine.set_fullscreen(is_fullscreen)
	_save()


func set_classic_art(value: bool) -> void:
	is_classic_art = value
	_save()
	art_set_changed.emit()


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


## Minutes of play between timed autosaves, kept in range and on the slider's steps. The timer
## reads it as it counts, so there is no signal.
func set_autosave_minutes(minutes: int) -> void:
	autosave_minutes = _clamped_autosave(minutes)
	_save()


## The frame rate limit, `NO_FPS_LIMIT` for none; a limit stays on the slider's steps and in
## range.
func set_max_fps(fps: int) -> void:
	max_fps = _clamped_max_fps(fps)
	_save()
	max_fps_changed.emit(max_fps)


func set_action_hint_shown(value: bool) -> void:
	is_action_hint_shown = value
	_save()


## A volume in percent, 0 to 100.
func volume_percent(channel: StringName) -> int:
	return _volumes[channel]


## Percent, kept in range and on the slider's steps.
func set_volume(channel: StringName, percent: int) -> void:
	_volumes[channel] = _clamped_volume(percent)
	_save()
	audio_changed.emit()


func set_sound_in_background(value: bool) -> void:
	sound_in_background = value
	_save()
	audio_changed.emit()


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
	key_bindings.load_from(file, _path)
	if file.has_section_key(DISPLAY_SECTION, FULLSCREEN_KEY):
		var value: Variant = file.get_value(DISPLAY_SECTION, FULLSCREEN_KEY)
		if value is bool:
			is_fullscreen = value
			_has_chosen_fullscreen = true
			SettingsEngine.set_fullscreen(is_fullscreen)
		else:
			push_warning("Ignoring display setting in %s: not true or false" % _path)
	if file.has_section_key(DISPLAY_SECTION, CLASSIC_ART_KEY):
		var value: Variant = file.get_value(DISPLAY_SECTION, CLASSIC_ART_KEY)
		if value is bool:
			is_classic_art = value
		else:
			push_warning("Ignoring the art setting in %s: not true or false" % _path)
	_load_game_section(file)
	_load_audio_section(file)
	profiles.load_from(file, _path)


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
	if file.has_section_key(GAME_SECTION, AUTOSAVE_KEY):
		var value: Variant = file.get_value(GAME_SECTION, AUTOSAVE_KEY)
		if value is int and value >= MIN_AUTOSAVE_MINUTES and value <= MAX_AUTOSAVE_MINUTES:
			autosave_minutes = _clamped_autosave(value)
		else:
			push_warning("Ignoring autosave interval in %s: not a whole number 10 to 60" % _path)
	if file.has_section_key(GAME_SECTION, MAX_FPS_KEY):
		var value: Variant = file.get_value(GAME_SECTION, MAX_FPS_KEY)
		if value is int and value >= 0:
			max_fps = _clamped_max_fps(value)
		else:
			push_warning("Ignoring frame rate limit in %s: not a whole number, 0 or more" % _path)
	if file.has_section_key(GAME_SECTION, ACTION_HINT_KEY):
		var value: Variant = file.get_value(GAME_SECTION, ACTION_HINT_KEY)
		if value is bool:
			is_action_hint_shown = value
		else:
			push_warning("Ignoring action hint in %s: not true or false" % _path)


func _load_audio_section(file: ConfigFile) -> void:
	for channel in VOLUME_CHANNELS:
		if not file.has_section_key(AUDIO_SECTION, channel):
			continue
		var value: Variant = file.get_value(AUDIO_SECTION, channel)
		if value is int and value >= 0 and value <= MAX_VOLUME:
			_volumes[channel] = _clamped_volume(value)
		else:
			push_warning("Ignoring %s volume in %s: not a whole number 0 to 100" % [channel, _path])
	if file.has_section_key(AUDIO_SECTION, SOUND_IN_BACKGROUND_KEY):
		var value: Variant = file.get_value(AUDIO_SECTION, SOUND_IN_BACKGROUND_KEY)
		if value is bool:
			sound_in_background = value
		else:
			push_warning("Ignoring sound in background in %s: not true or false" % _path)


func _save() -> void:
	var file := ConfigFile.new()
	key_bindings.save_to(file)
	if _has_chosen_fullscreen:
		file.set_value(DISPLAY_SECTION, FULLSCREEN_KEY, is_fullscreen)
	if is_classic_art:
		file.set_value(DISPLAY_SECTION, CLASSIC_ART_KEY, true)
	if ui_scale != DEFAULT_UI_SCALE:
		file.set_value(GAME_SECTION, UI_SCALE_KEY, ui_scale)
	if energy_drain != DEFAULT_ENERGY_DRAIN:
		file.set_value(GAME_SECTION, ENERGY_DRAIN_KEY, ENERGY_DRAIN_NAMES[energy_drain])
	if day_length_variation != DEFAULT_DAY_LENGTH_VARIATION:
		file.set_value(GAME_SECTION, DAY_LENGTH_KEY, day_length_variation)
	if autosave_minutes != DEFAULT_AUTOSAVE_MINUTES:
		file.set_value(GAME_SECTION, AUTOSAVE_KEY, autosave_minutes)
	if max_fps != DEFAULT_MAX_FPS:
		file.set_value(GAME_SECTION, MAX_FPS_KEY, max_fps)
	if is_action_hint_shown != DEFAULT_ACTION_HINT:
		file.set_value(GAME_SECTION, ACTION_HINT_KEY, is_action_hint_shown)
	for channel in VOLUME_CHANNELS:
		if _volumes[channel] != DEFAULT_VOLUME:
			file.set_value(AUDIO_SECTION, channel, _volumes[channel])
	if sound_in_background != DEFAULT_SOUND_IN_BACKGROUND:
		file.set_value(AUDIO_SECTION, SOUND_IN_BACKGROUND_KEY, sound_in_background)
	profiles.save_to(file)
	var error := DirAccess.make_dir_recursive_absolute(_path.get_base_dir())
	if error == OK:
		error = file.save(_path)
	if error != OK:
		push_error("Can't write %s: %s" % [_path, error_string(error)])


static func _clamped_variation(percent: int) -> int:
	return clampi(
		roundi(float(percent) / DAY_LENGTH_VARIATION_STEP) * DAY_LENGTH_VARIATION_STEP,
		0,
		MAX_DAY_LENGTH_VARIATION
	)


static func _clamped_autosave(minutes: int) -> int:
	return clampi(
		roundi(float(minutes) / AUTOSAVE_STEP) * AUTOSAVE_STEP,
		MIN_AUTOSAVE_MINUTES,
		MAX_AUTOSAVE_MINUTES
	)


static func _clamped_max_fps(fps: int) -> int:
	if fps <= NO_FPS_LIMIT:
		return NO_FPS_LIMIT
	return clampi(roundi(float(fps) / MAX_FPS_STEP) * MAX_FPS_STEP, MIN_MAX_FPS, MAX_MAX_FPS)


static func _clamped_volume(percent: int) -> int:
	return clampi(roundi(float(percent) / VOLUME_STEP) * VOLUME_STEP, 0, MAX_VOLUME)
