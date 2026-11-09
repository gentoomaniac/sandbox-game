class_name BuildMenu
extends CanvasLayer
## While the player holds the hammer: the build menu just above the hotbar. A row of the
## buildings, each a small picture with its name and what it takes, the chosen one marked;
## above the chosen one, a column of its other styles, if it has any; and beside them a larger
## preview of the chosen style with each material it takes as carried/needed, marked when
## short, and why the spot under the ghost is refused (see `show_message`). Q and E or the
## arrows pick (see BuildMode), and so does a click. While the hammer takes down, only the
## preview's panel is up, at the top left, saying so. On its own canvas layer like the hotbar,
## so the day/night tint doesn't touch it. It is drawn anew only when what it shows changes
## (see `_process`).

const THEME := preload("res://game/scenes/ui_theme.tres")
# Palette colour (see tools/art/palette.py): what is short, and the mode that takes down.
const SHORT_COLOR := Color("dc7a37")
const TAKING_DOWN_TEXT := "Taking down (X: build)"
## A cell of the row or of a column: its width, and the box its picture is fitted into.
const CELL_WIDTH := 70
const CELL_PICTURE := Vector2(35, 23)
const PREVIEW_PICTURE := Vector2(67, 64)
const GAP := 2
## Where the panel is while the hammer takes down: out of the way of the message of what taking
## down gives, which is above the hotbar.
const TAKING_DOWN_POSITION := Vector2(4, 40)
## The row's bottom edge above the bottom of the window: just above the hotbar.
const ROW_BOTTOM := HotbarHud.BOTTOM_MARGIN + SlotView.SIZE + 3 * GAP
## The style of a building's cell in the row: its own look.
const OWN_LOOK := &""

var _builder: Builder
var _inventory: Inventory
var _row := HBoxContainer.new()
## {building: {style: cell}}: the row's cell of each building is its OWN_LOOK's.
var _cells: Dictionary[StringName, Dictionary] = {}
## The column of the other styles of each building that has any.
var _columns: Dictionary[StringName, VBoxContainer] = {}
var _preview := PanelContainer.new()
var _preview_picture := _picture(PREVIEW_PICTURE)
var _preview_name := Label.new()
var _message := Label.new()
## One per material a building can take, in the order of BuildingTypes.COST_ITEMS.
var _material_labels: Array[Label] = []
## The boxes of the cells: the theme's buttons with narrower margins, the chosen one lit like a
## button under the mouse, its name in the gold of one.
var _cell_box := _narrowed(THEME.get_stylebox("normal", "Button"))
var _chosen_box := _narrowed(THEME.get_stylebox("hover", "Button"))
var _chosen_color := THEME.get_color("font_hover_color", "Button")
## What the menu was last drawn for (see `_process`).
var _shown: Array = []


func _init() -> void:
	add_to_group(ArtSet.VIEWS)
	_row.theme = THEME
	_row.add_theme_constant_override("separation", GAP)
	_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_row)
	for building in BuildingTypes.ids():
		_cells[building] = {}
		var styles := BuildingTypes.styles(building)
		_cells[building][OWN_LOOK] = _cell(building, OWN_LOOK)
		_row.add_child(_cells[building][OWN_LOOK])
		if styles.size() == 1:
			continue
		var column := VBoxContainer.new()
		column.theme = THEME
		column.add_theme_constant_override("separation", GAP)
		column.mouse_filter = Control.MOUSE_FILTER_IGNORE
		# The first style above the row's cell, the last at the top.
		for index in range(styles.size() - 1, 0, -1):
			_cells[building][styles[index]] = _cell(building, styles[index])
			column.add_child(_cells[building][styles[index]])
		_columns[building] = column
		add_child(column)
	_build_preview()


## Binds the menu to the game, once the art set is chosen (see ArtSet).
func bind(builder: Builder, inventory: Inventory) -> void:
	_builder = builder
	_inventory = inventory
	show_art_set()


## Whether the menu shows the messages of build mode: while it picks buildings. Taking down, the
## message of what it gives is the HUD's, above the hotbar where the row would be.
func takes_messages() -> bool:
	return visible and not _builder.is_taking_down()


## Shows why the spot under the ghost is refused, or nothing for "".
func show_message(text: String) -> void:
	if text != _message.text:
		_message.text = text
		_message.visible = text != ""


## Loads the pictures of the cells in the chosen art set (see ArtSet); the preview's follows
## by itself.
func show_art_set() -> void:
	for building in _cells:
		for style: StringName in _cells[building]:
			var picture: TextureRect = _cells[building][style].get_node("Rows/Picture")
			picture.texture = load(ArtSet.path(BuildingTypes.of(building, style)["sprite"]))


## Draws the menu anew when what it shows has changed: the choice, the mode, what the player
## carries of the materials, the message, the art set, the window, or the size the containers
## need (a label that wraps grows a line only once it has been laid out).
func _process(_delta: float) -> void:
	if not visible:
		return
	var shown := [
		_builder.choice,
		_builder.style,
		_builder.is_taking_down(),
		_builder.costs().keys().map(_inventory.count_of),
		_builder.shortfalls(),
		_message.text,
		ArtSet.is_classic,
		get_viewport().get_visible_rect().size,
		_row.get_combined_minimum_size(),
		_preview.get_combined_minimum_size(),
	]
	if shown == _shown:
		return
	_shown = shown
	var is_choosing := not _builder.is_taking_down()
	_row.visible = is_choosing
	for building in _columns:
		_columns[building].visible = is_choosing and building == _builder.choice
	if is_choosing:
		_show_choice()
	else:
		_show_taking_down()
	_place_on_screen(is_choosing)


## Marks the chosen building and style and shows them in the preview with what they take.
func _show_choice() -> void:
	for building in _cells:
		for style: StringName in _cells[building]:
			var is_chosen: bool = building == _builder.choice and style == _builder.style
			var cell: PanelContainer = _cells[building][style]
			cell.add_theme_stylebox_override("panel", _chosen_box if is_chosen else _cell_box)
			var name_label: Label = cell.get_node("Rows/Name")
			if is_chosen:
				name_label.add_theme_color_override("font_color", _chosen_color)
			else:
				name_label.remove_theme_color_override("font_color")
	var entry := _builder.type_data()
	_preview_picture.visible = true
	_preview_picture.texture = load(ArtSet.path(entry["sprite"]))
	_preview_name.text = entry["name"]
	_preview_name.remove_theme_color_override("font_color")
	var costs := _builder.costs()
	var short := _builder.shortfalls()
	var items: Array = costs.keys()
	for index in _material_labels.size():
		var label := _material_labels[index]
		label.visible = index < items.size()
		if not label.visible:
			continue
		var item: StringName = items[index]
		var text := (
			"%s %d/%d" % [ItemTypes.TYPES[item]["name"], _inventory.count_of(item), costs[item]]
		)
		label.text = text + (" !" if short.has(item) else "")
		if short.has(item):
			label.add_theme_color_override("font_color", SHORT_COLOR)
		else:
			label.remove_theme_color_override("font_color")


## The mode is on the preview's panel: red "Taking down" instead of the building.
func _show_taking_down() -> void:
	_preview_picture.visible = false
	_preview_name.text = TAKING_DOWN_TEXT
	_preview_name.add_theme_color_override("font_color", SHORT_COLOR)
	for label in _material_labels:
		label.visible = false


## The row above the hotbar, the chosen building's column above its cell and the preview
## beside them, on the right unless the window ends there. Taking down, the panel sits at the
## top left.
func _place_on_screen(is_choosing: bool) -> void:
	var screen := get_viewport().get_visible_rect().size
	_row.size = Vector2.ZERO
	_row.position = Vector2(
		roundf((screen.x - _row.size.x) / 2), screen.y - ROW_BOTTOM - _row.size.y
	)
	# Shrinks round fewer rows of materials.
	_preview.size = Vector2.ZERO
	if not is_choosing:
		_preview.position = TAKING_DOWN_POSITION
		return
	var stack: Rect2 = _cells[_builder.choice][OWN_LOOK].get_global_rect()
	if _columns.has(_builder.choice):
		var column := _columns[_builder.choice]
		column.custom_minimum_size.x = stack.size.x
		column.size = Vector2.ZERO
		column.position = Vector2(stack.position.x, _row.position.y - GAP - column.size.y)
		stack = stack.merge(column.get_global_rect())
	var x := stack.end.x + GAP
	if x + _preview.size.x > screen.x:
		x = stack.position.x - GAP - _preview.size.x
	_preview.position = Vector2(x, _row.position.y - GAP - _preview.size.y)


## A cell of the menu: the picture of the building in a style and its name. What it takes shows
## only in the preview of the chosen one. A click on it picks that building and style.
func _cell(building: StringName, style: StringName) -> PanelContainer:
	var entry := BuildingTypes.of(building, style)
	var cell := PanelContainer.new()
	cell.custom_minimum_size.x = CELL_WIDTH
	cell.mouse_filter = Control.MOUSE_FILTER_STOP
	cell.gui_input.connect(_on_cell_input.bind(building, style))
	var rows := VBoxContainer.new()
	rows.name = "Rows"
	rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rows.add_theme_constant_override("separation", 1)
	var picture := _picture(CELL_PICTURE)
	picture.name = "Picture"
	rows.add_child(picture)
	var label := Label.new()
	label.name = "Name"
	label.text = entry["name"]
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rows.add_child(label)
	cell.add_child(rows)
	return cell


func _build_preview() -> void:
	_preview.theme = THEME
	_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# The theme's panel margins are meant for menus.
	var style: StyleBoxTexture = THEME.get_stylebox("panel", "PanelContainer").duplicate()
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	_preview.add_theme_stylebox_override("panel", style)
	var rows := VBoxContainer.new()
	rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rows.add_child(_preview_picture)
	rows.add_child(_preview_name)
	for _item in BuildingTypes.COST_ITEMS:
		var label := Label.new()
		rows.add_child(label)
		_material_labels.append(label)
	_message.custom_minimum_size.x = PREVIEW_PICTURE.x
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_message.add_theme_color_override("font_color", SHORT_COLOR)
	_message.visible = false
	rows.add_child(_message)
	_preview.add_child(rows)
	add_child(_preview)


static func _narrowed(box: StyleBox) -> StyleBox:
	var narrow: StyleBox = box.duplicate()
	narrow.content_margin_left = 3
	narrow.content_margin_right = 3
	return narrow


## A building's picture fitted into `box`, its bottom on the box's bottom like on the ground.
static func _picture(box: Vector2) -> TextureRect:
	var picture := TextureRect.new()
	picture.custom_minimum_size = box
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ItemIcon.sharpen(picture)
	return picture


func _on_cell_input(event: InputEvent, building: StringName, style: StringName) -> void:
	# A click on the menu is not a click on the land under it. The wheel over it still turns the
	# hotbar, and a right click still dismisses build mode.
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_builder.choose(building, style)
		get_viewport().set_input_as_handled()
