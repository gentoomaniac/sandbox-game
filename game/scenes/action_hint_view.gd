class_name ActionHintView
extends CanvasLayer
## The hint over the hotbar that names what E and Use will do on the target tile ("E: Open chest",
## "Use: Harvest", see ActionHint). The key shown for E is the one the player bound. It is quiet,
## and hidden, when there is nothing to do or the game setting is off. Main says what to show each
## frame.

## Between the hint and the top of the hotbar.
const GAP := 2
const THEME := preload("res://game/scenes/ui_theme.tres")

## Names what E does (see InteractionRegistry); Main sets it.
var interactions: InteractionRegistry
var _label := Label.new()


func _init() -> void:
	_label.theme = THEME
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.visible = false
	add_child(_label)
	_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_label.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_label.offset_bottom = -(HotbarHud.BOTTOM_MARGIN + SlotView.SIZE + GAP)


func text() -> String:
	return _label.text if _label.visible else ""


## Shows what E and Use do on `target`, or nothing when `is_wanted` is false (a window is open, the
## player is building) or the setting is off.
func show_for(state: GameState, settings: GameSettings, target: Vector2i, is_wanted: bool) -> void:
	var lines: Array[String] = []
	if is_wanted and settings.is_action_hint_shown:
		var e_text := interactions.e_text(state, target)
		var e_keys := settings.bindings(&"interact")
		if e_text != "" and not e_keys.is_empty():
			lines.append("%s: %s" % [GameSettings.binding_text(e_keys[0]), e_text])
		var use_text := ActionHint.use_text(state, target)
		if use_text != "":
			lines.append("Use: " + use_text)
	_label.text = "\n".join(lines)
	_label.visible = not lines.is_empty()
