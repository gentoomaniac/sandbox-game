class_name VitalsHud
extends CanvasLayer
## The energy and health bars, right of the hotbar and level with its bottom. Each is a 12x12
## icon and a 48x8 bar (art in tools/art/ui.py). A bar at or below the warning level pulses.

## Gap between the hotbar and the bars.
const HOTBAR_GAP := 6
const ROW_GAP := 1
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
	# Anchored to the same bottom centre as the hotbar, so it follows the UI scale with it.
	_column.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)


func show_state(state: GameState) -> void:
	_state = state
	get_viewport().size_changed.connect(_place)
	_place()


## Beside the hotbar if the window is wide enough for it (the hotbar stays centred), else
## above its right end, so the bars never run off the screen.
func _place() -> void:
	var size := _column.get_combined_minimum_size()
	var half_window := get_viewport().get_visible_rect().size.x / 2.0
	var is_beside := HotbarHud.WIDTH / 2.0 + HOTBAR_GAP + size.x <= half_window
	if is_beside:
		_column.offset_left = HotbarHud.WIDTH / 2.0 + HOTBAR_GAP
		_column.offset_bottom = -HotbarHud.BOTTOM_MARGIN
	else:
		_column.offset_left = HotbarHud.WIDTH / 2.0 - size.x
		_column.offset_bottom = -HotbarHud.BOTTOM_MARGIN - SlotView.SIZE - HOTBAR_GAP
	_column.offset_right = _column.offset_left + size.x
	_column.offset_top = _column.offset_bottom - size.y


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
	_energy_bar.show_value(player.energy / PlayerState.MAX_ENERGY)
	_energy_bar.modulate.a = pulse if player.energy <= warning_level else 1.0
	_health_bar.show_value(player.health / PlayerState.MAX_HEALTH)
	_health_bar.modulate.a = pulse if player.health <= warning_level else 1.0
