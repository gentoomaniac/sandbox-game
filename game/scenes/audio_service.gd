class_name AudioService
extends Node
## Plays the game's sounds. Main owns it (not an autoload): everything that makes a sound is
## wired in Main anyway, and a node of its own is easy to test. `play` plays a sound event of
## data/sounds.cfg (see SoundRules) with a random variant and pitch; with a position the
## sound comes from there in the world (AudioStreamPlayer2D), else it is plain.
##
## Buses: Master with Game, Music and UI under it; Effects and Ambience send to Game, and
## OutsideEffects to Effects. While the game is paused (the pause menu, a chat) the Game bus fades
## to silence and back: only the music and the UI sounds go on (`fade_seconds` of
## data/ambience.cfg's [paused]).
## While the player is inside a building (`set_inside`) a low-pass filter fades in on Ambience and
## OutsideEffects, which is where the sounds of the world outside go, and they get quieter (the
## drop is `outside_db` of data/ambience.cfg's [indoors]).
## Players come from two small pools; when all are busy the next in turn is cut off.
##
## Debug: `--sound-log` (see StartupOptions) prints each event as it plays.

## An event was played; `position` is null for a plain sound.
signal played(event: StringName, position: Variant)

const MASTER := &"Master"
## Every sound of the game's world: silenced while the game is paused.
const GAME := &"Game"
const EFFECTS := &"Effects"
const AMBIENCE := &"Ambience"
const MUSIC := &"Music"
const UI := &"UI"
## Where the world's own effects play: muffled indoors, then on to Effects.
const OUTSIDE_EFFECTS := &"OutsideEffects"
## The bus of each `bus` value in sounds.cfg.
const BUS_OF_KEY := {"effects": EFFECTS, "ambience": AMBIENCE, "ui": UI}
## The bus of each volume channel of the settings (see GameSettings).
const CHANNEL_BUSES := {
	&"master": MASTER, &"effects": EFFECTS, &"ambience": AMBIENCE, &"music": MUSIC
}
## Where a bus sends its sound, for those that don't send to Master.
const SEND_OF_BUS := {EFFECTS: GAME, AMBIENCE: GAME, OUTSIDE_EFFECTS: EFFECTS}
## A slider's test clicks come at most this far apart, the last one at its final level.
const TEST_CLICK_SECONDS := 0.15
const POOL_SIZE := 12
## Beyond this far from the camera (31 tiles, in art pixels) a positional sound is silent, unless
## its event has a `reach_tiles` of its own.
const DEFAULT_REACH_TILES := 31.25
const MAX_DISTANCE := DEFAULT_REACH_TILES * TerrainTileset.TILE_SIZE
const SILENT_DB := -80.0

## Silent no matter the settings (the `--mute` flag, for test runs); sounds still play and
## log.
var is_muted := false
## Prints each event as it plays (the `--sound-log` flag). Set before the service is added to the
## tree.
var is_logging := false

var _rules := SoundRules.default_rules()
var _rng := RandomNumberGenerator.new()
var _muffle := Muffle.new()
var _low_passes: Array[AudioEffectLowPassFilter] = []
var _amplifiers: Array[AudioEffectAmplify] = []
## Seconds until a slider (by channel) may click again, and the level it last asked for while
## it had to wait.
var _test_cooldowns: Dictionary[StringName, float] = {}
var _test_waiting: Dictionary[StringName, float] = {}
var _pause_amplifier: AudioEffectAmplify
## 0 (the game's sounds play) to 1 (silenced by the pause).
var _pause_amount := 0.0
var _pause_fade_seconds: float = AmbienceRules.default_rules().value("paused", "fade_seconds")
var _outside_db: float = AmbienceRules.default_rules().value("indoors", "outside_db")
var _plain_players: Array[AudioStreamPlayer] = []
var _world_players: Array[AudioStreamPlayer2D] = []
var _world_root: Node = self
## The players that play each event that has `voices`, the oldest first, and the event each pool
## player was started for (a player may be cut off for another sound).
var _voices: Dictionary[StringName, Array] = {}
var _event_of: Dictionary[Node, StringName] = {}
var _next_plain := 0
var _next_world := 0
var _is_focused := true
var _is_sound_in_background := true


## A slider's percent as decibels: 100 % is 0 dB, and 0 % is silent.
static func percent_to_db(percent: float) -> float:
	if percent <= 0.0:
		return SILENT_DB
	return maxf(linear_to_db(percent / 100.0), SILENT_DB)


## Whether the game is silent: only when it isn't to play in the background and its window has
## lost the focus.
static func is_silenced(is_sound_in_background: bool, is_focused: bool) -> bool:
	return not is_sound_in_background and not is_focused


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.randomize()
	_set_up_buses()
	for index in POOL_SIZE:
		var player := AudioStreamPlayer.new()
		add_child(player)
		_plain_players.append(player)
		var world_player := AudioStreamPlayer2D.new()
		world_player.max_distance = MAX_DISTANCE
		# Reparented into the world viewport, which is paused with the game.
		world_player.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(world_player)
		_world_players.append(world_player)
	if is_logging:
		played.connect(
			func(event: StringName, position: Variant) -> void:
				print("sound: %s%s" % [event, "" if position == null else " at %s" % position])
		)


func _process(delta: float) -> void:
	_muffle.step(delta)
	for low_pass in _low_passes:
		low_pass.cutoff_hz = _muffle.cutoff_hz()
	for amplifier in _amplifiers:
		amplifier.volume_db = _muffle.volume_db(_outside_db)
	_step_test_clicks(delta)
	_pause_amount = move_toward(
		_pause_amount, 1.0 if get_tree().paused else 0.0, delta / _pause_fade_seconds
	)
	# Decibels are heard as loudness, so it fades in them, like the muffle.
	_pause_amplifier.volume_db = SILENT_DB * _pause_amount


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_is_focused = false
		_update_silence()
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN:
		_is_focused = true
		_update_silence()


## Positional sounds come from here: the world's viewport, whose camera is the listener.
func use_world(root: Node) -> void:
	_world_root = root
	for player in _world_players:
		player.reparent(root, false)


## Muffles the world outside while the player is inside a building, fading over a moment.
func set_inside(is_inside: bool) -> void:
	_muffle.is_inside = is_inside


## How silenced the game's sounds are by the pause now, 0 to 1.
func pause_amount() -> float:
	return _pause_amount


## How muffled the outside sounds are now, 0 to 1 (see Muffle).
func muffle_amount() -> float:
	return _muffle.amount


## Applies the volume sliders and the background setting of the settings.
func apply_settings(settings: GameSettings) -> void:
	for channel in CHANNEL_BUSES:
		AudioServer.set_bus_volume_db(
			AudioServer.get_bus_index(CHANNEL_BUSES[channel]),
			percent_to_db(settings.volume_percent(channel))
		)
	_is_sound_in_background = settings.sound_in_background
	_update_silence()


## Lets the player hear a volume slider of the settings: the world's sounds are silent while the
## menu is open, so a click on the UI bus (which only Master governs) plays at the slider's level
## for Effects and Ambience. Music goes on playing, so it is heard as it is.
func play_volume_test(channel: StringName, percent: float) -> void:
	if channel == &"music" or percent <= 0.0:
		return
	if _test_cooldowns.has(channel):
		_test_waiting[channel] = percent
		return
	_click_for(channel, percent)


func _click_for(channel: StringName, percent: float) -> void:
	_test_cooldowns[channel] = TEST_CLICK_SECONDS
	play(&"ui_click", null, false, 1.0 if channel == &"master" else percent / 100.0)


## Lets the sliders click again; one that was moved meanwhile clicks at its last level.
func _step_test_clicks(delta: float) -> void:
	for channel in _test_cooldowns.keys():
		_test_cooldowns[channel] -= delta
		if _test_cooldowns[channel] > 0.0:
			continue
		_test_cooldowns.erase(channel)
		if _test_waiting.has(channel):
			_click_for(channel, _test_waiting[channel])
			_test_waiting.erase(channel)


## Plays a sound event once. `position` (in the world's art pixels) makes it come from there.
## `is_from_outside` marks an effect of the world outside, which is muffled while the player is
## inside; the player's own sounds are not. `level` (0 to 1) is the share of the event's volume.
func play(
	event: StringName, position: Variant = null, is_from_outside := false, level := 1.0
) -> void:
	if not _rules.has_event(event):
		push_error("No sound event '%s'" % event)
		return
	var player := _oldest_voice_over_the_limit(event)
	if player == null:
		player = _free_player(position != null)
	if position != null:
		player.max_distance = _reach_of(event)
	_start(player, event, position, is_from_outside)
	player.volume_db += linear_to_db(level)
	if _rules.event(event).has("voices"):
		_voices[event].append(player)


## Starts a looping sound event at `level` (0 to 1) and returns its handle, to fade or stop it.
func start_loop(
	event: StringName, position: Variant = null, level := 1.0, max_distance := MAX_DISTANCE
) -> SoundLoop:
	var player: Node = AudioStreamPlayer.new() if position == null else AudioStreamPlayer2D.new()
	player.process_mode = Node.PROCESS_MODE_ALWAYS
	if position != null:
		player.max_distance = max_distance
	(self if position == null else _world_root).add_child(player)
	_start(player, event, position, false)
	return SoundLoop.new(player, _rules.event(event)["volume_db"], level)


## The player to cut off for a new play of an event that has a `voices` limit (see sounds.cfg), the
## oldest still playing it, once as many as the limit are; else null.
func _oldest_voice_over_the_limit(event: StringName) -> Node:
	var limit: int = _rules.event(event).get("voices", 0)
	if limit == 0:
		return null
	var playing: Array = _voices.get(event, []).filter(
		func(player: Node) -> bool: return player.playing and _event_of[player] == event
	)
	_voices[event] = playing
	return playing.pop_front() if playing.size() >= limit else null


## How far a positional event is heard, in art pixels: `reach_tiles` of its section in
## sounds.cfg, else MAX_DISTANCE.
func _reach_of(event: StringName) -> float:
	var reach_tiles: float = _rules.event(event).get("reach_tiles", DEFAULT_REACH_TILES)
	return reach_tiles * TerrainTileset.TILE_SIZE


func _start(player: Node, event: StringName, position: Variant, is_from_outside: bool) -> void:
	var values := _rules.event(event)
	var bus: StringName = BUS_OF_KEY[values["bus"]]
	_event_of[player] = event
	player.stream = load(_rules.pick_file(event, _rng))
	player.volume_db = values["volume_db"]
	player.pitch_scale = _rules.pick_pitch(event, _rng)
	player.bus = OUTSIDE_EFFECTS if is_from_outside and bus == EFFECTS else bus
	if position != null:
		player.position = position
	player.play()
	played.emit(event, position)


## An idle player of the pool, or else the next in turn.
func _free_player(is_in_world: bool) -> Node:
	var players: Array = _world_players if is_in_world else _plain_players
	for player: Node in players:
		if not player.playing:
			return player
	var index := _next_world if is_in_world else _next_plain
	if is_in_world:
		_next_world = (_next_world + 1) % POOL_SIZE
	else:
		_next_plain = (_next_plain + 1) % POOL_SIZE
	return players[index]


func _update_silence() -> void:
	AudioServer.set_bus_mute(
		AudioServer.get_bus_index(MASTER),
		is_muted or is_silenced(_is_sound_in_background, _is_focused)
	)


## Makes the buses (unless they exist: another service made them) and puts a low-pass filter on
## and an amplifier (to turn the volume down) on the two that are muffled, and an amplifier on
## Game to silence it while paused.
func _set_up_buses() -> void:
	for bus in [GAME, EFFECTS, AMBIENCE, MUSIC, UI, OUTSIDE_EFFECTS]:
		if AudioServer.get_bus_index(bus) != -1:
			continue
		AudioServer.add_bus()
		var index := AudioServer.bus_count - 1
		AudioServer.set_bus_name(index, bus)
		AudioServer.set_bus_send(index, SEND_OF_BUS.get(bus, MASTER))
		if bus == GAME:
			AudioServer.add_bus_effect(index, AudioEffectAmplify.new())
		if bus == AMBIENCE or bus == OUTSIDE_EFFECTS:
			AudioServer.add_bus_effect(index, AudioEffectLowPassFilter.new())
			AudioServer.add_bus_effect(index, AudioEffectAmplify.new())
	_pause_amplifier = AudioServer.get_bus_effect(AudioServer.get_bus_index(GAME), 0)
	for bus in [AMBIENCE, OUTSIDE_EFFECTS]:
		var index := AudioServer.get_bus_index(bus)
		for effect_index in AudioServer.get_bus_effect_count(index):
			var effect := AudioServer.get_bus_effect(index, effect_index)
			if effect is AudioEffectLowPassFilter:
				_low_passes.append(effect as AudioEffectLowPassFilter)
			elif effect is AudioEffectAmplify:
				_amplifiers.append(effect as AudioEffectAmplify)
