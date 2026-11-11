extends CharacterDragCase
## The character screen's trash can: a worn item let go on it is destroyed after the question is
## answered with Destroy; Escape answers Keep and leaves the window open.

var _trash_can: TrashCan


func before_each() -> void:
	_open_character_screen()
	_player.equipment.equip(Equipment.LEGS, ItemTypes.BREECHES)
	_trash_can = _character._trash_can
	await wait_process_frames(2)


func _drag_the_waistcoat_to_the_trash_can() -> void:
	_drag(_centre_of(_equipment_view(Equipment.BODY)), _centre_of(_trash_can._slot))


func test_a_worn_item_can_be_destroyed() -> void:
	var layers_before := _player.appearance.layers.size()
	_drag_the_waistcoat_to_the_trash_can()
	assert_eq(_trash_can._question.text, "Destroy Waistcoat?")
	_trash_can._destroy_button.pressed.emit()
	assert_eq(_player.equipment.item_in(Equipment.BODY), ItemTypes.NONE)
	assert_eq(_player.equipment.item_in(Equipment.LEGS), ItemTypes.BREECHES)
	assert_eq(_player.appearance.layers.size(), layers_before - 1, "the look loses the waistcoat")


func test_escape_answers_keep_and_only_then_closes_the_window() -> void:
	_drag_the_waistcoat_to_the_trash_can()
	var escape := InputEventAction.new()
	escape.action = &"ui_cancel"
	escape.pressed = true
	_character._unhandled_input(escape)
	assert_false(_trash_can.is_asking())
	assert_true(_character.is_open())
	assert_eq(_player.equipment.item_in(Equipment.BODY), ItemTypes.WAISTCOAT)
	_character._unhandled_input(escape)
	assert_false(_character.is_open())


func test_closing_the_window_or_switching_tabs_while_asking_destroys_nothing() -> void:
	_drag_the_waistcoat_to_the_trash_can()
	_character.open_tab(CharacterScreen.Tab.SKILLS)
	assert_false(_trash_can.is_asking())
	_character.open_tab(CharacterScreen.Tab.CHARACTER)
	_drag_the_waistcoat_to_the_trash_can()
	_character.close()
	assert_false(_trash_can.is_asking())
	assert_eq(_player.equipment.item_in(Equipment.BODY), ItemTypes.WAISTCOAT)
