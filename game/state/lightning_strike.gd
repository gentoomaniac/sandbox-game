class_name LightningStrike
extends RefCounted
## One strike of lightning at some distance: how long its thunder takes to arrive, how loud and
## how dull it is when it does, which thunder it is, and how bright and sharp the flash is. Far
## strikes are the common ones and a close one is rare. The numbers are in data/weather.cfg's
## [strike] (see WeatherRules).

## The kinds of thunder, by how far the strike was: a sound event each.
const CLOSE := &"thunder_close"
const MID := &"thunder_mid"
const FAR := &"thunder_far"

## How far away the strike was, in km.
var distance_km := 0.0
var _rules: WeatherRules


func _init(distance: float, rules := WeatherRules.default_rules()) -> void:
	distance_km = distance
	_rules = rules


## A strike at a random distance: one of the three bands by its weight, then anywhere in it.
static func draw(
	rng: RandomNumberGenerator, rules := WeatherRules.default_rules()
) -> LightningStrike:
	var edges: Array[float] = [
		rules.value("strike", "min_km"),
		rules.value("strike", "close_to_km"),
		rules.value("strike", "mid_to_km"),
		rules.value("strike", "far_to_km"),
	]
	var weights: Array[float] = [
		rules.value("strike", "close_weight"),
		rules.value("strike", "mid_weight"),
		rules.value("strike", "far_weight"),
	]
	var pick := rng.randf() * (weights[0] + weights[1] + weights[2])
	var band := 0
	while band < 2 and pick >= weights[band]:
		pick -= weights[band]
		band += 1
	return LightningStrike.new(rng.randf_range(edges[band], edges[band + 1]), rules)


## The sound event of this strike's thunder.
func event() -> StringName:
	if distance_km < _rules.value("strike", "close_to_km"):
		return CLOSE
	if distance_km < _rules.value("strike", "mid_to_km"):
		return MID
	return FAR


## Seconds from the flash to the thunder: the sound's travel time.
func delay_seconds() -> float:
	return distance_km * _rules.value("strike", "seconds_per_km")


## The share (0 to 1) of the event's volume the thunder has, falling with the distance.
func level() -> float:
	return db_to_linear(-distance_km * _rules.value("strike", "fall_db_per_km"))


## The cutoff of the low-pass the thunder goes through: duller the farther the strike.
func cutoff_hz() -> float:
	return lerpf(
		_rules.value("strike", "cutoff_near_hz"),
		_rules.value("strike", "cutoff_far_hz"),
		_remoteness()
	)


## How bright the flash is, as the opacity of the white over the screen at its peak.
func flash_peak() -> float:
	return lerpf(
		_rules.value("strike", "flash_peak_near"),
		_rules.value("strike", "flash_peak_far"),
		_remoteness()
	)


## How long the flash takes to fade out: far strikes are a slow, diffuse glow.
func flash_fade_seconds() -> float:
	return lerpf(
		_rules.value("strike", "flash_fade_near_seconds"),
		_rules.value("strike", "flash_fade_far_seconds"),
		_remoteness()
	)


## 0 for the nearest strike there is, 1 for the farthest.
func _remoteness() -> float:
	var nearest := _rules.value("strike", "min_km")
	var farthest := _rules.value("strike", "far_to_km")
	return clampf(inverse_lerp(nearest, farthest, distance_km), 0.0, 1.0)
