extends Node2D
## The game scene: owns the GameState, turns real time into game minutes and feeds the
## player's input to the state. The world is drawn into WorldViewport (one art pixel per
## pixel) and shown on the window by CameraController; the UI is drawn on the window itself.
## The camera and chunk streaming follow the player.
##
## The game is loaded from the save at start and saved after sleeping and on quit (see
## SaveFile). Flags after `--` on the Godot command line (see `make screenshot`):
## `--new-game` ignores the save; `--save-path=<file>` uses another save file. Debug flags:
## `--at=<x>,<y>` puts the player on that world tile instead of at the camp;
## `--screenshot=<path>` saves one frame as PNG once streaming has settled, then quits;
## `--time=<hh:mm>` sets the time of day; `--field=<x>,<y>` tills a small field there with
## crops in every growth stage (see DebugField); `--inside` walks into the first house as soon
## as one exists (see `--house`); `--zoom=<z>` sets the camera zoom;
## `--mouse-tile=<x>,<y>` pretends the mouse is always on that tile (for screenshots);
## `--camera-shift=<x>,<y>` moves the camera by that many art pixels, fractions included
## (to check smooth scrolling). PlayerView parses `--outfit=<n>` and
## `--pose=<direction>`, and F6 cycles the outfit (see there). BuildMode parses
## `--ghost=<x>,<y>` and `--house=<x>,<y>` (see there).

const WORLD_SEED := 1
## One game day lasts 16 real minutes (24 h * 60 min / 1.5 / 60 s).
const GAME_MINUTES_PER_REAL_SECOND := 1.5
## Debug speed-up, toggled with F2: a game day in 16 real seconds.
const FAST_FORWARD_FACTOR := 60.0
## Frames to wait before a screenshot once the scene is ready.
const SCREENSHOT_SETTLE_FRAMES := 3
## Fading out and back in around sleep and doors.
const SLEEP_FADE_SECONDS := 0.5

var _state: GameState
var _save_path := SaveFile.DEFAULT_PATH
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
var _camera_shift := Vector2.ZERO
var _start_zoom := 1.0

@onready var _world: SubViewport = $WorldViewport
@onready var _view: WorldView = $WorldViewport/WorldView
@onready var _tint: DayNightTint = $WorldViewport/DayNightTint
@onready var _build_mode: BuildMode = $WorldViewport/BuildMode
@onready var _camera: CameraController = $CameraController
@onready var _hud: ClockHud = $ClockHud
@onready var _message: Label = $MessageHud/Message
@onready var _fade: ColorRect = $FadeLayer/Fade


func _ready() -> void:
	_state = _load_or_start_game()
	# Quitting saves first (see _notification).
	get_tree().auto_accept_quit = false
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
		elif arg.begins_with("--zoom="):
			_start_zoom = float(arg.trim_prefix("--zoom="))
		elif arg.begins_with("--mouse-tile="):
			var tile := arg.trim_prefix("--mouse-tile=").split_floats(",")
			_use_highlight.debug_mouse_tile = Vector2i(int(tile[0]), int(tile[1]))
		elif arg.begins_with("--camera-shift="):
			var shift := arg.trim_prefix("--camera-shift=").split_floats(",")
			_camera_shift = Vector2(shift[0], shift[1])
	_view.show_world(_state.world)
	_build_mode.world = _state.world
	_build_mode.camera = _camera
	_build_mode.message_changed.connect(_show_build_message)
	_camera.rig.follow(_camera_target)
	_camera.rig.set_zoom_clamped(_start_zoom)
	# Among the objects, so the player walks behind tree canopies.
	_view.entities.add_child(_player_view)
	_player_view.show_player(_state.player)
	_view.add_child(_use_highlight)
	_use_highlight.show_for(_state, _camera)
	add_child(_harvest_hud)
	_interior_view.hide()
	_world.add_child(_interior_view)
	_show_clock()
	if _state.is_inside():
		_show_current_map()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_save_game()
		get_tree().quit()


func _unhandled_input(event: InputEvent) -> void:
	# Decided before BuildMode sees the event: the click that places a house ends build mode,
	# and must not also be a use click.
	var can_use := _can_use()
	# A SubViewport only gets the events that are pushed into it. That does not mark the
	# event as handled here, so Main still sees what BuildMode consumed.
	_world.push_input(event)
	if event.is_action_pressed("toggle_fast_forward"):
		_fast_forward = not _fast_forward
	elif event.is_action_pressed("interact") and not _is_fading:
		_try_sleep()
	elif event.is_action_pressed("use") and can_use:
		_use_on(_use_highlight.targeting())
	elif event.is_action_pressed("use_click") and can_use:
		var target := _use_highlight.targeting()
		if target.source == Targeting.Source.MOUSE:
			_use_on(target)
		# A click also counts as the mouse being in use. One that wakes an idle mouse (the target
		# is then the facing tile) does not act.
		_use_highlight.note_mouse_activity()


func _process(delta: float) -> void:
	_tick_clock(delta)
	_use_highlight.is_enabled = not _build_mode.is_active() and not _state.is_inside()
	if not _is_fading:
		var direction := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
		_state.player.move(_state.current_map, direction, delta)
		if _state.door_underfoot():
			_fade_through(_pass_door)
	if not _state.is_inside():
		_view.player_feet = _player_view.position
		_view.set_focus(_state.player.tile())
	if _enter_first_house:
		_enter_first_house_now()
	if _screenshot_path != "":
		# A few frames after everything is in place, for tile maps to catch up.
		_settled_frames = _settled_frames + 1 if _is_ready_to_shoot() else 0
		if _settled_frames > SCREENSHOT_SETTLE_FRAMES:
			_save_screenshot_and_quit()


func _can_use() -> bool:
	return not _is_fading and not _build_mode.is_active()


## Uses the targeted tile if the player can reach it.
func _use_on(target: Targeting) -> void:
	if target.is_in_reach and _state.use_tile(target.tile) == GameState.Use.HARVEST:
		_harvest_hud.show_harvest(GameState.CROP, _state.harvest_count)


## Where the camera looks. The player is drawn on the art pixel grid (rounded), the camera
## is not, so the world scrolls smoothly and the player wobbles by up to half an art pixel
## against the screen (the user chose this over a pixel-locked camera).
func _camera_target() -> Vector2:
	return _state.player.position * TerrainTileset.TILE_SIZE + _camera_shift


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
			_save_game()
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


## The saved game, or a new one if there is no save or `--new-game` is given. `--save-path=`
## picks another save file (to keep tests and screenshots off the real one). The first
## autosave after `--new-game` replaces the old save.
func _load_or_start_game() -> GameState:
	var is_new_game := false
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--save-path="):
			_save_path = arg.trim_prefix("--save-path=")
		elif arg == "--new-game":
			is_new_game = true
	var saved := null if is_new_game else SaveFile.read(_save_path)
	return saved if saved != null else GameState.new_game(WORLD_SEED)


func _save_game() -> void:
	SaveFile.write(_state, _save_path)


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
	# The world is not streamed while the player is inside.
	return (_view.is_settled or _state.is_inside()) and not _enter_first_house


func _show_build_message(text: String) -> void:
	_message.text = text


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
	# The window as the player sees it, not only the world viewport.
	get_viewport().get_texture().get_image().save_png(_screenshot_path)
	get_tree().quit()
