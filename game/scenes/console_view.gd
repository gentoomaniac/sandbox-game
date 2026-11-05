class_name ConsoleView
extends CanvasLayer
## The console on screen: a log and an input line at the top of the window (see Console for the
## commands). Main opens it with the console action and keeps the player still while it is open.

## Emitted after a command ran, for whatever the command changed on screen.
signal command_ran

const THEME := preload("res://game/scenes/ui_theme.tres")
const VISIBLE_LOG_LINES := 8
const MARGIN := 4
## Keeps the clock and the cheat line (see CheatHud) in view above the panel.
const TOP_OFFSET := 34

var _console: Console
var _log_lines: Array[String] = []
## What was run in this session, oldest first. `_history_index` is the entry shown in the
## input while browsing it, `_history.size()` when none.
var _history: Array[String] = []
var _history_index := 0
var _log := Label.new()
var _input := LineEdit.new()


func _init() -> void:
	layer = 5
	visible = false
	var panel := PanelContainer.new()
	panel.theme = THEME
	panel.set_anchors_preset(Control.PRESET_TOP_WIDE)
	panel.offset_left = MARGIN
	panel.offset_right = -MARGIN
	panel.offset_top = TOP_OFFSET
	add_child(panel)
	var box := VBoxContainer.new()
	panel.add_child(box)
	_log.clip_text = true
	box.add_child(_log)
	_input.text_submitted.connect(_on_submitted)
	_input.gui_input.connect(_on_input_gui_input)
	box.add_child(_input)


func _ready() -> void:
	_log.custom_minimum_size.y = VISIBLE_LOG_LINES * _log.get_line_height()


func show_state(state: GameState) -> void:
	_console = Console.new(state)


func is_open() -> bool:
	return visible


func open() -> void:
	visible = true
	_input.clear()
	_history_index = _history.size()
	_input.grab_focus()


func close() -> void:
	visible = false
	_input.release_focus()


## Runs a line as if it was typed: it is logged, remembered and answered.
func run_line(line: String) -> void:
	_log_lines.append("> " + line)
	_log_lines.append_array(_console.run(line))
	_log.text = "\n".join(_log_lines.slice(-VISIBLE_LOG_LINES))
	if _history.is_empty() or _history[-1] != line:
		_history.append(line)
	_history_index = _history.size()
	command_ran.emit()


func _on_submitted(line: String) -> void:
	_input.clear()
	if line.strip_edges().is_empty():
		close()
		return
	run_line(line)


func _on_input_gui_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed:
		return
	match event.keycode:
		KEY_UP:
			_browse_history(-1)
		KEY_DOWN:
			_browse_history(1)
		KEY_TAB:
			_input.text = _console.complete(_input.text)
			_input.caret_column = _input.text.length()
		_:
			return
	_input.accept_event()


func _browse_history(step: int) -> void:
	_history_index = clampi(_history_index + step, 0, _history.size())
	_input.text = "" if _history_index == _history.size() else _history[_history_index]
	_input.caret_column = _input.text.length()
