class_name AttributesPanel
extends HBoxContainer
## The attributes on the character tab: a row per attribute with its value (a bonus shows beside
## the level, "12 (+2)"), and beside them what the attributes give: the most energy, the most
## health and the weight carried before it tires (see Attributes).

const NAME_WIDTH := 56
const VALUE_WIDTH := 44
const DERIVED_NAME_WIDTH := 80
const DERIVED_VALUE_WIDTH := 44
const COLUMN_GAP := 24
const ROW_GAP := 2

var _attributes: Attributes
## Attribute id -> its value label.
var _value_labels := {}
var _max_energy_label := Label.new()
var _max_health_label := Label.new()
var _carry_capacity_label := Label.new()


## The rows are made for the first attributes shown; showing others lets go of the old ones.
func show_attributes(attributes: Attributes) -> void:
	if _attributes == null:
		_add_rows(attributes.rules)
	else:
		_attributes.changed.disconnect(_refresh)
	_attributes = attributes
	attributes.changed.connect(_refresh)
	_refresh()


func _add_rows(rules: AttributeRules) -> void:
	add_theme_constant_override("separation", COLUMN_GAP)
	var levels := _grid()
	for attribute in rules.attribute_ids():
		var name_label := _label(rules.attribute_name(attribute), NAME_WIDTH)
		name_label.mouse_filter = Control.MOUSE_FILTER_PASS
		TooltipView.set_text(name_label, rules.description(attribute), "attribute_%s" % attribute)
		levels.add_child(name_label)
		var value_label := _label("", VALUE_WIDTH)
		value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		levels.add_child(value_label)
		_value_labels[attribute] = value_label
	add_child(levels)
	var derived := _grid()
	for row: Array in [
		["Max energy", _max_energy_label],
		["Max health", _max_health_label],
		["Carry capacity", _carry_capacity_label],
	]:
		derived.add_child(_label(row[0], DERIVED_NAME_WIDTH))
		var value_label: Label = row[1]
		value_label.custom_minimum_size.x = DERIVED_VALUE_WIDTH
		value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		derived.add_child(value_label)
	add_child(derived)


func _grid() -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("v_separation", ROW_GAP)
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return grid


func _label(text: String, width: int) -> Label:
	var label := Label.new()
	label.text = text
	label.custom_minimum_size.x = width
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _refresh() -> void:
	for attribute: StringName in _value_labels:
		var text := str(_attributes.level(attribute))
		var bonus := _attributes.bonus(attribute)
		if bonus != 0:
			text += " (%+d)" % bonus
		_value_labels[attribute].text = text
	_max_energy_label.text = Attributes.number_text(_attributes.max_energy())
	_max_health_label.text = Attributes.number_text(_attributes.max_health())
	_carry_capacity_label.text = "%s kg" % Attributes.number_text(_attributes.carry_capacity())
