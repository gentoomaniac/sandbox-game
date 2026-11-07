class_name ChatScreen
extends CanvasLayer
## The chat with a villager: the player's portrait on the left and the villager's on the right,
## each with the name under it, and between them a chat window as on IRC: the lines so far with
## the game time and who said them, `[08:15] <You> hello`, scrolling back with the mouse wheel or
## Page Up and Page Down, and a line to type into. Enter sends, Escape leaves.
##
## The game is paused while it is open, so nothing moves and no key reaches the game: it keeps
## running itself, and its input line takes every key. A line sent is answered by NpcDialogue;
## while the answer is awaited the villager is shown typing, and nothing more is sent to them. The
## wait is the villager's (Npc `is_answering`): the player may leave and talk to another, and the
## answer is kept in the chat of the one who was asked. The villager keeps the latest lines; the
## older ones become a memory (NpcDialogue `compact`).

## The answer to a line came and is shown (for tests and the debug runner).
signal answered

const THEME := preload("res://game/scenes/ui_theme.tres")
## What the player is called in the chat.
const PLAYER_NAME := "You"
## Portraits are drawn at this many screen pixels per art pixel.
const PORTRAIT_SCALE := 2
const PORTRAIT_SIZE := 32 * PORTRAIT_SCALE
## A name under a portrait wraps to this width.
const NAME_WIDTH := 76
const LOG_SIZE := Vector2(340, 176)
const MAX_LINE_LENGTH := 200
const GAP := 10
## Behind the portraits: palette colour mud_dark (see tools/art/palette.py).
const PORTRAIT_GROUND := Color("4f4436")

## Gives the villagers' answers. Set before the chat is opened.
var dialogue: NpcDialogue

var _npc: Npc
var _state: GameState
## Whether the interact key that opened the chat is still held (its repeats are not typed).
var _is_opening_key_held := false
var _player_portrait := Control.new()
var _npc_portrait := Control.new()
var _npc_name := Label.new()
var _log := RichTextLabel.new()
var _input := LineEdit.new()


func _init() -> void:
	layer = 5
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	var backdrop := ColorRect.new()
	backdrop.color = UiColors.BACKDROP
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)
	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.add_child(centre)
	var panel := PanelContainer.new()
	panel.theme = THEME
	centre.add_child(panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", GAP)
	panel.add_child(row)
	var player_name := Label.new()
	player_name.text = PLAYER_NAME
	row.add_child(_portrait_column(_player_portrait, player_name))
	var chat := VBoxContainer.new()
	_log.custom_minimum_size = LOG_SIZE
	_log.scroll_following = true
	_log.focus_mode = Control.FOCUS_NONE
	chat.add_child(_log)
	_input.max_length = MAX_LINE_LENGTH
	_input.placeholder_text = "Say something. Enter sends, Esc leaves."
	_input.keep_editing_on_text_submit = true
	_input.text_submitted.connect(_on_submitted)
	_input.gui_input.connect(_on_input_gui_input)
	_input.focus_exited.connect(_on_input_focus_exited)
	chat.add_child(_input)
	row.add_child(chat)
	row.add_child(_portrait_column(_npc_portrait, _npc_name))


## One line of the chat as it is shown: `[08:15] <Antje Boysen> I understand.`
static func line_text(line: Dictionary, npc_name: String) -> String:
	var speaker := PLAYER_NAME if line["from_player"] else npc_name
	return "[%s] <%s> %s" % [Sun.time_text(line["minute"]), speaker, line["text"]]


func is_open() -> bool:
	return visible


## Opens the chat with a villager of the game of `state`, its lines so far shown, and pauses the
## game.
func open(npc: Npc, state: GameState) -> void:
	_npc = npc
	_state = state
	_show_portrait(_player_portrait, state.player.appearance)
	_show_portrait(_npc_portrait, npc.appearance)
	_npc_name.text = npc.name
	visible = true
	get_tree().paused = true
	_input.clear()
	_show_lines()
	_is_opening_key_held = Input.is_action_pressed("interact")
	_input.grab_focus()
	_input.edit()


func close() -> void:
	if not visible:
		return
	visible = false
	_input.release_focus()
	get_tree().paused = false


## Says a line to the villager and waits for the answer. Ignored while they still owe one.
func say(text: String) -> void:
	var npc := _npc
	var line := text.strip_edges()
	if npc.is_answering or line.is_empty():
		return
	var clock := _state.clock
	# The chat so far: the model only follows a conversation it is told.
	var history := npc.chat_history.duplicate()
	npc.add_chat_line(clock.day, clock.minute_of_day, true, line)
	npc.is_answering = true
	_show_lines()
	var answer: String = await dialogue.reply(npc, history, line, _state)
	# Said even when the player has left meanwhile: it is there when they come back.
	npc.add_chat_line(clock.day, clock.minute_of_day, false, answer)
	npc.is_answering = false
	# Once per exchange, not per line: the two lines that drop out are one memory.
	dialogue.compact(npc, _state)
	if npc == _npc and visible:
		_show_lines()
	answered.emit()


## The lines of the chat, and the villager typing while an answer is awaited.
func _show_lines() -> void:
	var lines: Array[String] = []
	for line in _npc.chat_history:
		lines.append(line_text(line, _npc.name))
	if _npc.is_answering:
		lines.append("* %s is typing..." % _npc.name)
	_log.text = "\n".join(lines)


func _portrait_column(portrait: Control, name_label: Label) -> VBoxContainer:
	var column := VBoxContainer.new()
	var ground := ColorRect.new()
	ground.color = PORTRAIT_GROUND
	ground.custom_minimum_size = Vector2(PORTRAIT_SIZE, PORTRAIT_SIZE)
	ground.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	portrait.set_anchors_preset(Control.PRESET_FULL_RECT)
	ground.add_child(portrait)
	column.add_child(ground)
	name_label.custom_minimum_size.x = NAME_WIDTH
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	column.add_child(name_label)
	return column


## Lays the portraits of a look's layers over each other, scaled up pixel for pixel.
func _show_portrait(portrait: Control, look: Appearance) -> void:
	for child in portrait.get_children():
		child.queue_free()
	for portrait_layer in look.portrait_layers():
		var picture := TextureRect.new()
		picture.texture = load(Appearance.portrait_path(portrait_layer))
		picture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		picture.set_anchors_preset(Control.PRESET_FULL_RECT)
		portrait.add_child(picture)


func _on_submitted(text: String) -> void:
	if _npc.is_answering:
		return
	_input.clear()
	say(text)


func _on_input_gui_input(event: InputEvent) -> void:
	# The key that opened the chat may still be held: its repeats would type into the input.
	if _is_opening_key_held and event is InputEventKey and event.is_action("interact"):
		_is_opening_key_held = event.pressed
		_input.accept_event()
		return
	if not event is InputEventKey or not event.pressed:
		return
	# A LineEdit consumes ui_cancel while editing, so the pause key is caught here; accepting it
	# keeps it from opening the pause menu once the game runs again.
	if event.is_action_pressed("pause"):
		close()
		_input.accept_event()
		return
	var scroll_bar := _log.get_v_scroll_bar()
	match event.keycode:
		KEY_PAGEUP:
			scroll_bar.value -= scroll_bar.page
		KEY_PAGEDOWN:
			scroll_bar.value += scroll_bar.page
		_:
			return
	_input.accept_event()


## The input never loses focus while the chat is open, e.g. to a click elsewhere.
func _on_input_focus_exited() -> void:
	if visible:
		_input.grab_focus.call_deferred()
