class_name SeaSounds
extends Node
## The waves of the shore (`sea_loop`): heard from the sea's edge, quieter with the distance to the
## nearest water until they are gone a few chunks inland, from the side the water is on, louder at
## high water and in a storm, and muffled indoors by the Ambience bus they play on (the numbers
## are AmbienceRules', in [sea] of data/ambience.cfg).
##
## It is cheap by design: a few times a second (`look_seconds`) it looks for the nearest water on a
## coarse grid around the player (SeaSearch), never over a whole area, and in between only keeps the
## loop beside the player. The loop is plain, one for the whole world, and exists only while the
## waves are audible.

## How many looks the pan takes to swing from one side to the other (-1 to 1): it follows the way to
## the water without jumping when the nearest water changes.
const PAN_SWING_LOOKS := 1.0
## A playing loop stops only below this share of `[loops] min_level`, so a player standing at the
## edge of hearing doesn't start and stop it at every look.
const STOP_SHARE := 0.5

var rules := AmbienceRules.default_rules()
var _audio: AudioService
var _state: GameState
var _search := SeaSearch.new()
var _loop: SoundLoop
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
	if _loop != null:
		_loop.move_to(_loop_position())


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
	var least := rules.value("loops", "min_level") * (STOP_SHARE if _loop != null else 1.0)
	_follow(level if level >= least else 0.0)


## Starts, fades or stops the loop so that it is at `level`.
func _follow(level: float) -> void:
	var fade_seconds := rules.value("sea", "fade_seconds")
	if level == 0.0:
		if _loop != null:
			_loop.stop(fade_seconds)
			_loop = null
	else:
		if _loop == null:
			_pan = _pan_target
			_loop = _audio.start_loop(
				&"sea_loop", _loop_position(), 0.0, AudioService.MAX_DISTANCE, 0.0
			)
			_level = 0.0
		if not is_equal_approx(level, _level):
			_loop.fade_to(level, fade_seconds)
	_level = level
