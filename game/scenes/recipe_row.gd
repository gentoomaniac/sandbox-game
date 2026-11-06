class_name RecipeRow
extends Button
## One recipe in the crafting menu: the icon of what it makes, its name and each material as
## carried/needed, marked when short. A recipe the player can't afford is greyed and can't be
## pressed. The row has a tooltip of the item it makes, and what is missing.

const ROW_WIDTH := 150
const MIN_HEIGHT := 22
const LINE_HEIGHT := 10
const ICON_SIZE := 16
const GAP := 6
## Palette colour flame (see tools/art/palette.py), as in the build panel.
const SHORT_COLOR := Color("dc7a37")
const UNAFFORDABLE_ALPHA := 0.5

var recipe_id: StringName

var _rules: RecipeRules
var _materials_label := Label.new()


func _init(id: StringName, rules: RecipeRules) -> void:
	recipe_id = id
	_rules = rules
	var materials := rules.materials(id)
	custom_minimum_size = Vector2(ROW_WIDTH, maxi(MIN_HEIGHT, materials.size() * LINE_HEIGHT + 8))

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", GAP)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 4)
	var icon := TextureRect.new()
	icon.texture = load(ItemTypes.icon_path(rules.result(id)))
	icon.custom_minimum_size = Vector2(ICON_SIZE, ICON_SIZE)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(icon)
	var name_label := Label.new()
	name_label.text = _title()
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(name_label)
	_materials_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_materials_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_materials_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_materials_label)
	add_child(row)


func _ready() -> void:
	# A disabled row keeps the look of the others, just dimmer. The theme comes from the screen
	# that holds the row, so it is not there yet in `_init`.
	add_theme_stylebox_override("disabled", get_theme_stylebox("normal"))


## Shows what the player has against what the recipe takes. `short` is what they lack, item id to
## the count short (empty if they can craft it).
func show_stock(inventory: Inventory, short: Dictionary) -> void:
	var materials := _rules.materials(recipe_id)
	var lines: Array[String] = []
	for item: StringName in materials:
		var item_name: String = ItemTypes.TYPES[item]["name"]
		var line := "%s %d/%d" % [item_name, inventory.count_of(item), materials[item]]
		lines.append(line + (" !" if short.has(item) else ""))
	_materials_label.text = "\n".join(lines)
	_materials_label.add_theme_color_override(
		"font_color", SHORT_COLOR if not short.is_empty() else Color.WHITE
	)
	disabled = not short.is_empty()
	modulate.a = UNAFFORDABLE_ALPHA if disabled else 1.0
	var tip := ItemTooltip.text_for(_rules.result(recipe_id), _rules.count(recipe_id))
	if not short.is_empty():
		var missing: Array[String] = []
		for item: StringName in short:
			missing.append("%d %s" % [short[item], ItemTypes.TYPES[item]["name"].to_lower()])
		tip += "\nMissing: " + ", ".join(missing)
	TooltipView.set_text(self, tip, "recipe_%s" % recipe_id)


## "Chest", or "Arrow x5" for a recipe that makes several.
func _title() -> String:
	var item_name: String = ItemTypes.TYPES[_rules.result(recipe_id)]["name"]
	var count := _rules.count(recipe_id)
	return item_name if count == 1 else "%s x%d" % [item_name, count]
