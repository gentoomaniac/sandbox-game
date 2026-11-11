class_name DayNightTint
extends CanvasModulate
## Colours the world canvas by time of day, by the stops of data/lighting.cfg (see
## LightingRules). Dawn comes with the sunrise and dusk with the sunset of the day (see Sun), and
## cloud cover dims and greys the day a little.

## Lights fade out as the tint gets brighter: full strength once the tint's darkness
## (1 - luminance) times this is 1, in the late dusk, before full night.
const LIGHT_STRENGTH_PER_DARKNESS := 2.0

## Inside there is no day and night: a fixed warm tint, as from lamps and a hearth.
const INTERIOR_TINT := Color(1.0, 0.9, 0.78)

## Overcast skies darken the day tint by this much at most, and take this much of its colour.
const OVERCAST_DARKENING := 0.18
const OVERCAST_GREYING := 0.3

## Where the sun is, for the hours of dawn and dusk.
var sun := Sun.new()
var rules := LightingRules.default_rules()

## The stops of the tint around one day as [hours from the start of the day, colour], from
## the evening of the day before to the morning of the day after.
var _stops: Array = []
var _stops_day := -1
var _stops_variation := -1.0


func show_time(clock: GameClock, cloud_cover := 0.0) -> void:
	if clock.day != _stops_day or sun.variation != _stops_variation:
		_build_stops(clock.day)
	var hour := float(clock.minute_of_day) / GameClock.MINUTES_PER_HOUR
	var tint := _sample_stops(hour)
	# Clouds dim the day, not the night: the more the tint is lighter than the night's.
	var night_luminance := rules.tint_colour("night").get_luminance()
	var daylight := clampf(
		(tint.get_luminance() - night_luminance) / (1.0 - night_luminance), 0.0, 1.0
	)
	var overcast := cloud_cover * daylight
	var grey := Color(tint.get_luminance(), tint.get_luminance(), tint.get_luminance())
	tint = tint.lerp(grey, OVERCAST_GREYING * overcast)
	var brightness := 1.0 - OVERCAST_DARKENING * overcast
	color = Color(tint.r * brightness, tint.g * brightness, tint.b * brightness)


func show_interior() -> void:
	color = INTERIOR_TINT


## How much light sources should shine now: 0 in full daylight, 1 once the tint is as dark as
## night.
func light_strength() -> float:
	return clampf((1.0 - color.get_luminance()) * LIGHT_STRENGTH_PER_DARKNESS, 0.0, 1.0)


## The stops for yesterday evening, today and tomorrow morning: the evening's stops belong to
## the day before, so that the tint doesn't jump at midnight.
func _build_stops(day: int) -> void:
	_stops_day = day
	_stops_variation = sun.variation
	_stops.clear()
	var night := rules.tint_colour("night")
	var day_tint := rules.tint_colour("day")
	var ramps := rules.tint_hours("night_before_sunrise") + rules.tint_hours("night_after_sunset")
	for day_offset in [-1, 0, 1]:
		var sunrise := sun.sunrise(day + day_offset) / GameClock.MINUTES_PER_HOUR
		var sunset := sun.sunset(day + day_offset) / GameClock.MINUTES_PER_HOUR
		var shift: float = day_offset * 24.0
		# Dawn and dusk ramps shrink together until a night of min_night_hours is left.
		var night_hours := 24.0 - (sunset - sunrise)
		var squeeze := minf(1.0, (night_hours - rules.tint_hours("min_night_hours")) / ramps)
		var before_sunrise := rules.tint_hours("night_before_sunrise") * squeeze
		_stops.append([shift + sunrise - before_sunrise, night])
		_stops.append([shift + sunrise, rules.tint_colour("dawn")])
		_stops.append([shift + sunrise + rules.tint_hours("day_after_sunrise"), day_tint])
		_stops.append([shift + sunset - rules.tint_hours("day_before_sunset"), day_tint])
		for stop: Array in [
			["glow_after_sunset", "dusk_glow"],
			["purple_after_sunset", "dusk_purple"],
			["night_after_sunset", "night"],
		]:
			var after_sunset := rules.tint_hours(stop[0]) * squeeze
			_stops.append([shift + sunset + after_sunset, rules.tint_colour(stop[1])])


func _sample_stops(hour: float) -> Color:
	if hour <= _stops[0][0]:
		return _stops[0][1]
	for index in range(1, _stops.size()):
		var next: Array = _stops[index]
		if hour <= next[0]:
			var previous: Array = _stops[index - 1]
			return previous[1].lerp(next[1], inverse_lerp(previous[0], next[0], hour))
	return _stops[-1][1]
