class_name ProcessRecipeRow
extends VBoxContainer
## One recipe in a process station's window (ProcessScreen): a button with the icon of what one
## load makes, its name (with the skill level it needs, if any) and each material as what the
## player has, carried and in the grid, against what the amount takes; under it the amount, in
## loads: a number to type, - and +, and Max. Pressing the button asks to fill the grid to that
## amount (`fill_requested`). The amount stays within what ProcessStation `amounts` allows; a
## recipe it can't fill (locked, ruled out by the grid, or short of materials for one load) is
## greyed and can't be pressed.

signal fill_requested(amount: int)
## A key that closes the window was pressed in the amount field, which would keep it (a text field
## takes Escape): `action` is `ui_cancel`, `pause` or `interact`.
signal close_key_pressed(action: StringName)

const CLOSE_ACTIONS: Array[StringName] = [&"ui_cancel", &"pause", &"interact"]

const ROW_WIDTH := 180
const GAP := 6
const AMOUNT_WIDTH := 28
const UNAFFORDABLE_ALPHA := 0.5

var recipe_id: StringName

var _rules: RecipeRules
var _station: ProcessStation
var _skills: Skills
var _button := Button.new()
## What the button shows: the icon, the name and level, and the materials.
var _content := HBoxContainer.new()
var _level_label := Label.new()
var _materials_label := Label.new()
var _minus := Button.new()
var _amount_field := LineEdit.new()
var _plus := Button.new()
var _max := Button.new()
var _amount := 1
## The fewest and most loads (see ProcessStation `amounts`), and whether a press can fill at all.
var _limits := Vector2i(1, 1)
var _can_fill := false
var _available := {}


func _init(id: StringName, station: ProcessStation, rules: RecipeRules, skills: Skills) -> void:
	recipe_id = id
	_station = station
	_rules = rules
	_skills = skills
	add_theme_constant_override("separation", 1)

	_button.custom_minimum_size = Vector2(ROW_WIDTH, RecipeRow.MIN_HEIGHT)
	var row := _content
	row.add_theme_constant_override("separation", GAP)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 4)
	var icon := ItemIcon.new()
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.show_item(rules.result(id))
	row.add_child(icon)
	var name_column := VBoxContainer.new()
	name_column.add_theme_constant_override("separation", 0)
	name_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_column.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	name_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var name_label := Label.new()
	name_label.text = RecipeRow.title_of(id, rules)
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_column.add_child(name_label)
	_level_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_level_label.visible = rules.level(id) > 0.0
	_level_label.text = "%s %s" % [_skill_name(), ("%.1f" % rules.level(id)).trim_suffix(".0")]
	name_column.add_child(_level_label)
	row.add_child(name_column)
	_materials_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_materials_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_materials_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_materials_label)
	_button.add_child(row)
	_button.pressed.connect(func() -> void: fill_requested.emit(_amount))
	add_child(_button)

	var amount_row := HBoxContainer.new()
	amount_row.alignment = BoxContainer.ALIGNMENT_END
	_minus.text = "-"
	_minus.pressed.connect(func() -> void: _set_amount(_amount - 1))
	_plus.text = "+"
	_plus.pressed.connect(func() -> void: _set_amount(_amount + 1))
	_max.text = "Max"
	_max.pressed.connect(func() -> void: _set_amount(_limits.y))
	_amount_field.custom_minimum_size.x = AMOUNT_WIDTH
	_amount_field.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_amount_field.text_submitted.connect(
		func(_text: String) -> void:
			_take_typed_amount()
			_amount_field.release_focus()
	)
	_amount_field.gui_input.connect(_on_amount_input)
	_amount_field.focus_exited.connect(_take_typed_amount)
	for control: Control in [_minus, _amount_field, _plus, _max]:
		amount_row.add_child(control)
	add_child(amount_row)


func _ready() -> void:
	# The theme comes from the window that holds the row, so it is not there yet in `_init`.
	_button.add_theme_stylebox_override("disabled", _button.get_theme_stylebox("normal"))


## The loads a press fills the grid to.
func amount() -> int:
	return _amount


## Shows the recipe as it stands: `available` (item id to count) is what the player has for it,
## carried and in the grid.
func refresh(available: Dictionary) -> void:
	_available = available
	_can_fill = _station.can_fill(recipe_id)
	_limits = _station.amounts(recipe_id)
	var is_locked := _station.is_locked(recipe_id)
	_level_label.add_theme_color_override(
		"font_color", RecipeRow.SHORT_COLOR if is_locked else Color.WHITE
	)
	_button.disabled = not _can_fill
	modulate.a = 1.0 if _can_fill else UNAFFORDABLE_ALPHA
	TooltipView.set_text(_button, _tooltip(is_locked), "recipe_%s" % recipe_id)
	_set_amount(_amount)


func _tooltip(is_locked: bool) -> String:
	var tip := ItemTooltip.text_for(_rules.result(recipe_id), _rules.count(recipe_id))
	tip += "\nA run takes %s hours" % ("%.1f" % _rules.hours(recipe_id)).trim_suffix(".0")
	var skill := _rules.skill(recipe_id)
	if is_locked:
		tip += "\nNeeds %s (you have %.1f)" % [_level_label.text, _skills.points(skill)]
	elif not _station.is_open(recipe_id):
		tip += "\n" + "What is in the grid is not for this"
	elif _limits.y < _limits.x:
		tip += "\nNot enough for a load"
	if skill != &"" and not is_locked:
		var level := _rules.practice_level(recipe_id, _skills.points(skill))
		tip += "\nTeaches %s +%.1f" % [_skill_name(), _skills.gain_at(skill, level)]
	return tip


## Sets the amount, held to the limits, and shows what it takes.
func _set_amount(wanted: int) -> void:
	_amount = clampi(wanted, _limits.x, maxi(_limits.x, _limits.y))
	_amount_field.text = str(_amount)
	_amount_field.editable = _can_fill
	_minus.disabled = not _can_fill or _amount <= _limits.x
	_plus.disabled = not _can_fill or _amount >= _limits.y
	_max.disabled = _plus.disabled
	var materials := _rules.materials(recipe_id)
	var lines: Array[String] = []
	for item: StringName in materials:
		var item_name: String = ItemTypes.TYPES[item]["name"]
		var needed: int = _amount * materials[item]
		lines.append("%s %d/%d" % [item_name, _available.get(item, 0), needed])
	_materials_label.text = "\n".join(lines)
	# The button grows round its content, which is drawn over it rather than laid out by it.
	_button.custom_minimum_size.y = maxf(
		RecipeRow.MIN_HEIGHT, _content.get_combined_minimum_size().y + 8
	)


## Takes the keys that close the window before the field does, with the amount typed so far.
func _on_amount_input(event: InputEvent) -> void:
	for action in CLOSE_ACTIONS:
		if event.is_action_pressed(action):
			_amount_field.accept_event()
			_take_typed_amount()
			_amount_field.release_focus()
			close_key_pressed.emit(action)
			return


## A typed number is held to the limits too; anything but a number keeps the amount.
func _take_typed_amount() -> void:
	var typed := _amount_field.text.strip_edges()
	_set_amount(int(typed) if typed.is_valid_int() else _amount)


func _skill_name() -> String:
	return _skills.rules.skill_name(_rules.skill(recipe_id))
