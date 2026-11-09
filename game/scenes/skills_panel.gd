class_name SkillsPanel
extends VBoxContainer
## The skills tab of the character screen: a row per skill with its points as a number and as a
## bar up to the cap of one skill, and a Fade button that marks it to fade (it then reads
## "Fading"); below them the total against the total cap, and the rule of the cap (see Skills).

const NAME_WIDTH := 64
const BAR_SIZE := Vector2(96, 6)
const POINTS_WIDTH := 28
## Wide enough for "Fading", so the rows stay aligned.
const FADE_WIDTH := 48
const ROW_GAP := 6
## Palette colours ink (the empty bar), gold (the points) and flame (the total at its cap), see
## tools/art/palette.py.
const BAR_BACK := Color("1d1b26")
const BAR_FILL := Color("eec25a")
const AT_CAP_COLOR := Color("dc7a37")
const RULE_WIDTH := 240
const RULE_TEXT := (
	"Your skills together reach at most %d points. There, a skill only grows by taking points"
	+ " from one you let fade."
)
const FADE_TIP := (
	"Fade: at the total cap, the other skills grow by taking points from this one. Nothing fades"
	+ " while you are below the cap."
)

var _skills: Skills
## Skill id -> its bar, points label and fade button.
var _bars := {}
var _points_labels := {}
var _fade_buttons := {}
var _total_label := Label.new()


## The rows are made for the first skills shown; showing others lets go of the old ones.
func show_skills(skills: Skills) -> void:
	if _skills == null:
		_add_rows(skills.rules)
	else:
		_skills.changed.disconnect(_refresh)
	_skills = skills
	skills.changed.connect(_refresh)
	_refresh()


func _add_rows(rules: SkillRules) -> void:
	add_theme_constant_override("separation", ROW_GAP)
	for skill in rules.skill_ids():
		add_child(_skill_row(skill, rules))
	add_child(_total_label)
	var rule := Label.new()
	rule.text = RULE_TEXT % roundi(rules.total_cap())
	rule.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rule.custom_minimum_size.x = RULE_WIDTH
	add_child(rule)


func _skill_row(skill: StringName, rules: SkillRules) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", ROW_GAP)
	var name_label := Label.new()
	name_label.text = rules.skill_name(skill)
	name_label.custom_minimum_size.x = NAME_WIDTH
	name_label.mouse_filter = Control.MOUSE_FILTER_PASS
	TooltipView.set_text(name_label, rules.description(skill), "skill_%s" % skill)
	row.add_child(name_label)
	var bar := Control.new()
	bar.custom_minimum_size = BAR_SIZE
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.draw.connect(_draw_bar.bind(bar, skill))
	row.add_child(bar)
	_bars[skill] = bar
	var points_label := Label.new()
	points_label.custom_minimum_size.x = POINTS_WIDTH
	points_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(points_label)
	_points_labels[skill] = points_label
	var fade := Button.new()
	fade.toggle_mode = true
	fade.custom_minimum_size.x = FADE_WIDTH
	fade.toggled.connect(func(is_on: bool) -> void: _skills.set_fading(skill, is_on))
	TooltipView.set_text(fade, FADE_TIP, "fade_%s" % skill)
	row.add_child(fade)
	_fade_buttons[skill] = fade
	return row


func _draw_bar(bar: Control, skill: StringName) -> void:
	bar.draw_rect(Rect2(Vector2.ZERO, bar.size), BAR_BACK)
	var share := _skills.points(skill) / _skills.rules.skill_cap()
	bar.draw_rect(Rect2(Vector2.ZERO, Vector2(roundf(bar.size.x * share), bar.size.y)), BAR_FILL)


func _refresh() -> void:
	for skill: StringName in _bars:
		_bars[skill].queue_redraw()
		_points_labels[skill].text = "%.1f" % _skills.points(skill)
		var fade: Button = _fade_buttons[skill]
		fade.set_pressed_no_signal(_skills.is_fading(skill))
		fade.text = "Fading" if fade.button_pressed else "Fade"
	var total_cap := _skills.rules.total_cap()
	_total_label.text = "Total %.1f / %d" % [_skills.total(), roundi(total_cap)]
	var is_at_cap := _skills.total() >= total_cap
	_total_label.add_theme_color_override("font_color", AT_CAP_COLOR if is_at_cap else Color.WHITE)
