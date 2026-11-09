class_name BuildPanel
extends CanvasLayer
## While the player holds the hammer: a small panel at the left edge with the chosen
## building's name and each material it takes as carried/needed, marked when short. On its
## own canvas layer like the clock, so the day/night tint doesn't touch it.

const POSITION := Vector2(4, 40)
const THEME := preload("res://game/scenes/ui_theme.tres")
# Palette colour (see tools/art/palette.py): what is short, and the mode that takes down.
const SHORT_COLOR := Color("dc7a37")
const TAKING_DOWN_TEXT := "Taking down (X: build)"

var _builder: Builder
var _inventory: Inventory
var _panel := PanelContainer.new()
var _name_label := Label.new()
## One per material a building can take, in the order of BuildingTypes.COST_ITEMS.
var _material_labels: Array[Label] = []


func _init() -> void:
	_panel.theme = THEME
	_panel.position = POSITION
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# The theme's panel margins are meant for menus.
	var style: StyleBoxTexture = THEME.get_stylebox("panel", "PanelContainer").duplicate()
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	_panel.add_theme_stylebox_override("panel", style)
	var rows := VBoxContainer.new()
	rows.add_child(_name_label)
	for _item in BuildingTypes.COST_ITEMS:
		var label := Label.new()
		rows.add_child(label)
		_material_labels.append(label)
	_panel.add_child(rows)
	add_child(_panel)


func bind(builder: Builder, inventory: Inventory) -> void:
	_builder = builder
	_inventory = inventory


func _process(_delta: float) -> void:
	if not visible:
		return
	if _builder.is_taking_down():
		_show_taking_down()
		return
	_name_label.remove_theme_color_override("font_color")
	var costs := _builder.costs()
	var short := _builder.shortfalls()
	_name_label.text = _builder.type_data()["name"]
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
	# Shrinks back round fewer rows.
	_panel.size = Vector2.ZERO


## The mode is on the panel: red "Taking down" instead of the building and its materials.
func _show_taking_down() -> void:
	_name_label.text = TAKING_DOWN_TEXT
	_name_label.add_theme_color_override("font_color", SHORT_COLOR)
	for label in _material_labels:
		label.visible = false
	_panel.size = Vector2.ZERO
