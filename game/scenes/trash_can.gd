class_name TrashCan
extends HBoxContainer
## The trash can of an inventory screen: a slot with a bin. The screen sends the picked stack to
## it with `ask`, which shows "Destroy Logs (12)?" with Destroy and Keep buttons in a small panel
## over the screen (it floats, so the screen does not change size while it is up). Keep has the
## focus, so a stray Enter keeps the stack. Destroy emits `destroy_confirmed` and the screen does
## the destroying. While the question is up, any click outside its panel answers Keep and is
## swallowed, so it does nothing else; Escape is the screen's to hand to `keep()` (see
## Modal `_takes_escape`). The question is part of the screen, not a window of its own: only one
## Modal can be open.

## The bin slot was clicked.
signal pressed
signal destroy_confirmed

const BIN_ICON := preload("res://assets/ui/trash_icon.png")
const GAP := 4

var _slot := SlotView.new()
var _question := Label.new()
var _destroy_button := Button.new()
var _keep_button := Button.new()
var _prompt := PanelContainer.new()


func _init() -> void:
	add_theme_constant_override("separation", GAP)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_slot.hint = BIN_ICON
	_slot.pressed.connect(pressed.emit)
	add_child(_slot)

	_destroy_button.text = "Destroy"
	_destroy_button.pressed.connect(_on_destroy_pressed)
	_keep_button.text = "Keep"
	_keep_button.pressed.connect(keep)
	var buttons := HBoxContainer.new()
	buttons.add_child(_destroy_button)
	buttons.add_child(_keep_button)
	var column := VBoxContainer.new()
	_question.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(_question)
	column.add_child(buttons)
	_prompt.add_child(column)
	_prompt.top_level = true
	_prompt.z_index = 1
	_prompt.visible = false
	add_child(_prompt)
	set_process_input(false)


## Asks whether to destroy `count` of `item`, over the slot's lower left corner.
func ask(item: StringName, count: int) -> void:
	var item_name: String = ItemTypes.TYPES[item]["name"]
	_question.text = (
		"Destroy %s (%d)?" % [item_name, count] if count > 1 else "Destroy %s?" % item_name
	)
	_prompt.visible = true
	_prompt.reset_size()
	_prompt.global_position = _slot.global_position + Vector2(0, SlotView.SIZE - _prompt.size.y)
	_keep_button.grab_focus()
	set_process_input(true)


func is_asking() -> bool:
	return _prompt.visible


## Answers Keep: the question goes away and nothing else happens. Returns whether it was up.
func keep() -> bool:
	var was_asking := _prompt.visible
	_prompt.visible = false
	set_process_input(false)
	return was_asking


func _input(event: InputEvent) -> void:
	var is_click: bool = event is InputEventMouseButton and event.pressed
	if is_click and not _prompt.get_global_rect().has_point(event.position):
		keep()
		get_viewport().set_input_as_handled()


func _on_destroy_pressed() -> void:
	keep()
	destroy_confirmed.emit()
