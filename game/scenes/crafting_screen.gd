class_name CraftingScreen
extends CanvasLayer
## The crafting menu over the game (C): a panel with a row for every recipe (see RecipeRow). A
## click on a row the player can afford crafts it. Like the character screen, it takes the
## input while it is open (Main sees to that, and closes it on C and Escape).

const THEME := preload("res://game/scenes/ui_theme.tres")
const NO_ROOM_NOTE := "Inventory full"

var _crafting: Crafting
var _inventory: Inventory
var _backdrop := ColorRect.new()
var _panel := PanelContainer.new()
var _rows: Array[RecipeRow] = []
var _note_label := Label.new()


func _init() -> void:
	visible = false
	_backdrop.color = UiColors.BACKDROP
	_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_backdrop)
	_panel.theme = THEME
	_backdrop.add_child(_panel)


func show_crafting(crafting: Crafting, inventory: Inventory) -> void:
	_crafting = crafting
	_inventory = inventory
	var column := VBoxContainer.new()
	var title := Label.new()
	title.text = "Crafting"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)
	for recipe_id in crafting.rules.recipe_ids():
		var row := RecipeRow.new(recipe_id, crafting.rules)
		row.pressed.connect(_craft.bind(recipe_id))
		column.add_child(row)
		_rows.append(row)
	column.add_child(_note_label)
	_panel.add_child(column)
	inventory.changed.connect(_refresh)
	_refresh()


func is_open() -> bool:
	return visible


func open() -> void:
	_show(true)


## Safe to call when it is closed.
func close() -> void:
	_show(false)


func toggle() -> void:
	_show(not visible)


func _show(is_shown: bool) -> void:
	visible = is_shown
	_show_note("")
	_refresh()
	# The panel is sized round its rows, which are only measured once it is shown.
	_panel.reset_size()
	_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)


func _craft(recipe_id: StringName) -> void:
	var result := _crafting.craft(recipe_id)
	_show_note(NO_ROOM_NOTE if result == Crafting.Result.NO_ROOM else "")


func _show_note(text: String) -> void:
	_note_label.text = text
	_note_label.visible = text != ""


func _refresh() -> void:
	for row in _rows:
		row.show_stock(_inventory, _crafting.shortfalls(row.recipe_id))
