class_name VitalsHud
extends MarginContainer
## The energy and health bars, put in the hotbar's row (see HotbarHud `add_aside`) so they stay
## right of it at any UI scale. Each a 12x12 icon and a 48x8 bar (art in
## tools/art/ui.py). A bar at or below the warning level pulses.

## Gap between the hotbar and the bars.
const HOTBAR_GAP := 6
const ROW_GAP := 1
const PULSE_HZ := 1.0
const PULSE_LOW_ALPHA := 0.5

var _state: GameState
var _energy_bar := VitalBar.new(
	preload("res://assets/ui/energy_icon.png"), preload("res://assets/ui/energy_fill.png")
)
var _health_bar := VitalBar.new(
	preload("res://assets/ui/health_icon.png"), preload("res://assets/ui/health_fill.png")
)


func _init() -> void:
	add_theme_constant_override("margin_left", HOTBAR_GAP)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", ROW_GAP)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for bar in [_energy_bar, _health_bar]:
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		column.add_child(bar)
	add_child(column)


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
	_energy_bar.show_value(player.energy / PlayerState.MAX_ENERGY)
	_energy_bar.modulate.a = pulse if player.energy <= warning_level else 1.0
	_health_bar.show_value(player.health / PlayerState.MAX_HEALTH)
	_health_bar.modulate.a = pulse if player.health <= warning_level else 1.0
