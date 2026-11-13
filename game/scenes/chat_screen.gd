class_name ChatScreen
extends Modal
## The chat with a villager, laid out like a messenger: the villager's portrait on the left and
## the player's on the right, each with the name under it, and between them the lines so far as
## bubbles, the villager's on the left under their name and the player's on the right, each with
## the game time in its corner, and above each day's lines that day ("Today", "Yesterday" or the
## date), so a line of an earlier day doesn't look newer than the one after it. The window
## scrolls to the newest line, back with the mouse wheel or Page Up and Page Down, and a line to
## type into is below. Enter sends, Escape leaves. The log is LOG_SIZE, or smaller where the
## window at the current UI scale leaves less room (see `_fit_log`), and the bubbles' widths
## follow it.
##
## The game is paused while it is open (a Modal that pauses), so nothing moves and no key reaches
## the game but the art switch, which the chat passes on (`art_set_switch_pressed`): it keeps
## running itself, and its input line takes every other key, Escape included (see
## `_on_input_gui_input`). A line sent is answered by NpcDialogue;
## while the answer is awaited the villager is shown typing ("..."), and nothing more is sent to
## them; if no answer comes (the model failed), the dots go at once and the player's line stays,
## and they may write again. The wait is the villager's (Npc `is_answering`): the player may leave
## and talk to another, and the answer is kept in the chat of the one who was asked. Typing
## `/clear` makes the villager forget everything but what they know: the chat, the stories and the
## memories (for debugging); other text, also with a "/", is said as it is.
## The villager keeps the latest lines; the older ones become a memory (NpcDialogue `compact`).

## The exchange of a line is over, with the answer shown or without one (for tests and the debug
## runner).
signal answered
## The art switch key (the `toggle_art_set` action, F7 by default) was pressed in the chat, which
## pauses the game and so Main's input.
signal art_set_switch_pressed

## What the player is called in the chat.
const PLAYER_NAME := "You"
## Portraits are drawn at this many screen pixels per art pixel.
const PORTRAIT_SCALE := 2
const PORTRAIT_SIZE := 32 * PORTRAIT_SCALE
## A name under a portrait wraps to this width.
const NAME_WIDTH := 76
## The largest the log gets, in UI units.
const LOG_SIZE := Vector2(340, 176)
## The log is never squeezed below this, however small the window is: a window tinier than the
## portraits and this loses the panel's edge before the log loses its lines.
const MIN_LOG_SIZE := Vector2(128, 64)
## A bubble is at most this share of the window wide, so the two sides stay apart.
const BUBBLE_MAX_SHARE := 0.7
## Space between the bubbles of one speaker, and where the speaker changes.
const SAME_SPEAKER_GAP := 2
const OTHER_SPEAKER_GAP := 6
const BUBBLE_PADDING := Vector2(5, 3)
const LOG_PADDING := 4
const BUBBLE_CORNER := 3
const TYPING_TEXT := "..."
const MAX_LINE_LENGTH := 200
const CLEAR_COMMAND := "/clear"
const CLEARED_NOTICE := "* %s forgets your talks."
const GAP := 10
## Palette colours (see tools/art/palette.py): behind the portraits mud_dark, behind the bubbles
## ink, the villager's bubbles stone_dark and the player's water_deep, a name gold and a time
## stone_light.
const PORTRAIT_GROUND := Color("4f4436")
const LOG_GROUND := Color("1d1b26")
const NPC_BUBBLE := Color("4a4852")
const PLAYER_BUBBLE := Color("2b4561")
const NAME_COLOR := Color("eec25a")
const TIME_COLOR := Color("a8a39c")

## Gives the villagers' answers. Set before the chat is opened.
var dialogue: NpcDialogue

var _npc: Npc
## A line shown after the chat's, not part of it (what a command did); gone with the next line.
var _notice := ""
var _state: GameState
## Whether the interact key that opened the chat is still held (its repeats are not typed).
var _is_opening_key_held := false
var _player_portrait := Control.new()
var _npc_portrait := Control.new()
var _npc_name := Label.new()
## The lines, one MarginContainer each holding a bubble (or a notice), top to bottom.
var _messages := VBoxContainer.new()
var _scroll := ScrollContainer.new()
## Whether the window follows the newest line: not once the player has scrolled back.
var _is_following := true
var _log_size := LOG_SIZE
var _line_edit := LineEdit.new()


func _init() -> void:
	super()
	add_to_group(ArtSet.VIEWS)
	pauses_game = true
	layer = 5
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", GAP)
	_panel.add_child(row)
	row.add_child(_portrait_column(_npc_portrait, _npc_name))
	var chat := VBoxContainer.new()
	var log_ground := PanelContainer.new()
	var ground_box := StyleBoxFlat.new()
	ground_box.bg_color = LOG_GROUND
	ground_box.set_content_margin_all(LOG_PADDING)
	log_ground.add_theme_stylebox_override("panel", ground_box)
	_scroll.custom_minimum_size = _log_size
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.focus_mode = Control.FOCUS_NONE
	var scroll_bar := _scroll.get_v_scroll_bar()
	scroll_bar.changed.connect(_follow_newest_line)
	scroll_bar.value_changed.connect(_on_scrolled)
	_messages.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_messages.add_theme_constant_override("separation", 0)
	_scroll.add_child(_messages)
	log_ground.add_child(_scroll)
	chat.add_child(log_ground)
	_line_edit.max_length = MAX_LINE_LENGTH
	_line_edit.placeholder_text = "Enter sends, Esc leaves, /clear forgets."
	_line_edit.keep_editing_on_text_submit = true
	_line_edit.text_submitted.connect(_on_submitted)
	_line_edit.gui_input.connect(_on_input_gui_input)
	_line_edit.focus_exited.connect(_on_input_focus_exited)
	chat.add_child(_line_edit)
	row.add_child(chat)
	var player_name := Label.new()
	player_name.text = PLAYER_NAME
	row.add_child(_portrait_column(_player_portrait, player_name))


## Opens the chat with a villager of the game of `state`, its lines so far shown. Opening it again
## moves it to that villager.
func open_chat(npc: Npc, state: GameState) -> void:
	close()
	_npc = npc
	_state = state
	if not dialogue.answered.is_connected(_on_answered):
		dialogue.answered.connect(_on_answered)
	open()


func _enter_tree() -> void:
	get_viewport().size_changed.connect(refit)


func _exit_tree() -> void:
	super()
	get_viewport().size_changed.disconnect(refit)


func _on_open() -> void:
	_show_portrait(_player_portrait, _state.player.appearance)
	_show_portrait(_npc_portrait, _npc.appearance)
	_npc_name.text = _npc.name
	_line_edit.clear()
	_notice = ""
	_show_lines()
	_is_opening_key_held = Input.is_action_pressed("interact")
	_line_edit.grab_focus()
	_line_edit.edit()


func _on_close() -> void:
	# A window removed while open is closed on its way out of the tree, where releasing fails.
	if _line_edit.is_inside_tree():
		_line_edit.release_focus()


## Fits the log to the window, which changes with the window's size and the UI scale. The bubbles
## follow, and the newest line stays followed by the scroll bar's own `changed`.
func refit() -> void:
	super()
	if not visible:
		return
	# What the panel is besides the log (portraits, the input line, padding), as the log's own
	# size is part of the panel's.
	var chrome := _panel.get_combined_minimum_size() - _scroll.get_combined_minimum_size()
	var room := (
		get_viewport().get_visible_rect().size - chrome - Vector2.ONE * (2 * ScrollingList.MARGIN)
	)
	_log_size = room.clamp(MIN_LOG_SIZE, LOG_SIZE)
	_scroll.custom_minimum_size = _log_size
	for body in _messages.find_children("Text", "Label", true, false):
		_fit_text_width(body)


## Says a line to the villager, who answers it in time. Ignored while they still owe one.
func say(text: String) -> void:
	var npc := _npc
	var line := text.strip_edges()
	if npc.is_answering or line.is_empty():
		return
	if line == CLEAR_COMMAND:
		npc.forget_all_but_knowledge()
		_notice = CLEARED_NOTICE % npc.name
		_show_lines()
		return
	_notice = ""
	# The dialogue finishes the exchange, whether this window is still there or not.
	dialogue.say(npc, line, _state)
	_show_lines()


## An exchange with `npc` ended: shown if that is the villager of the open chat, the dots of an
## answer that did not come gone.
func _on_answered(npc: Npc) -> void:
	if npc == _npc and visible:
		_show_lines()
	answered.emit()


## The lines of the chat as bubbles, the villager typing while an answer is awaited, and the
## notice of a command.
func _show_lines() -> void:
	for message in _messages.get_children():
		# Out of the tree first, so nothing counts it as a line while it is freed.
		_messages.remove_child(message)
		message.free()
	# Whether the line above was the player's; null before the first and after a date.
	var previous: Variant = null
	var shown_day := 0
	for line in _npc.chat_history:
		if line["day"] != shown_day:
			shown_day = line["day"]
			_add_centred_line("Date", _day_text(shown_day))
			previous = null
		_add_bubble(line["text"], Sun.time_text(line["minute"]), line["from_player"], previous)
		previous = line["from_player"]
	if _npc.is_answering:
		_add_bubble(TYPING_TEXT, "", false, previous)
	if _notice != "":
		_add_centred_line("Notice", _notice)
	_is_following = true


## The day a run of lines was said, above it as in a messenger: "Today", "Yesterday" or the date.
func _day_text(day: int) -> String:
	var today := _state.clock.day
	if day == today:
		return "Today"
	if day == today - 1:
		return "Yesterday"
	return GameClock.date_text_of(day)


## A small line in the middle of the chat, such as the day of the lines below it or a notice.
func _add_centred_line(label_name: String, text: String) -> void:
	var label := Label.new()
	label.name = label_name
	label.text = text
	label.add_theme_color_override("font_color", TIME_COLOR)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD
	var gap := OTHER_SPEAKER_GAP if _messages.get_child_count() > 0 else 0
	_messages.add_child(_margin(label, gap))


## Adds the bubble of a line: on the right for the player, on the left for the villager, who has
## their name above the first bubble of a run. `previous` is whether the line above was the
## player's (null if no line is above it on this day), which sets the space above.
func _add_bubble(text: String, time: String, is_player: bool, previous: Variant) -> void:
	var is_run_start: bool = previous != is_player
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 0)
	if not is_player and is_run_start:
		content.add_child(_bubble_label("Name", _npc.name, NAME_COLOR))
	var body := _bubble_label("Text", text, Color.WHITE)
	content.add_child(body)
	if time != "":
		var time_label := _bubble_label("Time", time, TIME_COLOR)
		time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		content.add_child(time_label)
	var box := StyleBoxFlat.new()
	box.bg_color = PLAYER_BUBBLE if is_player else NPC_BUBBLE
	box.set_corner_radius_all(BUBBLE_CORNER)
	box.anti_aliasing = false
	box.content_margin_left = BUBBLE_PADDING.x
	box.content_margin_right = BUBBLE_PADDING.x
	box.content_margin_top = BUBBLE_PADDING.y
	box.content_margin_bottom = BUBBLE_PADDING.y
	var bubble := PanelContainer.new()
	bubble.name = "Bubble"
	bubble.add_theme_stylebox_override("panel", box)
	bubble.size_flags_horizontal = (
		Control.SIZE_SHRINK_END if is_player else Control.SIZE_SHRINK_BEGIN
	)
	bubble.add_child(content)
	var gap := 0
	if previous != null:
		gap = OTHER_SPEAKER_GAP if is_run_start else SAME_SPEAKER_GAP
	_messages.add_child(_margin(bubble, gap))
	_fit_text_width(body)


## The text takes the width it needs up to the bubble's largest and wraps there; a word too long
## for it is broken.
func _fit_text_width(body: Label) -> void:
	var window_width := _log_size.x - _scroll.get_v_scroll_bar().get_combined_minimum_size().x
	var max_width := int(window_width * BUBBLE_MAX_SHARE - BUBBLE_PADDING.x * 2)
	var font := body.get_theme_font("font")
	var font_size := body.get_theme_font_size("font_size")
	var text_size := font.get_multiline_string_size(
		body.text, HORIZONTAL_ALIGNMENT_LEFT, max_width, font_size
	)
	body.custom_minimum_size.x = ceili(minf(text_size.x, max_width))
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART


func _bubble_label(label_name: String, text: String, color: Color) -> Label:
	var label := Label.new()
	label.name = label_name
	label.text = text
	label.add_theme_color_override("font_color", color)
	return label


func _margin(child: Control, top: int) -> MarginContainer:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_top", top)
	margin.add_child(child)
	return margin


## Keeps the newest line in view when the lines make the window longer, unless the player has
## scrolled back.
func _follow_newest_line() -> void:
	if _is_following:
		var scroll_bar := _scroll.get_v_scroll_bar()
		_scroll.scroll_vertical = int(scroll_bar.max_value - scroll_bar.page)


func _on_scrolled(value: float) -> void:
	var scroll_bar := _scroll.get_v_scroll_bar()
	_is_following = value >= scroll_bar.max_value - scroll_bar.page - 1.0


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


func show_art_set() -> void:
	if visible:
		_show_portrait(_player_portrait, _state.player.appearance)
		_show_portrait(_npc_portrait, _npc.appearance)


## Lays the portraits of a look's layers over each other, scaled up pixel for pixel.
func _show_portrait(portrait: Control, look: Appearance) -> void:
	for child in portrait.get_children():
		child.queue_free()
	for portrait_layer in look.portrait_layers():
		var picture := TextureRect.new()
		picture.texture = load(ArtSet.path(Appearance.portrait_path(portrait_layer)))
		picture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		picture.set_anchors_preset(Control.PRESET_FULL_RECT)
		portrait.add_child(picture)


func _on_submitted(text: String) -> void:
	if _npc.is_answering:
		return
	_line_edit.clear()
	say(text)


func _on_input_gui_input(event: InputEvent) -> void:
	# The key that opened the chat may still be held: its repeats would type into the input.
	if _is_opening_key_held and event is InputEventKey and event.is_action("interact"):
		_is_opening_key_held = event.pressed
		_line_edit.accept_event()
		return
	if not event is InputEventKey or not event.pressed:
		return
	# A LineEdit consumes ui_cancel while editing, so Modal never sees Escape and the pause key
	# is caught here; accepting it keeps it from opening the pause menu once the game runs again.
	if event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
		close()
		_line_edit.accept_event()
		return
	if event.is_action_pressed("toggle_art_set"):
		art_set_switch_pressed.emit()
		_line_edit.accept_event()
		return
	var scroll_bar := _scroll.get_v_scroll_bar()
	match event.keycode:
		KEY_PAGEUP:
			scroll_bar.value -= scroll_bar.page
		KEY_PAGEDOWN:
			scroll_bar.value += scroll_bar.page
		_:
			return
	_line_edit.accept_event()


## The input never loses focus while the chat is open, e.g. to a click elsewhere.
func _on_input_focus_exited() -> void:
	if visible:
		_line_edit.grab_focus.call_deferred()
