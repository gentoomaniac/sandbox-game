class_name LightingRules
extends RefCounted
## How dark the night gets, when dusk and dawn come and how the lantern shines, read from
## data/lighting.cfg (see there for what each value means). `from_file` reports every key that
## is missing or wrong, and `is_valid` says whether any was.

const DEFAULT_PATH := "res://data/lighting.cfg"

## The colours of the day's stops and the hours that place them (see DayNightTint).
const TINT_COLOURS := ["night", "dawn", "day", "dusk_glow", "dusk_purple"]
const TINT_HOURS := [
	"night_before_sunrise",
	"day_after_sunrise",
	"day_before_sunset",
	"glow_after_sunset",
	"purple_after_sunset",
	"night_after_sunset",
	"min_night_hours",
]
## The lantern's light, in the shape of a world object's `light` (see ObjectLight).
const LANTERN_KEYS := ["color", "energy", "radius_tiles"]

## The cloud shadows' numbers, each a plain number (see WeatherView).
const CLOUD_SHADOW_KEYS := [
	"strength", "size", "size_growth", "coverage", "softness", "speed_per_wind", "closed_from"
]

static var _default: LightingRules

## {section: {key: value}}, as in the file.
var _values: Dictionary


func _init(values: Dictionary) -> void:
	_values = values


## The rules of the data file, loaded the first time they are asked for.
static func default_rules() -> LightingRules:
	if _default == null:
		_default = from_file(DEFAULT_PATH)
	return _default


static func from_file(path: String) -> LightingRules:
	var rules := LightingRules.new(DataFile.read_sections(path))
	for problem in rules.problems():
		push_error("%s: %s" % [path, problem])
	return rules


## What is missing or wrong, as "[section] what".
func problems() -> Array[String]:
	var found: Array[String] = []
	var tint: Dictionary = _values.get("day_and_night", {})
	for key: String in TINT_COLOURS + TINT_HOURS:
		if not tint.has(key):
			found.append("[day_and_night] no %s" % key)
	var lantern: Dictionary = _values.get("lantern", {})
	for key: String in LANTERN_KEYS:
		if not lantern.has(key):
			found.append("[lantern] no %s" % key)
	var cloud_shadows: Dictionary = _values.get("cloud_shadows", {})
	for key: String in CLOUD_SHADOW_KEYS:
		if not cloud_shadows.has(key):
			found.append("[cloud_shadows] no %s" % key)
	if not found.is_empty():
		return found
	if not lantern["color"] is Color:
		found.append("[lantern] color must be a Color(r, g, b, a)")
	for key: String in ["energy", "radius_tiles"]:
		if float(lantern[key]) <= 0.0:
			found.append("[lantern] %s must be above 0" % key)
	for key: String in TINT_COLOURS:
		if not tint[key] is Color:
			found.append("[day_and_night] %s must be a Color(r, g, b, a)" % key)
	for key: String in TINT_HOURS:
		if float(tint[key]) < 0.0:
			found.append("[day_and_night] %s must not be below 0" % key)
	if not (
		tint_hours("glow_after_sunset") < tint_hours("purple_after_sunset")
		and tint_hours("purple_after_sunset") < tint_hours("night_after_sunset")
	):
		found.append(
			"[day_and_night] needs glow_after_sunset < purple_after_sunset < night_after_sunset"
		)
	for key: String in ["strength", "coverage", "closed_from"]:
		if float(cloud_shadows[key]) < 0.0 or float(cloud_shadows[key]) > 1.0:
			found.append("[cloud_shadows] %s must be from 0 to 1" % key)
	for key: String in ["size", "softness"]:
		if float(cloud_shadows[key]) <= 0.0:
			found.append("[cloud_shadows] %s must be above 0" % key)
	for key: String in ["size_growth", "speed_per_wind"]:
		if float(cloud_shadows[key]) < 0.0:
			found.append("[cloud_shadows] %s must not be below 0" % key)
	return found


func is_valid() -> bool:
	return problems().is_empty()


## The tint at a stop of the day (one of TINT_COLOURS).
func tint_colour(stop: String) -> Color:
	return _values["day_and_night"][stop]


## Hours that place the stops of the day (one of TINT_HOURS).
func tint_hours(key: String) -> float:
	return float(_values["day_and_night"][key])


## The light of a lit lantern: {color, energy, radius_tiles}, as ObjectLight takes it.
func lantern_light() -> Dictionary:
	var lantern: Dictionary = _values["lantern"]
	return {
		"color": lantern["color"],
		"energy": float(lantern["energy"]),
		"radius_tiles": float(lantern["radius_tiles"]),
	}


## One of the cloud shadows' numbers (one of CLOUD_SHADOW_KEYS).
func cloud_shadow(key: String) -> float:
	return float(_values["cloud_shadows"][key])
