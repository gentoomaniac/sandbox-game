extends GutTest
## The flash of lightning: it tells its strike to the listeners, a near one is bright at once and
## a far one is a glow that swells.

var _view: WeatherView
var _rules := WeatherRules.default_rules()


func before_each() -> void:
	_view = WeatherView.new()
	add_child_autofree(_view)


func test_the_flash_tells_its_strike() -> void:
	watch_signals(_view)
	var strike := LightningStrike.new(2.0, _rules)
	_view.flash(strike)
	assert_signal_emitted_with_parameters(_view, "flashed", [strike])


func test_a_near_flash_is_at_its_peak_at_once() -> void:
	var strike := LightningStrike.new(0.2, _rules)
	_view.flash(strike)
	assert_almost_eq(_view._flash.color.a, strike.flash_peak(), 0.001)


func test_a_far_flash_swells_from_nothing_to_a_faint_glow() -> void:
	var strike := LightningStrike.new(10.0, _rules)
	_view.flash(strike)
	assert_eq(_view._flash.color.a, 0.0)
	await wait_seconds(0.25)
	assert_gt(_view._flash.color.a, 0.0)
	assert_lt(_view._flash.color.a, LightningStrike.new(0.2, _rules).flash_peak() / 2.0)
