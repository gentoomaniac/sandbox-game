extends Node2D
## The game scene: owns the GameState, turns real time into game minutes and feeds the
## player's input to the state. The camera and chunk streaming follow the player.
##
## Debug flags (after `--` on the Godot command line, see `make screenshot`):
## `--at=<x>,<y>` puts the player on that world tile instead of at the camp;
## `--screenshot=<path>` saves one frame as PNG once streaming has settled, then quits;
## `--time=<hh:mm>` sets the time of day; `--field=<x>,<y>` tills a small field there with
## crops in every growth stage (see DebugField); `--inside` walks into the first house as soon
## as one exists (see `--house`). BuildMode parses `--ghost=<x>,<y>` and
## `--house=<x>,<y>` (see there).

const WORLD_SEED := 1
## One game day lasts 16 real minutes (24 h * 60 min / 1.5 / 60 s).
const GAME_MINUTES_PER_REAL_SECOND := 1.5
## Debug speed-up, toggled with F2: a game day in 16 real seconds.
const FAST_FORWARD_FACTOR := 60.0
## Frames to wait before a screenshot once the scene is ready.
const SCREENSHOT_SETTLE_FRAMES := 3
## Fading out and back in around sleep and doors.
const SLEEP_FADE_SECONDS := 0.5

var _state := GameState.new_game(WORLD_SEED)
var _player_view := PlayerView.new()
var _use_highlight := UseHighlight.new()
var _harvest_hud := HarvestHud.new()
var _interior_view := InteriorView.new()
var _screenshot_path := ""
var _fast_forward := false
var _is_fading := false
var _enter_first_house := false
var _settled_frames := 0
var _pending_minutes := 0.0

@onready var _view: WorldView = $WorldView
@onready var _camera: Camera2D = $Camera2D
@onready var _tint: DayNightTint = $DayNightTint
@onready var _hud: ClockHud = $ClockHud
@onready var _fade: ColorRect = $FadeLayer/Fade
@onready var _build_mode: BuildMode = $BuildMode


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--at="):
			var tile := arg.trim_prefix("--at=").split_floats(",")
			_state.player.position = Vector2(tile[0], tile[1]) + Vector2(0.5, 0.5)
		elif arg.begins_with("--screenshot="):
			_screenshot_path = arg.trim_prefix("--screenshot=")
		elif arg.begins_with("--time="):
			_set_start_time(arg.trim_prefix("--time="))
		elif arg.begins_with("--field="):
			var tile := arg.trim_prefix("--field=").split_floats(",")
			DebugField.create(_state.world, Vector2i(int(tile[0]), int(tile[1])))
		elif arg == "--inside":
			_enter_first_house = true
	_view.show_world(_state.world)
	_build_mode.world = _state.world
	# Among the objects, so the player walks behind tree canopies.
	_view.entities.add_child(_player_view)
	_player_view.show_player(_state.player)
	_view.add_child(_use_highlight)
	_use_highlight.show_for(_state)
	add_child(_harvest_hud)
	_interior_view.hide()
	add_child(_interior_view)
	_show_clock()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_fast_forward"):
		_fast_forward = not _fast_forward
	elif event.is_action_pressed("interact") and not _is_fading:
		_try_sleep()
	elif event.is_action_pressed("use") and not _is_fading and not _build_mode.is_active():
		if _state.use_facing_tile() == GameState.Use.HARVEST:
			_harvest_hud.show_harvest(GameState.CROP, _state.harvest_count)


func _process(delta: float) -> void:
	_tick_clock(delta)
	if not _is_fading:
		var direction := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
		_state.player.move(_state.current_map, direction, delta)
		if _state.door_underfoot():
			_fade_through(_pass_door)
	_camera.position = (_state.player.position * TerrainTileset.TILE_SIZE).round()
	if not _state.is_inside():
		_view.set_focus(_state.player.tile())
	if _enter_first_house:
		_enter_first_house_now()
	if _screenshot_path != "":
		# A few frames after everything is in place, for tile maps to catch up.
		_settled_frames = _settled_frames + 1 if _is_ready_to_shoot() else 0
		if _settled_frames > SCREENSHOT_SETTLE_FRAMES:
			_save_screenshot_and_quit()


## Real time to whole game minutes; the fraction carries over to the next frame.
func _tick_clock(delta: float) -> void:
	# A screenshot with TIME=... must show exactly that time.
	if _screenshot_path != "":
		return
	var rate := GAME_MINUTES_PER_REAL_SECOND * (FAST_FORWARD_FACTOR if _fast_forward else 1.0)
	_pending_minutes += delta * rate
	var whole_minutes := int(_pending_minutes)
	if whole_minutes > 0:
		_pending_minutes -= whole_minutes
		_state.clock.advance(whole_minutes)
		_show_clock()


func _try_sleep() -> void:
	var bed := _state.bed_in_reach()
	if bed == null:
		return
	_fade_through(
		func() -> void:
			_state.sleep_in(bed)
			_show_clock()
	)


## Fades to black, runs `change` while the screen is black, and fades back in.
func _fade_through(change: Callable) -> void:
	_is_fading = true
	var fade := create_tween()
	fade.tween_property(_fade, "color:a", 1.0, SLEEP_FADE_SECONDS)
	await fade.finished
	change.call()
	fade = create_tween()
	fade.tween_property(_fade, "color:a", 0.0, SLEEP_FADE_SECONDS)
	await fade.finished
	_is_fading = false


func _pass_door() -> void:
	_state.pass_door()
	_show_current_map()


## Shows the map the player is on: the world, or the interior (which pauses the world's
## chunk streaming, leaving it as it is).
func _show_current_map() -> void:
	var is_inside := _state.is_inside()
	_build_mode.cancel()
	_build_mode.process_mode = PROCESS_MODE_DISABLED if is_inside else PROCESS_MODE_INHERIT
	_view.visible = not is_inside
	_view.process_mode = PROCESS_MODE_DISABLED if is_inside else PROCESS_MODE_INHERIT
	_interior_view.visible = is_inside
	if is_inside:
		_interior_view.show_interior(_state.current_map)
	_player_view.reparent(_interior_view.entities if is_inside else _view.entities, false)
	_show_clock()


## Debug: waits for the first house and the world around, then walks in without a fade.
func _enter_first_house_now() -> void:
	var houses := _state.world.buildings()
	if houses.is_empty() or not _view.is_settled:
		return
	_enter_first_house = false
	_state.player.position = Vector2(houses[0].door_tile()) + Vector2(0.5, 0.5)
	_pass_door()


func _set_start_time(text: String) -> void:
	var parts := text.split(":")
	if parts.size() != 2 or not parts[0].is_valid_int() or not parts[1].is_valid_int():
		push_error("--time expects hh:mm, got '%s'" % text)
		return
	var hour := int(parts[0])
	var minute := int(parts[1])
	if hour < 0 or hour > 23 or minute < 0 or minute > 59:
		push_error("--time out of range: '%s'" % text)
		return
	_state.clock.set_time(hour, minute)


func _is_ready_to_shoot() -> bool:
	return _view.is_settled and not _enter_first_house


func _show_clock() -> void:
	if _state.is_inside():
		_tint.show_interior()
	else:
		_tint.show_time(_state.clock)
	_view.set_light_strength(_tint.light_strength())
	_hud.show_time(_state.clock)


func _save_screenshot_and_quit() -> void:
	# Draws now instead of waiting for the next frame, which never comes while the window
	# can't be shown (e.g. a locked screen).
	RenderingServer.force_draw(false)
	get_viewport().get_texture().get_image().save_png(_screenshot_path)
	get_tree().quit()
