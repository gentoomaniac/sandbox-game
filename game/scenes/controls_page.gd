class_name ControlsPage
extends VBoxContainer
## The key bindings screen: one row per game action with its two bindings. Click a binding
## and press a key or mouse button to set it (Escape cancels, Delete clears); right-click or
## Delete on a focused binding clears it. The rules are GameSettings'.

signal back_requested

const NAME_WIDTH := 100
const BINDING_WIDTH := 74
const HINT := "Click a binding, then press a key. Esc cancels."
const EMPTY_BINDING := "-"
const CAPTURING_TEXT := "Press..."

var first_focus: Control

var _settings: GameSettings
## Where the next key or button goes: the action and slot, and the button showing it.
var _capture_action := &""
var _capture_slot := 0
var _capture_button: Button
## The buttons per action, indexed by slot.
var _binding_buttons := {}
var _note := Label.new()


func _init(settings: GameSettings) -> void:
	_settings = settings
	visibility_changed.connect(_stop_capture)
	var title := Label.new()
	title.text = "Controls"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(title)

	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 2)
	add_child(ScrollingList.new(rows))
	for action in GameSettings.actions():
		rows.add_child(_make_row(action))

	_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_note)
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 4)
	add_child(buttons)
	var reset := Button.new()
	reset.text = "Reset to defaults"
	reset.pressed.connect(_reset)
	TooltipView.set_text(reset, "Put every key back to its default.", "reset_bindings")
	buttons.add_child(reset)
	var back := Button.new()
	back.text = "Back"
	back.pressed.connect(back_requested.emit)
	buttons.add_child(back)
	first_focus = _binding_buttons[GameSettings.actions()[0]][0]


func show_bindings() -> void:
	_note.text = HINT
	for action in _binding_buttons:
		var events := _settings.bindings(action)
		for slot in GameSettings.MAX_BINDINGS:
			var button: Button = _binding_buttons[action][slot]
			button.text = (
				GameSettings.binding_text(events[slot]) if slot < events.size() else EMPTY_BINDING
			)


func _make_row(action: StringName) -> HBoxContainer:
	var row := HBoxContainer.new()
	var label := Label.new()
	label.text = GameSettings.action_label(action)
	label.custom_minimum_size.x = NAME_WIDTH
	label.mouse_filter = Control.MOUSE_FILTER_PASS
	var description := GameSettings.action_description(action)
	TooltipView.set_text(label, description, "action_%s" % action)
	row.add_child(label)
	_binding_buttons[action] = []
	for slot in GameSettings.MAX_BINDINGS:
		var button := Button.new()
		button.custom_minimum_size.x = BINDING_WIDTH
		button.clip_text = true
		TooltipView.set_text(button, description)
		button.pressed.connect(_start_capture.bind(action, slot, button))
		button.gui_input.connect(_on_binding_gui_input.bind(action, slot))
		row.add_child(button)
		_binding_buttons[action].append(button)
	return row


func _start_capture(action: StringName, slot: int, button: Button) -> void:
	_stop_capture()
	_capture_action = action
	_capture_slot = slot
	_capture_button = button
	button.text = CAPTURING_TEXT
	_note.text = "Press a key or mouse button. Esc cancels, Del clears."


func _stop_capture() -> void:
	if _capture_button == null:
		return
	_capture_button = null
	show_bindings()


## Comes before the GUI sees the event, so the key being bound never also moves the focus
## or leaves the menu.
func _input(event: InputEvent) -> void:
	if _capture_button == null or not GameSettings.is_bindable(event):
		return
	# A click elsewhere ends the capture and works as usual; a click on the capturing button
	# is how a mouse button gets bound.
	var is_click_elsewhere := (
		event is InputEventMouseButton
		and not _capture_button.get_global_rect().has_point(
			_capture_button.get_global_mouse_position()
		)
	)
	if is_click_elsewhere:
		_stop_capture()
		return
	get_viewport().set_input_as_handled()
	var action := _capture_action
	var slot := _capture_slot
	var button := _capture_button
	if event is InputEventKey and event.keycode == KEY_ESCAPE:
		_stop_capture()
		return
	_capture_button = null
	if event is InputEventKey and event.keycode == KEY_DELETE:
		_clear(action, slot)
		return
	var note := _settings.bind(action, slot, event)
	show_bindings()
	_note.text = note if note != "" else "Bound to " + button.text


func _on_binding_gui_input(event: InputEvent, action: StringName, slot: int) -> void:
	var is_right_click: bool = (
		event is InputEventMouseButton
		and event.pressed
		and event.button_index == MOUSE_BUTTON_RIGHT
	)
	var is_delete: bool = event is InputEventKey and event.pressed and event.keycode == KEY_DELETE
	if is_right_click or is_delete:
		_clear(action, slot)


func _clear(action: StringName, slot: int) -> void:
	if slot >= _settings.bindings(action).size():
		return
	var refusal := _settings.clear(action, slot)
	show_bindings()
	_note.text = refusal if refusal != "" else "Cleared"


func _reset() -> void:
	_settings.reset_bindings()
	show_bindings()
	_note.text = "Bindings reset to the defaults"
