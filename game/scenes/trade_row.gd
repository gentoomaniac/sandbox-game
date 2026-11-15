class_name TradeRow
extends HBoxContainer
## One good in the trade screen (see TradeScreen): its icon, its name with what the price or value
## and what is left say under it, and a count to change with [-] and [+]. A good that can't be
## traded now, for want of stock, of room or of the item in the bag, is greyed.

## The player pressed [-] or [+]: -1 or 1.
signal stepped(delta: int)

const WIDTH := 190
const GAP := 4
const GREY_ALPHA := 0.5

var item: StringName

var _detail_label := Label.new()
var _count_label := Label.new()
var _minus := Button.new()
var _plus := Button.new()


func _init(good: StringName) -> void:
	item = good
	add_theme_constant_override("separation", GAP)
	custom_minimum_size.x = WIDTH
	var icon := ItemIcon.new()
	icon.show_item(good)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	add_child(icon)
	var text_column := VBoxContainer.new()
	text_column.add_theme_constant_override("separation", 0)
	text_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var name_label := Label.new()
	name_label.text = ItemTypes.TYPES[good]["name"]
	name_label.clip_text = true
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	text_column.add_child(name_label)
	text_column.add_child(_detail_label)
	add_child(text_column)
	_minus.text = "-"
	_plus.text = "+"
	for button: Button in [_minus, _plus]:
		# Space is the game's use key: a focused button would take it.
		button.focus_mode = Control.FOCUS_NONE
		button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_minus.pressed.connect(stepped.emit.bind(-1))
	_plus.pressed.connect(stepped.emit.bind(1))
	_count_label.custom_minimum_size.x = 20
	_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_minus)
	add_child(_count_label)
	add_child(_plus)
	TooltipView.set_text(self, ItemTooltip.text_for(good, 1), "trade_%s" % good)


## Shows the line under the name, the count, and whether the count can go up or down.
func show_state(detail: String, count: int, can_add: bool, is_grey: bool) -> void:
	_detail_label.text = detail
	_count_label.text = str(count)
	_minus.disabled = count == 0
	_plus.disabled = not can_add
	modulate.a = GREY_ALPHA if is_grey else 1.0
