class_name LoadDialog
extends Modal
## The list of saves to load from, the newest first, each with its game date and time, what made
## it and when. A row is picked with the mouse or the keys and Load asks to load it (the
## signal; what happens to the game now being played is the asker's to ask about, see
## SaveQuestions). A save that can't be loaded is shown with why, and can't be picked.

## The player picked `entry` and pressed Load. The dialog is closed.
signal load_requested(entry: SaveEntry)

const PANEL_WIDTH := 400
const NO_SAVES_TEXT := "There are no saves yet."
const UNREADABLE_TEXT := "Can't be loaded: %s\n%s"

var _base := ""
var _rows := VBoxContainer.new()
var _picking := ButtonGroup.new()
var _load_button := Button.new()
var _picked: SaveEntry


func _init() -> void:
	super()
	pauses_game = true
	is_movable = false
	# Over the pause menu it opens from, under a question about the load (see ChoiceDialog).
	layer = 15
	_panel.custom_minimum_size.x = PANEL_WIDTH
	var title := Label.new()
	title.text = "Load game"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var buttons := HBoxContainer.new()
	_load_button.text = "Load"
	_load_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_load_button.pressed.connect(_request_load)
	var cancel := Button.new()
	cancel.text = "Cancel"
	cancel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cancel.pressed.connect(close)
	buttons.add_child(_load_button)
	buttons.add_child(cancel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	column.add_child(title)
	column.add_child(_scrolling(_rows))
	column.add_child(buttons)
	_panel.add_child(column)


## Opens the list of the saves of the world at `base`.
func open_saves(base: String) -> void:
	_base = base
	close()
	open()


func _on_open() -> void:
	for row in _rows.get_children():
		_rows.remove_child(row)
		row.queue_free()
	_picked = null
	_load_button.disabled = true
	var entries := SaveList.entries(_base)
	if entries.is_empty():
		var none := Label.new()
		none.text = NO_SAVES_TEXT
		_rows.add_child(none)
	var newest_loadable: Button = null
	for entry in entries:
		var row := _row_of(entry)
		_rows.add_child(row)
		if newest_loadable == null and entry.is_loadable():
			newest_loadable = row
	if newest_loadable != null:
		newest_loadable.button_pressed = true
		newest_loadable.grab_focus()


func _row_of(entry: SaveEntry) -> Button:
	var row := Button.new()
	row.toggle_mode = true
	row.button_group = _picking
	row.alignment = HORIZONTAL_ALIGNMENT_LEFT
	if entry.is_loadable():
		row.text = "%s\n%s" % [entry.header.game_text(), entry.header.how_text()]
		row.toggled.connect(_on_row_toggled.bind(entry))
		row.pressed.connect(_load_button.grab_focus)
	else:
		var when := "" if entry.header == null else entry.header.how_text()
		row.text = UNREADABLE_TEXT % [entry.problem, when]
		row.disabled = true
	return row


func _on_row_toggled(is_on: bool, entry: SaveEntry) -> void:
	if is_on:
		_picked = entry
		_load_button.disabled = false


func _request_load() -> void:
	var entry := _picked
	close()
	load_requested.emit(entry)
