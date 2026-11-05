class_name WeatherView
extends CanvasLayer
## The look of the weather, inside the world viewport so that it is drawn on the art pixel
## grid: rain, snow, wind streaks and leaves (one shader, see weather_precipitation.gdshader),
## fog (weather_fog.gdshader) and the flash of lightning. They cover the whole viewport, which
## is also all the window ever shows, at any zoom. The scene feeds it the weather every frame
## (`show_weather`); what is on screen follows with a fade, so changes in the weather are
## never abrupt. Hide the node to show no weather, e.g. inside a building.

const PRECIPITATION_SHADER := preload("res://game/scenes/weather_precipitation.gdshader")
const FOG_SHADER := preload("res://game/scenes/weather_fog.gdshader")

## How fast what is shown follows the weather: the share of the way it covers per second.
const FOLLOW_RATE := 1.5
## Art pixels per second.
const RAIN_FALL_SPEED := 230.0
const SNOW_FALL_SPEED := 24.0
## Pixels per second for every m/s of wind.
const SNOW_DRIFT_PER_WIND := 5.0
const STREAK_SPEED_PER_WIND := 14.0
const FOG_DRIFT_PER_WIND := 1.0
## Sideways pixels a raindrop moves for every pixel it falls, per m/s of wind.
const RAIN_SLANT_PER_WIND := 0.03
const MAX_RAIN_SLANT := 0.6
## Fog drifts a little even without wind, in pixels per second.
const FOG_BASE_DRIFT := Vector2(1.5, 0.4)
## Effects with less than this intensity are not drawn at all.
const MIN_INTENSITY := 0.003

const FLASH_COLOR := Color(0.88, 0.92, 1.0)
const FLASH_PEAK := 0.55

## Debug: keeps the flash of lightning on, for screenshots.
var is_flash_held := false

var _precipitation := ColorRect.new()
var _fog := ColorRect.new()
var _flash := ColorRect.new()
var _target := WeatherSample.new()
var _has_weather := false
## What is shown now: intensities, and the wind in m/s.
var _rain := 0.0
var _snow := 0.0
var _fog_density := 0.0
var _wind_intensity := 0.0
var _wind := Vector2.ZERO
## How far each effect has moved, in pixels.
var _rain_fall := 0.0
var _snow_scroll := Vector2.ZERO
var _streak_scroll := Vector2.ZERO
var _fog_drift := Vector2.ZERO
var _seconds := 0.0
var _flash_tween: Tween


func _init() -> void:
	layer = 1
	var view_size := Vector2(ViewMath.VIEWPORT_SIZE)
	for rect: ColorRect in [_fog, _precipitation, _flash]:
		rect.size = view_size
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(rect)
	_fog.material = _shader_material(FOG_SHADER, view_size)
	_precipitation.material = _shader_material(PRECIPITATION_SHADER, view_size)
	_flash.color = Color(FLASH_COLOR, 0.0)


## Sets the weather to show and the tint of the world (see DayNightTint), which the effects
## wear too. The first weather shown appears at once; later changes fade in and out.
func show_weather(sample: WeatherSample, tint: Color) -> void:
	_target = sample
	_precipitation.material.set_shader_parameter("tint", tint)
	_fog.material.set_shader_parameter("tint", tint)
	if not _has_weather:
		_has_weather = true
		_follow_target(1.0)


## Game minutes have passed: each one may bring a flash of lightning.
func minutes_passed(count: int) -> void:
	for _minute in count:
		if randf() < _target.lightning_chance:
			flash()


## A flash of lightning: bright for a moment, a flicker, then a fade.
func flash() -> void:
	if _flash_tween != null:
		_flash_tween.kill()
	_flash.color.a = FLASH_PEAK
	_flash_tween = create_tween()
	_flash_tween.tween_property(_flash, "color:a", 0.12, 0.07)
	_flash_tween.tween_property(_flash, "color:a", FLASH_PEAK * 0.7, 0.03)
	_flash_tween.tween_property(_flash, "color:a", 0.0, 0.35)


func _process(delta: float) -> void:
	_follow_target(1.0 - exp(-FOLLOW_RATE * delta))
	_seconds += delta
	var wind_x := _wind.x
	_rain_fall += RAIN_FALL_SPEED * delta
	_snow_scroll += Vector2(wind_x * SNOW_DRIFT_PER_WIND, SNOW_FALL_SPEED) * delta
	var gust_direction := -1.0 if wind_x < 0.0 else 1.0
	_streak_scroll += Vector2(gust_direction * _wind.length() * STREAK_SPEED_PER_WIND, 0.0) * delta
	_fog_drift += (FOG_BASE_DRIFT + _wind * FOG_DRIFT_PER_WIND) * delta
	if is_flash_held:
		_flash.color.a = FLASH_PEAK
	_show_effects(wind_x)


## Moves what is shown by `share` (0 to 1) of the way to the weather.
func _follow_target(share: float) -> void:
	_rain = lerpf(_rain, _target.rain, share)
	_snow = lerpf(_snow, _target.snow, share)
	_fog_density = lerpf(_fog_density, _target.fog, share)
	_wind_intensity = lerpf(_wind_intensity, _target.wind, share)
	_wind = _wind.lerp(_target.wind_direction * _target.wind_speed, share)


func _show_effects(wind_x: float) -> void:
	_precipitation.visible = maxf(maxf(_rain, _snow), _wind_intensity) > MIN_INTENSITY
	_fog.visible = _fog_density > MIN_INTENSITY
	var precipitation: ShaderMaterial = _precipitation.material
	precipitation.set_shader_parameter("time", _seconds)
	precipitation.set_shader_parameter("rain", _rain)
	precipitation.set_shader_parameter("rain_fall", _rain_fall)
	precipitation.set_shader_parameter(
		"rain_slant", clampf(wind_x * RAIN_SLANT_PER_WIND, -MAX_RAIN_SLANT, MAX_RAIN_SLANT)
	)
	precipitation.set_shader_parameter("snow", _snow)
	precipitation.set_shader_parameter("snow_scroll", _snow_scroll)
	precipitation.set_shader_parameter("wind", _wind_intensity)
	precipitation.set_shader_parameter("wind_scroll", _streak_scroll)
	var fog: ShaderMaterial = _fog.material
	fog.set_shader_parameter("fog", _fog_density)
	fog.set_shader_parameter("drift", _fog_drift)
	var camera := get_viewport().get_camera_2d()
	if camera != null:
		fog.set_shader_parameter("camera", camera.position.round())


static func _shader_material(shader: Shader, view_size: Vector2) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("view_size", view_size)
	return material
