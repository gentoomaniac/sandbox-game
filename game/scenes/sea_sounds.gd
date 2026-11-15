class_name SeaSounds
extends Node
## The waves of the shore (`sea_loop`, and `sea_storm_loop` as the weather turns rough): heard from
## the sea's edge, quieter with the distance to the nearest water until they are gone a few chunks
## inland, from the side the water is on, louder at high water and in a storm, and muffled indoors
## by the Ambience bus they play on (the numbers are AmbienceRules', in [sea] of data/ambience.cfg).
## The calm loop and the stormy one are crossfaded by the weather's storm (equal power, see
## AmbienceRules.sea_blend); only the one or two that are audible play.
##
## It is cheap by design: a few times a second (`look_seconds`) it looks for the nearest water on a
## coarse grid around the player (SeaSearch), never over a whole area, and in between only keeps the
## loops beside the player. The loops are plain, one pair for the whole world, and each exists only
## while it is audible.

## How many looks the pan takes to swing from one side to the other (-1 to 1): it follows the way to
## the water without jumping when the nearest water changes.
const PAN_SWING_LOOKS := 1.0
## A playing loop stops only below this share of `[loops] min_level`, so a player standing at the
## edge of hearing doesn't start and stop it at every look.
const STOP_SHARE := 0.5


## One of the two loops: nothing playing while `loop` is null.
class Voice:
	extends RefCounted
	var event: StringName
	var loop: SoundLoop
	var level := 0.0

	func _init(event_name: StringName) -> void:
		event = event_name


var rules := AmbienceRules.default_rules()
var _audio: AudioService
var _state: GameState
var _search := SeaSearch.new()
var _calm := Voice.new(&"sea_loop")
var _rough := Voice.new(&"sea_storm_loop")
## The level of all the waves; each loop has its share of it.
var _level := 0.0
var _pan := 0.0
var _pan_target := 0.0
var _seconds_to_look := 0.0


## Starts following the player in `state`, playing through `audio`.
func listen(audio: AudioService, state: GameState) -> void:
	_audio = audio
	_state = state
	_search.world = state.world
	_search.step = int(rules.value("sea", "search_step_tiles"))
	_search.is_flooded_mud_sea = rules.value("sea", "flooded_mud_is_sea") > 0.0


func _process(delta: float) -> void:
	_seconds_to_look -= delta
	if _seconds_to_look <= 0.0:
		_seconds_to_look += rules.value("sea", "look_seconds")
		_look()
	var swing_seconds := PAN_SWING_LOOKS * rules.value("sea", "look_seconds")
	_pan = move_toward(_pan, _pan_target, delta * 2.0 / swing_seconds)
	for voice in [_calm, _rough]:
		if voice.loop != null:
			voice.loop.move_to(_loop_position())


## Where the waves seem to come from: to the side of the player, as far as the pan says.
func _loop_position() -> Vector2:
	var width := rules.value("sea", "pan_width_tiles") * TerrainTileset.TILE_SIZE
	return _state.player.position * TerrainTileset.TILE_SIZE + Vector2(_pan * width, 0.0)


## Looks for the nearest water and sets the level and the side of the waves for it.
func _look() -> void:
	var weather := _state.current_weather()
	var tide := Tide.level(_state.clock.total_minutes())
	var way := _search.nearest(_state.outdoor_tile(), rules.sea_reach(weather), tide)
	_pan_target = rules.sea_pan(way) if way != Vector2.INF else 0.0
	var level := rules.sea_level(way.length(), tide, weather, _state.is_inside())
	var least := rules.value("loops", "min_level") * (STOP_SHARE if _is_playing() else 1.0)
	_follow(level if level >= least else 0.0, rules.sea_roughness(weather))


func _is_playing() -> bool:
	return _calm.loop != null or _rough.loop != null


## Starts, fades or stops the two loops so that together they are at `level`, as calm and as
## rough as `roughness` says.
func _follow(level: float, roughness: float) -> void:
	var blend := AmbienceRules.sea_blend(roughness)
	if level > 0.0 and not _is_playing():
		_pan = _pan_target
	_level = level
	_tune(_calm, level * blend.x)
	_tune(_rough, level * blend.y)


## Starts, fades or stops one loop for its `level`: below the least level it is gone, but a
## playing one stops only below `STOP_SHARE` of it.
func _tune(voice: Voice, level: float) -> void:
	var least := rules.value("loops", "min_level") * (STOP_SHARE if voice.loop != null else 1.0)
	var fade_seconds := rules.value("sea", "fade_seconds")
	if level < least or _level == 0.0:
		if voice.loop != null:
			voice.loop.stop(fade_seconds)
			voice.loop = null
		voice.level = 0.0
		return
	if voice.loop == null:
		voice.loop = _audio.start_loop(
			voice.event, _loop_position(), 0.0, AudioService.MAX_DISTANCE, 0.0
		)
	if not is_equal_approx(level, voice.level):
		voice.loop.fade_to(level, fade_seconds)
	voice.level = level
