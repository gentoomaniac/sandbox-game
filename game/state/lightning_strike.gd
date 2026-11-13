class_name LightningStrike
extends RefCounted
## One strike of lightning at some distance: how long its thunder takes to arrive, how loud and
## how dull it is when it does, which thunder it is, and how bright and sharp the flash is. Far
## strikes are the common ones and a close one is rare. Some lightning runs across the sky instead
## of striking down (a crawler): a mid or far distance, a rumble that travels and a flash that
## flickers along the sky. The numbers are in data/weather.cfg's [strike] (see WeatherRules).

## The kinds of thunder, by how far the strike was: a sound event each.
const CLOSE := &"thunder_close"
const MID := &"thunder_mid"
const FAR := &"thunder_far"
const CRAWL := &"thunder_crawl"
## What keeps a crawler's pulses from being evenly spaced: how far, in pulses, one is off its place
## along the sky and how late, in pulse intervals, it starts; and how faint the faintest is.
const PULSE_PLACE_JITTER := 0.3
const PULSE_START_JITTER := 0.4
const MIN_PULSE_STRENGTH := 0.35

## How far away the strike was, in km.
var distance_km := 0.0
## Whether this lightning runs across the sky, from one side to the other.
var is_crawl := false
## Seeds the shape of this strike's flicker, so that it is the same every time it is asked for.
var shape_seed := 0
var _rules: WeatherRules


func _init(
	distance: float, rules := WeatherRules.default_rules(), crawl := false, seed_of_shape := 0
) -> void:
	distance_km = distance
	is_crawl = crawl
	shape_seed = seed_of_shape
	_rules = rules


## A strike at a random distance: one of the three bands or the crawler's by its weight, then
## anywhere in it.
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
		rules.value("strike", "crawl_weight"),
	]
	var pick := rng.randf() * (weights[0] + weights[1] + weights[2] + weights[3])
	var band := 0
	while band < 3 and pick >= weights[band]:
		pick -= weights[band]
		band += 1
	var shape := rng.randi()
	if band == 3:
		# A crawler is as far as a mid or a far strike.
		return LightningStrike.new(rng.randf_range(edges[1], edges[3]), rules, true, shape)
	return LightningStrike.new(rng.randf_range(edges[band], edges[band + 1]), rules, false, shape)


## The sound event of this strike's thunder.
func event() -> StringName:
	if is_crawl:
		return CRAWL
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


## The flicker of a crawler's flash, one pulse after the other along the sky: x is the start in
## seconds after the flash, y where along the sky it is (0 the left edge, 1 the right) and z how
## strong it is (0 to 1 of the flash's peak). The pulses travel one way, left to right or the
## other as `is_crawling_rightwards` has it; there are none for other strikes.
func crawl_pulses() -> Array[Vector3]:
	var pulses: Array[Vector3] = []
	if not is_crawl:
		return pulses
	var dice := RandomNumberGenerator.new()
	dice.seed = shape_seed
	var count := int(_rules.value("strike", "crawl_pulses"))
	var step: float = _rules.value("strike", "crawl_seconds") / count
	var is_rightwards := is_crawling_rightwards()
	for index in count:
		var along := clampf(
			(index + dice.randf_range(-PULSE_PLACE_JITTER, PULSE_PLACE_JITTER)) / (count - 1),
			0.0,
			1.0
		)
		var start := (index + dice.randf_range(0.0, PULSE_START_JITTER)) * step
		var strength := dice.randf_range(MIN_PULSE_STRENGTH, 1.0)
		pulses.append(Vector3(start, along if is_rightwards else 1.0 - along, strength))
	return pulses


## Whether a crawler runs from the left of the sky to the right, which its flicker and its
## thunder both follow, else from the right to the left.
func is_crawling_rightwards() -> bool:
	return shape_seed % 2 == 0


## 0 for the nearest strike there is, 1 for the farthest.
func _remoteness() -> float:
	var nearest := _rules.value("strike", "min_km")
	var farthest := _rules.value("strike", "far_to_km")
	return clampf(inverse_lerp(nearest, farthest, distance_km), 0.0, 1.0)
