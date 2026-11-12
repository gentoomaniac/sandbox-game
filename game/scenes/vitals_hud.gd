class_name VitalsHud
extends CanvasLayer
## The energy and health bars in the top right corner, one above the other. Each is a 12x12
## icon and a 48x8 bar (art in tools/art/ui.py). A bar at or below the warning level pulses.

## Gap to the top and right edges of the window, as the clock has on the left.
const MARGIN := 4
const ROW_GAP := 1
const BAR_COUNT := 2
## Where the bars end, for what sits below them (the coordinates). A test checks it against the
## column's real size, so a bar added without raising BAR_COUNT fails there.
const BOTTOM := MARGIN + BAR_COUNT * VitalBar.ICON_SIZE + (BAR_COUNT - 1) * ROW_GAP
const PULSE_HZ := 1.0
const PULSE_LOW_ALPHA := 0.5

var _state: GameState
var _column := VBoxContainer.new()
var _energy_bar := VitalBar.new(
	preload("res://assets/ui/energy_icon.png"), preload("res://assets/ui/energy_fill.png")
)
var _health_bar := VitalBar.new(
	preload("res://assets/ui/health_icon.png"), preload("res://assets/ui/health_fill.png")
)


func _init() -> void:
	_column.add_theme_constant_override("separation", ROW_GAP)
	_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for bar in [_energy_bar, _health_bar]:
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_column.add_child(bar)
	add_child(_column)


func _ready() -> void:
	# Anchored to the top right, so it follows the window and the UI scale, and growing to the
	# left, so a wider row keeps the right edge. Placed in the tree: the row gap, and with it the
	# column's height, is only known once the theme override applies.
	var size := _column.get_combined_minimum_size()
	_column.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_column.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_column.offset_right = -MARGIN
	_column.offset_left = -MARGIN - size.x
	_column.offset_top = MARGIN
	_column.offset_bottom = MARGIN + size.y


func show_state(state: GameState) -> void:
	_state = state


func _process(_delta: float) -> void:
	var player := _state.player
	var warning_level := _state.energy_rules.warning_level()
	var pulse := (
		PULSE_LOW_ALPHA
		+ (
			(1.0 - PULSE_LOW_ALPHA)
			* (0.5 + 0.5 * cos(Time.get_ticks_msec() / 1000.0 * TAU * PULSE_HZ))
		)
	)
	_energy_bar.show_value(player.energy / player.attributes.max_energy())
	_energy_bar.modulate.a = pulse if player.energy <= warning_level else 1.0
	_health_bar.show_value(player.health / player.attributes.max_health())
	_health_bar.modulate.a = pulse if player.health <= warning_level else 1.0
