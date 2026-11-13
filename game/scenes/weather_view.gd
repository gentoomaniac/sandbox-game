class_name WeatherView
extends CanvasLayer
## The look of the weather, inside the world viewport so that it is drawn on the art pixel
## grid: rain, snow, wind streaks and leaves (one shader, see weather_precipitation.gdshader),
## fog (weather_fog.gdshader), cloud shadows drifting over the ground by day
## (cloud_shadows.gdshader) and the flash of lightning. Rain, snow and fog are anchored to
## the world, so they stay in place when the player walks. They cover the whole viewport, which
## is also all the window ever shows, at any zoom. The scene feeds it the weather every frame
## (`show_weather`); what is on screen follows with a fade, so changes in the weather are
## never abrupt. Hide the node to show no weather, e.g. inside a building.

## A flash of lightning has begun, from a strike this far away (its thunder is up to whoever
## listens).
signal flashed(strike: LightningStrike)

const PRECIPITATION_SHADER := preload("res://game/scenes/weather_precipitation.gdshader")
const FOG_SHADER := preload("res://game/scenes/weather_fog.gdshader")
const CLOUD_SHADOWS_SHADER := preload("res://game/scenes/cloud_shadows.gdshader")

## How fast what is shown follows the weather: the share of the way it covers per second.
const FOLLOW_RATE := 1.5
## Pixels per second. The shaders work on the world's pixels, as the art at 32 px per tile, and
## so do all the numbers of pixels here.
const RAIN_FALL_SPEED := 460.0
const SNOW_FALL_SPEED := 48.0
## Pixels per second for every m/s of wind.
const SNOW_DRIFT_PER_WIND := 10.0
const STREAK_SPEED_PER_WIND := 28.0
const FOG_DRIFT_PER_WIND := 2.0
## Sideways pixels a raindrop moves for every pixel it falls, per m/s of wind.
const RAIN_SLANT_PER_WIND := 0.03
const MAX_RAIN_SLANT := 0.6
## The cloud shadow pattern repeats after this many patches, so that its drift can wrap around
## without a visible jump and stays small enough for a float to hold whole pixels.
const CLOUD_SHADOW_PERIOD_PATCHES := 32.0

## Fog drifts a little even without wind, in pixels per second.
const FOG_BASE_DRIFT := Vector2(3.0, 0.8)
## Effects with less than this intensity are not drawn at all.
const MIN_INTENSITY := 0.003

const FLASH_COLOR := Color(0.88, 0.92, 1.0)
## How bright the flash is while it is held on (see is_flash_held).
const HELD_FLASH_OPACITY := 0.55
## A pulse of a crawler's flicker is a glow this wide (a share of the view) that rises and fades
## in this many seconds each.
const CRAWL_GLOW_WIDTH_SHARE := 0.45
const CRAWL_PULSE_RISE_SECONDS := 0.04
const CRAWL_PULSE_FADE_SECONDS := 0.16
## The bolt shows for a few frames: at its brightness, dimmed for the second stroke, then gone.
const BOLT_FIRST_SECONDS := 0.07
const BOLT_SECOND_SECONDS := 0.05
const BOLT_SECOND_SHARE := 0.6
const BOLT_FADE_SECONDS := 0.08

## The part of the viewport the window shows, where a bolt is drawn so that it is seen at any zoom;
## Main keeps it up to date.
var visible_region := Rect2(Vector2.ZERO, Vector2(ViewMath.VIEWPORT_SIZE))
## Debug: keeps the flash of lightning on, for screenshots.
var is_flash_held := false
## The rain (0 to 1) and the wind (m/s, the way it blows) shown now, which the world's ambient
## motion follows too (see AmbientMotion).
var rain := 0.0
var wind := Vector2.ZERO
## How dark the darkest part of a cloud shadow is now (0 to 1), and how far the shadows have
## drifted, in pixels (wrapped at the pattern's period).
var cloud_shadow_strength := 0.0
var cloud_shadow_drift := Vector2.ZERO

var _precipitation := ColorRect.new()
var _fog := ColorRect.new()
var _cloud_shadows := ColorRect.new()
var _flash := ColorRect.new()
var _crawl_glow := TextureRect.new()
var _bolt := TextureRect.new()
var _rules := LightingRules.default_rules()
var _weather_rules := WeatherRules.default_rules()
var _rng := RandomNumberGenerator.new()
var _target := WeatherSample.new()
var _has_weather := false
## The other intensities shown now.
var _snow := 0.0
var _fog_density := 0.0
var _wind_intensity := 0.0
var _cloud_cover := 0.0
## How much daylight there is (see DayNightTint).
var _daylight := 0.0
## How far each effect has moved, in pixels.
var _rain_fall := 0.0
var _snow_scroll := Vector2.ZERO
var _streak_scroll := Vector2.ZERO
var _fog_drift := Vector2.ZERO
var _seconds := 0.0
var _is_snap_due := false
var _flash_tween: Tween
var _bolt_tween: Tween


func _init() -> void:
	layer = 1
	var view_size := Vector2(ViewMath.VIEWPORT_SIZE)
	for rect: ColorRect in [_cloud_shadows, _fog, _precipitation, _flash]:
		rect.size = view_size
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(rect)
	_fog.material = _shader_material(FOG_SHADER, view_size)
	_cloud_shadows.material = _shader_material(CLOUD_SHADOWS_SHADER, view_size)
	_precipitation.material = _shader_material(PRECIPITATION_SHADER, view_size)
	_flash.color = Color(FLASH_COLOR, 0.0)
	_set_up_crawl_glow(view_size)
	_set_up_bolt()


## Sets the weather to show, the tint of the world (see DayNightTint), which the effects
## wear too, and how much daylight there is (0 to 1), which the cloud shadows fade with. The
## first weather shown appears at once; later changes fade in and out.
func show_weather(sample: WeatherSample, tint: Color, daylight: float) -> void:
	_target = sample
	_daylight = daylight
	if _is_snap_due:
		_is_snap_due = false
		_follow_target(1.0)
	_precipitation.material.set_shader_parameter("tint", tint)
	_fog.material.set_shader_parameter("tint", tint)
	if not _has_weather:
		_has_weather = true
		_follow_target(1.0)


## Time has skipped: the next weather shown appears at once, with no fade from the old.
func snap() -> void:
	_is_snap_due = true


## Game minutes have passed: each one may bring a flash of lightning.
func minutes_passed(count: int) -> void:
	for _minute in count:
		if randf() < _target.lightning_chance:
			flash()


## A flash of lightning from a strike (a random one unless given): a near one is bright for a
## moment, flickers, then fades; a far one (as far as its thunder is the far kind) is a faint glow
## that swells and fades slowly.
func flash(strike := LightningStrike.draw(_rng, _weather_rules)) -> void:
	flashed.emit(strike)
	if _flash_tween != null:
		_flash_tween.kill()
	# Whatever the last flash left on is over: a crawler's glow too, if it is cut short.
	_flash.color.a = 0.0
	_crawl_glow.modulate.a = 0.0
	var peak := strike.flash_peak()
	_show_bolt(strike)
	_flash_tween = create_tween()
	if strike.is_crawl:
		_flicker_along_the_sky(strike)
		return
	if strike.event() == LightningStrike.FAR:
		_flash.color.a = 0.0
		_flash_tween.tween_property(_flash, "color:a", peak, 0.2)
	else:
		_flash.color.a = peak
		_flash_tween.tween_property(_flash, "color:a", peak * 0.2, 0.07)
		_flash_tween.tween_property(_flash, "color:a", peak * 0.7, 0.03)
	_flash_tween.tween_property(_flash, "color:a", 0.0, strike.flash_fade_seconds())


## The flash of a crawler: faint pulses of glow one after the other along the sky, left to right
## or the other way, instead of one burst.
func _flicker_along_the_sky(strike: LightningStrike) -> void:
	var glow_size := _crawl_glow.size
	var elapsed := 0.0
	for pulse in strike.crawl_pulses():
		_flash_tween.tween_interval(pulse.x - elapsed)
		elapsed = pulse.x + CRAWL_PULSE_RISE_SECONDS + CRAWL_PULSE_FADE_SECONDS
		var centre_x := pulse.y * ViewMath.VIEWPORT_SIZE.x
		_flash_tween.tween_callback(
			func() -> void: _crawl_glow.position.x = centre_x - glow_size.x / 2.0
		)
		_flash_tween.tween_property(
			_crawl_glow, "modulate:a", strike.flash_peak() * pulse.z, CRAWL_PULSE_RISE_SECONDS
		)
		_flash_tween.tween_property(_crawl_glow, "modulate:a", 0.0, CRAWL_PULSE_FADE_SECONDS)


## Draws the bolt of the strike, if it has one, for a few frames. Its picture is made here, once
## per strike, in the art's pixels (twice as big in the classic art), shown with no smoothing.
func _show_bolt(strike: LightningStrike) -> void:
	if _bolt_tween != null:
		_bolt_tween.kill()
	_bolt.modulate.a = 0.0
	_bolt.texture = null
	var opacity := strike.bolt_opacity()
	if opacity <= 0.0:
		return
	var pixel := TerrainTileset.ART_16_SCALE if ArtSet.is_classic else 1
	var sky_pixels := Vector2i((visible_region.size / pixel).ceil())
	var bolt := LightningBolt.new(strike.shape_seed, sky_pixels, _weather_rules)
	_bolt.texture = ImageTexture.create_from_image(BoltImage.render(bolt, sky_pixels))
	_bolt.position = (visible_region.position / pixel).round() * pixel
	_bolt.size = Vector2(sky_pixels * pixel)
	_bolt.modulate.a = opacity
	_bolt_tween = create_tween()
	_bolt_tween.tween_interval(BOLT_FIRST_SECONDS)
	_bolt_tween.tween_property(_bolt, "modulate:a", opacity * BOLT_SECOND_SHARE, 0.0)
	_bolt_tween.tween_interval(BOLT_SECOND_SECONDS)
	_bolt_tween.tween_property(_bolt, "modulate:a", 0.0, BOLT_FADE_SECONDS)
	_bolt_tween.tween_callback(func() -> void: _bolt.texture = null)


func _set_up_bolt() -> void:
	_bolt.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_bolt.stretch_mode = TextureRect.STRETCH_SCALE
	_bolt.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_bolt.modulate.a = 0.0
	_bolt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bolt)


func _set_up_crawl_glow(view_size: Vector2) -> void:
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray(
		[Color(FLASH_COLOR, 0.0), FLASH_COLOR, Color(FLASH_COLOR, 0.0)]
	)
	gradient.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill_from = Vector2(0.0, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	_crawl_glow.texture = texture
	_crawl_glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_crawl_glow.stretch_mode = TextureRect.STRETCH_SCALE
	_crawl_glow.size = Vector2(view_size.x * CRAWL_GLOW_WIDTH_SHARE, view_size.y)
	_crawl_glow.modulate.a = 0.0
	_crawl_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_crawl_glow)


func _process(delta: float) -> void:
	_follow_target(1.0 - exp(-FOLLOW_RATE * delta))
	_seconds += delta
	var wind_x := wind.x
	_rain_fall += RAIN_FALL_SPEED * delta
	_snow_scroll += Vector2(wind_x * SNOW_DRIFT_PER_WIND, SNOW_FALL_SPEED) * delta
	var gust_direction := -1.0 if wind_x < 0.0 else 1.0
	_streak_scroll += Vector2(gust_direction * wind.length() * STREAK_SPEED_PER_WIND, 0.0) * delta
	_fog_drift += (FOG_BASE_DRIFT + wind * FOG_DRIFT_PER_WIND) * delta
	var shadow_period: float = CLOUD_SHADOW_PERIOD_PATCHES * _rules.cloud_shadow("size")
	cloud_shadow_drift += wind * _rules.cloud_shadow("speed_per_wind") * delta
	cloud_shadow_drift = cloud_shadow_drift.posmod(shadow_period)
	if is_flash_held:
		_flash.color.a = HELD_FLASH_OPACITY
	_show_effects(wind_x)


## Moves what is shown by `share` (0 to 1) of the way to the weather.
func _follow_target(share: float) -> void:
	rain = lerpf(rain, _target.rain, share)
	_snow = lerpf(_snow, _target.snow, share)
	_fog_density = lerpf(_fog_density, _target.fog, share)
	_wind_intensity = lerpf(_wind_intensity, _target.wind, share)
	_cloud_cover = lerpf(_cloud_cover, _target.cloud_cover, share)
	wind = wind.lerp(_target.wind_direction * _target.wind_speed, share)


func _show_effects(wind_x: float) -> void:
	_precipitation.visible = maxf(maxf(rain, _snow), _wind_intensity) > MIN_INTENSITY
	_fog.visible = _fog_density > MIN_INTENSITY
	var precipitation: ShaderMaterial = _precipitation.material
	precipitation.set_shader_parameter("time", _seconds)
	precipitation.set_shader_parameter("rain", rain)
	precipitation.set_shader_parameter("rain_fall", _rain_fall)
	precipitation.set_shader_parameter(
		"rain_slant", clampf(wind_x * RAIN_SLANT_PER_WIND, -MAX_RAIN_SLANT, MAX_RAIN_SLANT)
	)
	precipitation.set_shader_parameter("snow", _snow)
	precipitation.set_shader_parameter("snow_scroll", _snow_scroll)
	precipitation.set_shader_parameter("wind", _wind_intensity)
	precipitation.set_shader_parameter("wind_scroll", _streak_scroll)
	_show_cloud_shadows()
	var fog: ShaderMaterial = _fog.material
	fog.set_shader_parameter("fog", _fog_density)
	fog.set_shader_parameter("drift", _fog_drift)
	var camera := get_viewport().get_camera_2d()
	if camera != null:
		precipitation.set_shader_parameter("camera", camera.position.round())
		fog.set_shader_parameter("camera", camera.position.round())


## The shadows need a sun that is out: by day, under a partly clouded sky, with no rain or snow.
## Under a closed sky there are none, as the day tint dims the whole scene then (task 177), so
## the ground isn't darkened twice.
func _show_cloud_shadows() -> void:
	var closed_from := _rules.cloud_shadow("closed_from")
	var open_sky := 1.0 - smoothstep(closed_from, 1.0, _cloud_cover)
	var sun_out := 1.0 - maxf(rain, _snow)
	cloud_shadow_strength = (_rules.cloud_shadow("strength") * _daylight * sun_out * open_sky)
	_cloud_shadows.visible = cloud_shadow_strength * _cloud_cover > MIN_INTENSITY
	var shadows: ShaderMaterial = _cloud_shadows.material
	shadows.set_shader_parameter("cover", _cloud_cover)
	shadows.set_shader_parameter("strength", cloud_shadow_strength)
	shadows.set_shader_parameter("size", _rules.cloud_shadow("size"))
	shadows.set_shader_parameter("coverage", _rules.cloud_shadow("coverage"))
	shadows.set_shader_parameter("softness", _rules.cloud_shadow("softness"))
	shadows.set_shader_parameter("drift", cloud_shadow_drift)
	shadows.set_shader_parameter("period_patches", CLOUD_SHADOW_PERIOD_PATCHES)
	var camera := get_viewport().get_camera_2d()
	if camera != null:
		shadows.set_shader_parameter("camera", camera.position.round())


static func _shader_material(shader: Shader, view_size: Vector2) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("view_size", view_size)
	return material
