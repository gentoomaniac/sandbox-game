class_name ConsoleView
extends CanvasLayer
## The console on screen: a log and an input line at the top of the window (see Console for the
## commands). Main opens it with the console action and keeps the player still while it is open.

## Emitted after a command ran, for whatever the command changed on screen.
signal command_ran

const THEME := preload("res://game/scenes/ui_theme.tres")
const VISIBLE_LOG_LINES := 8
## The oldest lines go when the log is longer.
const MAX_LOG_LINES := 500
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
var _log_list := ScrollingList.new(_log)
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
	# Long lines (`gossip`, `crows`) wrap at the panel's width instead of being cut off.
	_log.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_log_list.keeps_bottom = true
	box.add_child(_log_list)
	_input.keep_editing_on_text_submit = true
	_input.text_submitted.connect(_on_submitted)
	_input.gui_input.connect(_on_input_gui_input)
	_input.focus_exited.connect(_on_input_focus_exited)
	box.add_child(_input)


func _ready() -> void:
	_log_list.fixed_height = VISIBLE_LOG_LINES * _log.get_line_height()


## `wildlife_spawner` puts animals in view for the `spawn` command and `wildlife_clearer` takes
## them away for `killall` (see Console). `music` is what `play` and `stop` drive, and the log says
## when a piece, rendered after the command ran, begins.
func show_state(
	state: GameState,
	wildlife_spawner := Callable(),
	wildlife_clearer := Callable(),
	music: MusicPlayer = null
) -> void:
	_console = Console.new(state)
	if music != null:
		_console.music_tracks = music.tracks
		_console.music_player = music.play
		_console.music_stopper = music.stop
		music.started.connect(func(track: String) -> void: _log_line("Playing %s" % track))
	_console.wildlife_spawner = wildlife_spawner
	_console.wildlife_clearer = wildlife_clearer


func is_open() -> bool:
	return visible


func open() -> void:
	visible = true
	_input.clear()
	_history_index = _history.size()
	_log_list.fit()
	_log_list.scroll_to_bottom()
	_focus_input()


func close() -> void:
	visible = false
	_input.release_focus()


## Runs a line as if it was typed: it is logged, remembered and answered.
func run_line(line: String) -> void:
	_log_lines.append("> " + line)
	_log_lines.append_array(_console.run(line))
	_show_log()
	if _history.is_empty() or _history[-1] != line:
		_history.append(line)
	_history_index = _history.size()
	command_ran.emit()


func _log_line(text: String) -> void:
	_log_lines.append(text)
	_show_log()


func _show_log() -> void:
	_log_lines = _log_lines.slice(-MAX_LOG_LINES)
	_log.text = "\n".join(_log_lines)


func _on_submitted(line: String) -> void:
	_input.clear()
	if line.strip_edges().is_empty():
		close()
		return
	run_line(line)


func _on_input_gui_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed:
		return
	# The pause key closes the console here: a LineEdit consumes ui_cancel while editing, so
	# main.gd's pause handler would not see it. Accepting it keeps it from opening the menu.
	if event.is_action_pressed("pause"):
		close()
		_input.accept_event()
		return
	match event.keycode:
		KEY_UP:
			_browse_history(-1)
		KEY_DOWN:
			_browse_history(1)
		KEY_PAGEUP:
			_log_list.scroll_pages(-1)
		KEY_PAGEDOWN:
			_log_list.scroll_pages(1)
		KEY_TAB:
			_input.text = _console.complete(_input.text)
			_input.caret_column = _input.text.length()
		_:
			return
	_input.accept_event()


## The input never loses focus while the console is open, e.g. to a click elsewhere.
func _on_input_focus_exited() -> void:
	if visible:
		_focus_input.call_deferred()


func _focus_input() -> void:
	_input.grab_focus()
	_input.edit()


func _browse_history(step: int) -> void:
	_history_index = clampi(_history_index + step, 0, _history.size())
	_input.text = "" if _history_index == _history.size() else _history[_history_index]
	_input.caret_column = _input.text.length()
