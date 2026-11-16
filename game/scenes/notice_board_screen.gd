class_name NoticeBoardScreen
extends Modal
## The window of the notice board (E on it, see BoardNotices): the rough line of each quest posted
## and not taken yet, with whom to see, or "Nothing new on the board.". It gives no quest: the
## villager does. E, Escape or the close button closes it. The lines scroll when the window has no
## room for them.

const TITLE_TEXT := "Notice board"
const WIDTH := 280
const LINE_GAP := 8

var _title_label := Label.new()
var _lines := VBoxContainer.new()
var _state: GameState


func _init() -> void:
	super()
	pauses_game = true
	close_actions = [&"interact"]
	_title_label.text = TITLE_TEXT
	_title_label.theme_type_variation = &"TitleLabel"
	_lines.add_theme_constant_override("separation", LINE_GAP)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", LINE_GAP)
	column.add_child(_title_label)
	column.add_child(_scrolling(_lines))
	_panel.add_child(column)


## Opens the board of the game of `state`.
func open_board(state: GameState) -> void:
	close()
	_state = state
	open()


func _on_open() -> void:
	for line in _lines.get_children():
		_lines.remove_child(line)
		line.free()
	for text in BoardNotices.lines(_state):
		var label := Label.new()
		label.text = text
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.custom_minimum_size.x = WIDTH
		_lines.add_child(label)
