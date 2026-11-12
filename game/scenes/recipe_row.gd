class_name RecipeRow
extends Button
## One recipe in the crafting menu: the icon of what it makes, its name (with the skill level it
## needs, if any, below it) and each material as carried/needed, marked when short. A recipe the
## player can't make, for want of materials or of skill, is greyed and can't be pressed; what is
## missing is marked in flame. The tooltip is that of the item it makes, plus what is missing and
## what the craft teaches.

const ROW_WIDTH := 180
const MIN_HEIGHT := 22
const GAP := 6
## Palette colour flame (see tools/art/palette.py), as in the build panel.
const SHORT_COLOR := Color("dc7a37")
const UNAFFORDABLE_ALPHA := 0.5

var recipe_id: StringName

var _crafting: Crafting
var _rules: RecipeRules
var _inventory: Inventory
var _icon := ItemIcon.new()
var _level_label := Label.new()
var _materials_label := Label.new()


func _init(id: StringName, crafting: Crafting, inventory: Inventory) -> void:
	recipe_id = id
	_crafting = crafting
	_rules = crafting.rules
	_inventory = inventory
	custom_minimum_size = Vector2(ROW_WIDTH, MIN_HEIGHT)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", GAP)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 4)
	_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_icon.show_item(_rules.result(id))
	row.add_child(_icon)
	var name_column := VBoxContainer.new()
	name_column.add_theme_constant_override("separation", 0)
	name_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_column.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	name_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var name_label := Label.new()
	name_label.text = title_of(id, _rules)
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# A long name is cut short rather than pushing the materials out of the row.
	name_label.clip_text = true
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_column.add_child(name_label)
	_level_label.text = _level_text()
	_level_label.visible = _has_level()
	_level_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_column.add_child(_level_label)
	row.add_child(name_column)
	_materials_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_materials_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_materials_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_materials_label)
	add_child(row)


func _ready() -> void:
	# The theme comes from the screen that holds the row, so it is not there yet in `_init`.
	var lines := maxi(_rules.materials(recipe_id).size(), 2 if _has_level() else 1)
	var height := lines * _materials_label.get_line_height() + 8
	custom_minimum_size.y = maxf(MIN_HEIGHT, height)
	# A disabled row keeps the look of the others, just dimmer.
	add_theme_stylebox_override("disabled", get_theme_stylebox("normal"))


## Shows what the player has against what the recipe takes and needs.
func refresh() -> void:
	var short := _crafting.shortfalls(recipe_id)
	var is_locked := _crafting.is_locked(recipe_id)
	var materials := _rules.materials(recipe_id)
	var lines: Array[String] = []
	for item: StringName in materials:
		var item_name: String = ItemTypes.TYPES[item]["name"]
		var line := "%s %d/%d" % [item_name, _inventory.count_of(item), materials[item]]
		lines.append(line + (" !" if short.has(item) else ""))
	_materials_label.text = "\n".join(lines)
	_materials_label.add_theme_color_override(
		"font_color", SHORT_COLOR if not short.is_empty() else Color.WHITE
	)
	_level_label.add_theme_color_override("font_color", SHORT_COLOR if is_locked else Color.WHITE)
	disabled = is_locked or not short.is_empty()
	modulate.a = UNAFFORDABLE_ALPHA if disabled else 1.0
	TooltipView.set_text(self, _tooltip(short, is_locked), "recipe_%s" % recipe_id)


func _tooltip(short: Dictionary, is_locked: bool) -> String:
	var tip := ItemTooltip.text_for(_rules.result(recipe_id), _rules.count(recipe_id))
	if is_locked:
		tip += "\nNeeds %s (you have %.1f)" % [_level_text(), _skill_points()]
	if not short.is_empty():
		var missing: Array[String] = []
		for item: StringName in short:
			missing.append("%d %s" % [short[item], ItemTypes.TYPES[item]["name"].to_lower()])
		tip += "\nMissing: " + ", ".join(missing)
	var skill := _rules.skill(recipe_id)
	if skill != &"" and not is_locked:
		var gain := _crafting.player_skills().gain_at(skill, _rules.level(recipe_id))
		tip += "\nTeaches %s +%.1f" % [_skill_name(), gain]
	return tip


## "Chest", or "Arrow x5" for a recipe that makes several.
static func title_of(id: StringName, rules: RecipeRules) -> String:
	var count := rules.count(id)
	return rules.name_of(id) if count == 1 else "%s x%d" % [rules.name_of(id), count]


func _has_level() -> bool:
	return _rules.level(recipe_id) > 0.0


## "Cooking 20": the skill level the recipe needs.
func _level_text() -> String:
	if _rules.skill(recipe_id) == &"":
		return ""
	return "%s %s" % [_skill_name(), ("%.1f" % _rules.level(recipe_id)).trim_suffix(".0")]


func _skill_name() -> String:
	return _crafting.player_skills().rules.skill_name(_rules.skill(recipe_id))


func _skill_points() -> float:
	return _crafting.player_skills().points(_rules.skill(recipe_id))
