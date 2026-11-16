class_name QuestsPanel
extends VBoxContainer
## The quests tab of the character window: the quests the player has taken, the oldest first (see
## QuestRows): who gave each, what it asks, how far they are and the days left; the reward is its
## tooltip. It is read-only: a quest is handed in to the villager. The counts follow the bag and the
## world while the tab is open. The title stays in place and the rows scroll in `list`, when there
## are more than the window has room for.

const PANEL_WIDTH := 260
const ROW_GAP := 6
## How often the rows are worked out again while the tab is open, in seconds: counting what a
## build quest asks for looks through the objects the player put down.
const REFRESH_SECONDS := 0.25
const EMPTY_TEXT := "No open quests."
const TITLE_TEXT := "Open quests (%d)"
## Palette colour gold (see tools/art/palette.py), for the title.
const TITLE_COLOR := UiColors.GOLD

## The rows' list: the character window fits it and starts it at the top when the tab is shown.
var list: ScrollingList

var _state: GameState
var _rows_shown: Array[Dictionary] = []
var _seconds_since_refresh := 0.0
var _title := Label.new()
var _rows := VBoxContainer.new()


func _init() -> void:
	add_theme_constant_override("separation", ROW_GAP)
	_rows.add_theme_constant_override("separation", ROW_GAP)
	custom_minimum_size.x = PANEL_WIDTH
	_title.add_theme_color_override("font_color", TITLE_COLOR)
	add_child(_title)
	list = ScrollingList.new(_rows)
	add_child(list)


## Shows the quests of the game of `state`; showing another game lets go of the old one.
func show_quests(state: GameState) -> void:
	_state = state
	refresh()


## Works out the rows again and draws them if they changed.
func refresh() -> void:
	_seconds_since_refresh = 0.0
	if _state == null:
		return
	var rows := QuestRows.of(_state)
	if rows != _rows_shown or _rows.get_child_count() == 0:
		_rows_shown = rows
		_draw_rows(rows)


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_seconds_since_refresh += delta
	if _seconds_since_refresh >= REFRESH_SECONDS:
		refresh()


func _draw_rows(rows: Array[Dictionary]) -> void:
	for child in _rows.get_children():
		# Out of the tree first, so nothing counts it while it is freed.
		_rows.remove_child(child)
		child.free()
	_title.text = TITLE_TEXT % rows.size()
	if rows.is_empty():
		_rows.add_child(_label(EMPTY_TEXT))
	for row in rows:
		_rows.add_child(_row(row))


## The row is what the mouse is over, whatever part of it, as it carries the tooltip.
func _row(row: Dictionary) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_PASS
	box.add_child(_label(row["giver"]))
	var what := _label("  %s: %s, %s" % [row["what"], row["progress"], row["days_left"]])
	box.add_child(what)
	TooltipView.set_text(box, row["reward"], "quest_reward")
	return box


func _label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x = PANEL_WIDTH
	return label
