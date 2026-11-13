class_name AudioPage
extends VBoxContainer
## The audio settings: a volume slider each for Master, Effects, Ambience and Music, and whether
## the game keeps playing sound while its window is not focused. The rules are GameSettings'.

signal back_requested
## The player moved a volume slider: the menu plays a sound to hear the new volume by.
signal volume_tested(channel: StringName, percent: float)

const CHANNEL_LABELS := {
	&"master": "Master", &"effects": "Effects", &"ambience": "Ambience", &"music": "Music"
}

const VOLUME_TIPS := {
	&"master": "How loud everything is.",
	&"effects": "Footsteps, tools and other sounds of what you do.",
	&"ambience": "Weather and the animals around you.",
	&"music": "The background music.",
}
const BACKGROUND_TIP := "Off: the game is silent while its window is not in focus."

var first_focus: Control

var _settings: GameSettings
var _labels := {}
var _sliders := {}
var _background_button: Button


func _init(settings: GameSettings) -> void:
	_settings = settings
	var title := Label.new()
	title.text = "Audio"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(title)
	for channel in GameSettings.VOLUME_CHANNELS:
		var label := Label.new()
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		TooltipView.set_text(label, VOLUME_TIPS[channel])
		label.mouse_filter = Control.MOUSE_FILTER_PASS
		add_child(label)
		_labels[channel] = label
		var slider := HSlider.new()
		slider.max_value = GameSettings.MAX_VOLUME
		slider.step = GameSettings.VOLUME_STEP
		slider.value_changed.connect(_on_volume_changed.bind(channel))
		TooltipView.set_text(slider, VOLUME_TIPS[channel], "setting_%s_volume" % channel)
		add_child(slider)
		_sliders[channel] = slider
	first_focus = _sliders[GameSettings.VOLUME_CHANNELS[0]]
	_background_button = Button.new()
	_background_button.pressed.connect(_toggle_sound_in_background)
	TooltipView.set_text(_background_button, BACKGROUND_TIP, "setting_sound_in_background")
	add_child(_background_button)
	var back := Button.new()
	back.text = "Back"
	back.pressed.connect(back_requested.emit)
	add_child(back)


## Brings the sliders and the button up to date with the settings.
func show_settings() -> void:
	for channel in GameSettings.VOLUME_CHANNELS:
		_sliders[channel].set_value_no_signal(_settings.volume_percent(channel))
		_show_volume(channel, _settings.volume_percent(channel))
	_show_sound_in_background()


func _show_volume(channel: StringName, percent: float) -> void:
	_labels[channel].text = "%s volume %d %%" % [CHANNEL_LABELS[channel], roundi(percent)]


func _on_volume_changed(percent: float, channel: StringName) -> void:
	_show_volume(channel, percent)
	_settings.set_volume(channel, roundi(percent))
	volume_tested.emit(channel, percent)


func _toggle_sound_in_background() -> void:
	_settings.set_sound_in_background(not _settings.sound_in_background)
	_show_sound_in_background()


func _show_sound_in_background() -> void:
	_background_button.text = (
		"Sound in background: " + ("On" if _settings.sound_in_background else "Off")
	)
