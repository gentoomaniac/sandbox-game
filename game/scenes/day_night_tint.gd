class_name DayNightTint
extends CanvasModulate
## Colours the world canvas by time of day. Night stays bluish and readable, not black. Dawn
## comes with the sunrise and dusk with the sunset of the day (see Sun), and cloud cover
## dims and greys the day a little.

## Lights fade out as the tint gets brighter: full strength at this multiple of the darkness
## (1 - luminance) of the night tint, which is about 0.5.
const LIGHT_STRENGTH_PER_DARKNESS := 2.0

## Inside there is no day and night: a fixed warm tint, as from lamps and a hearth.
const INTERIOR_TINT := Color(1.0, 0.9, 0.78)

## The colours of the day's stops, blended linearly in between, and where the stops are
## relative to sunrise and sunset.
const NIGHT := Color(0.40, 0.46, 0.74)
const DAWN := Color(1.00, 0.82, 0.70)
const DAY := Color(1.00, 1.00, 1.00)
const DUSK_GLOW := Color(1.05, 0.66, 0.46)
const DUSK_PURPLE := Color(0.70, 0.52, 0.70)
## Night until this many hours before sunrise, then the dawn tint at sunrise ...
const NIGHT_BEFORE_SUNRISE := 1.5
## ... and full day this many hours after it.
const DAY_AFTER_SUNRISE := 2.0
## Full day until this many hours before sunset, the glow just after it, the purple later ...
const DAY_BEFORE_SUNSET := 1.0
const GLOW_AFTER_SUNSET := 0.5
const PURPLE_AFTER_SUNSET := 2.5
## ... and night this many hours after sunset.
const NIGHT_AFTER_SUNSET := 4.0
## A night is at least this many hours of full night: in the short nights of summer the dusk
## and dawn are squeezed to leave it.
const MIN_NIGHT_HOURS := 1.0
## Overcast skies darken the day tint by this much at most, and take this much of its colour.
const OVERCAST_DARKENING := 0.18
const OVERCAST_GREYING := 0.3

## Where the sun is, for the hours of dawn and dusk.
var sun := Sun.new()

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
	var daylight := clampf(
		(tint.get_luminance() - NIGHT.get_luminance()) / (1.0 - NIGHT.get_luminance()), 0.0, 1.0
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
	for day_offset in [-1, 0, 1]:
		var sunrise := sun.sunrise(day + day_offset) / GameClock.MINUTES_PER_HOUR
		var sunset := sun.sunset(day + day_offset) / GameClock.MINUTES_PER_HOUR
		var shift: float = day_offset * 24.0
		# Dawn and dusk ramps shrink together until a night of MIN_NIGHT_HOURS is left.
		var night_hours := 24.0 - (sunset - sunrise)
		var ramps := NIGHT_BEFORE_SUNRISE + NIGHT_AFTER_SUNSET
		var squeeze := minf(1.0, (night_hours - MIN_NIGHT_HOURS) / ramps)
		_stops.append([shift + sunrise - NIGHT_BEFORE_SUNRISE * squeeze, NIGHT])
		_stops.append([shift + sunrise, DAWN])
		_stops.append([shift + sunrise + DAY_AFTER_SUNRISE, DAY])
		_stops.append([shift + sunset - DAY_BEFORE_SUNSET, DAY])
		_stops.append([shift + sunset + GLOW_AFTER_SUNSET * squeeze, DUSK_GLOW])
		_stops.append([shift + sunset + PURPLE_AFTER_SUNSET * squeeze, DUSK_PURPLE])
		_stops.append([shift + sunset + NIGHT_AFTER_SUNSET * squeeze, NIGHT])


func _sample_stops(hour: float) -> Color:
	if hour <= _stops[0][0]:
		return _stops[0][1]
	for index in range(1, _stops.size()):
		var next: Array = _stops[index]
		if hour <= next[0]:
			var previous: Array = _stops[index - 1]
			return previous[1].lerp(next[1], inverse_lerp(previous[0], next[0], hour))
	return _stops[-1][1]
