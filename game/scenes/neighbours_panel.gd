class_name NeighboursPanel
extends VBoxContainer
## The neighbours tab of the character window: a row for each villager (see NeighbourRows) with
## their portrait, their name, the name of their level and the ten marks of it (FriendshipMarks);
## the tooltip of a row says what the next level brings, so the player knows what to work for. The
## points are never shown. Read-only. The rows follow the game while the tab is open.

const PANEL_WIDTH := 260
const ROW_GAP := 6
const PORTRAIT_SIZE := 32
const PORTRAIT_GROUND := Color("4f4436")
const REFRESH_SECONDS := 0.25
const EMPTY_TEXT := "No neighbours yet."
const TITLE_TEXT := "Neighbours (%d)"
## Palette colour gold (see tools/art/palette.py), for the title.
const TITLE_COLOR := Color("eec25a")

var _state: GameState
var _rows_shown: Array[Dictionary] = []
var _seconds_since_refresh := 0.0


func _init() -> void:
	add_theme_constant_override("separation", ROW_GAP)
	custom_minimum_size.x = PANEL_WIDTH


## Shows the villagers of the game of `state`; showing another game lets go of the old one.
func show_neighbours(state: GameState) -> void:
	_state = state
	refresh()


## Works out the rows again and draws them if they changed.
func refresh() -> void:
	_seconds_since_refresh = 0.0
	if _state == null:
		return
	var rows := NeighbourRows.of(_state)
	if rows != _rows_shown or get_child_count() == 0:
		_rows_shown = rows
		_draw_rows(rows)


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_seconds_since_refresh += delta
	if _seconds_since_refresh >= REFRESH_SECONDS:
		refresh()


func _draw_rows(rows: Array[Dictionary]) -> void:
	for child in get_children():
		# Out of the tree first, so nothing counts it while it is freed.
		remove_child(child)
		child.free()
	var title := Label.new()
	title.text = TITLE_TEXT % rows.size()
	title.add_theme_color_override("font_color", TITLE_COLOR)
	add_child(title)
	if rows.is_empty():
		var empty := Label.new()
		empty.text = EMPTY_TEXT
		add_child(empty)
	for row in rows:
		add_child(_row(row))


## The row is what the mouse is over, whatever part of it, as it carries the tooltip.
func _row(row: Dictionary) -> HBoxContainer:
	var box := HBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_PASS
	box.add_theme_constant_override("separation", ROW_GAP)
	box.add_child(_portrait(row["look"]))
	var text := VBoxContainer.new()
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var name_label := Label.new()
	name_label.text = row["name"]
	text.add_child(name_label)
	var level_label := Label.new()
	level_label.text = row["level_name"]
	text.add_child(level_label)
	var marks := FriendshipMarks.new()
	marks.level = row["level"]
	marks.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.add_child(marks)
	box.add_child(text)
	TooltipView.set_text(box, row["next"], "neighbour_next")
	return box


## The head of the look, as in the chat window.
func _portrait(look: Appearance) -> Control:
	var ground := ColorRect.new()
	ground.color = PORTRAIT_GROUND
	ground.custom_minimum_size = Vector2(PORTRAIT_SIZE, PORTRAIT_SIZE)
	ground.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for portrait_layer in look.portrait_layers():
		var picture := TextureRect.new()
		picture.texture = load(ArtSet.path(Appearance.portrait_path(portrait_layer)))
		picture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		picture.set_anchors_preset(Control.PRESET_FULL_RECT)
		picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ground.add_child(picture)
	return ground
