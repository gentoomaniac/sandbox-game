extends Node2D
## The game scene: owns the GameState, turns real time into game minutes and feeds the
## player's input to the state. The world is drawn into WorldViewport (one art pixel per
## pixel) and shown on the window by CameraController; the UI is drawn on the window itself.
## The camera and chunk streaming follow the player.
##
## The game is loaded from the save at start and saved after sleeping and on quit (see
## SaveFile). Flags after `--` on the Godot command line (see `make screenshot`):
## `--new-game` ignores the save; `--save-path=<file>` uses another save file;
## `--settings-path=<file>` uses another settings file (see GameSettings). Debug flags:
## `--at=<x>,<y>` puts the player on that world tile instead of at the camp;
## `--energy=<n>` and `--health=<n>` start with that much (0 to 100);
## `--screenshot=<path>` saves one frame as PNG once streaming has settled, then quits;
## `--screenshot-delay=<s>` waits that many real seconds after that, with the clock running
## (to see what a midnight changes, e.g. `--day=30 --time=23:50 --screenshot-delay=10`);
## `--day=<n>` sets the day number (days 1, 31, 61 and 91 are the first day of each season);
## `--time=<hh:mm>` sets the time of day; `--field=<x>,<y>` tills a small field there with
## crops in every growth stage (see DebugField); `--inside` walks into the first house as soon
## as one exists (see `--house`); `--forage=<x>,<y>` puts a stump, bushes and a sapling in a
## row from there and some of every new item in the inventory (see DebugForage);
## `--console=<line>;<line>` runs those console commands at start and leaves the console
## open (see ConsoleView); `--zoom=<z>` sets the camera zoom; `--coordinates` shows the
## coordinates (F3); `--inventory` opens the character screen at start;
## `--wear=<item>` puts a wearable item on (`straw_hat`, `shirt`, ...);
## `--weather=<condition>` forces the weather (`clear`, `rain`, `snow`, `fog`, `wind`, `storm`,
## `thunder`; see WeatherView), `--flash` keeps the flash of lightning on;
## `--mouse-tile=<x>,<y>` pretends the mouse is always on that tile (for screenshots);
## `--camera-shift=<x>,<y>` moves the camera by that many art pixels, fractions included
## (to check smooth scrolling); `--menu=pause|settings|controls|display|game` opens that menu page
## (with `--screenshot`, the shot is of the menu). PlayerView parses `--hair=<n>` and
## `--pose=<direction>`, and F6 cycles the hair (see there). BuildMode parses
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
var _settings: GameSettings
var _menu: PauseMenu
var _save_path := SaveFile.DEFAULT_PATH
var _settings_path := GameSettings.DEFAULT_PATH
var _debug_menu_page := -1
var _player_view := PlayerView.new()
var _use_highlight := UseHighlight.new()
var _harvest_hud := HarvestHud.new()
var _coordinates_hud := CoordinatesHud.new()
var _hotbar := HotbarHud.new()
var _vitals := VitalsHud.new()
var _character_screen := CharacterScreen.new()
var _console_view := ConsoleView.new()
var _cheat_hud := CheatHud.new()
var _start_console_lines := PackedStringArray()
var _interior_view := InteriorView.new()
var _weather_view := WeatherView.new()
var _screenshot_path := ""
var _fast_forward := false
var _is_fading := false
var _enter_first_house := false
var _open_character_screen_at_start := false
var _settled_frames := 0
var _screenshot_delay := 0.0
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
	if not EnergyRules.default_rules().is_valid() or not Vegetation.default_vegetation().is_valid():
		# The load has reported the missing rules or curves. Nothing else runs before the quit.
		set_process(false)
		set_process_unhandled_input(false)
		get_tree().quit(1)
		return
	_settings = _load_settings()
	_apply_ui_scale(_settings.ui_scale)
	_settings.ui_scale_changed.connect(_apply_ui_scale)
	_state = _load_or_start_game()
	_state.energy_drain = _settings.energy_drain_factor()
	_settings.drain_changed.connect(
		func() -> void: _state.energy_drain = _settings.energy_drain_factor()
	)
	_state.sun.variation = _settings.day_length_variation_factor()
	_tint.sun = _state.sun
	_settings.day_length_changed.connect(
		func() -> void:
			_state.sun.variation = _settings.day_length_variation_factor()
			_show_clock()
	)
	# Quitting saves first (see _notification).
	get_tree().auto_accept_quit = false
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--at="):
			var tile := arg.trim_prefix("--at=").split_floats(",")
			_state.player.position = Vector2(tile[0], tile[1]) + Vector2(0.5, 0.5)
		elif arg.begins_with("--screenshot="):
			_screenshot_path = arg.trim_prefix("--screenshot=")
		elif arg.begins_with("--screenshot-delay="):
			_screenshot_delay = float(arg.trim_prefix("--screenshot-delay="))
		elif arg.begins_with("--day="):
			_state.clock.day = maxi(int(arg.trim_prefix("--day=")), 1)
		elif arg.begins_with("--time="):
			_set_start_time(arg.trim_prefix("--time="))
		elif arg.begins_with("--field="):
			var tile := arg.trim_prefix("--field=").split_floats(",")
			DebugField.create(_state.world, Vector2i(int(tile[0]), int(tile[1])))
		elif arg.begins_with("--forage="):
			var tile := arg.trim_prefix("--forage=").split_floats(",")
			DebugForage.create(_state, Vector2i(int(tile[0]), int(tile[1])))
		elif arg.begins_with("--energy="):
			_state.player.energy = float(arg.trim_prefix("--energy="))
		elif arg.begins_with("--health="):
			_state.player.health = float(arg.trim_prefix("--health="))
		elif arg == "--coordinates":
			_coordinates_hud.toggle()
		elif arg.begins_with("--wear="):
			var item := StringName(arg.trim_prefix("--wear="))
			_state.player.equipment.equip(Equipment.slot_of(item), item)
		elif arg == "--inside":
			_enter_first_house = true
		elif arg == "--inventory":
			_open_character_screen_at_start = true
		elif arg.begins_with("--console="):
			_start_console_lines = arg.trim_prefix("--console=").split(";")
		elif arg.begins_with("--zoom="):
			_start_zoom = float(arg.trim_prefix("--zoom="))
		elif arg.begins_with("--mouse-tile="):
			var tile := arg.trim_prefix("--mouse-tile=").split_floats(",")
			_use_highlight.debug_mouse_tile = Vector2i(int(tile[0]), int(tile[1]))
		elif arg.begins_with("--menu="):
			_debug_menu_page = PauseMenu.Page.get(arg.trim_prefix("--menu=").to_upper(), -1)
		elif arg.begins_with("--weather="):
			_force_weather(StringName(arg.trim_prefix("--weather=")))
		elif arg == "--flash":
			_weather_view.is_flash_held = true
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
	add_child(_coordinates_hud)
	add_child(_hotbar)
	_hotbar.show_inventory(_state.player.inventory)
	add_child(_vitals)
	_vitals.show_state(_state)
	add_child(_character_screen)
	_character_screen.show_player(_state.player)
	if _open_character_screen_at_start:
		_character_screen.toggle()
	add_child(_cheat_hud)
	_cheat_hud.show_cheats(_state.cheats)
	add_child(_console_view)
	_console_view.show_state(_state)
	# A teleport moves the player far: the camera jumps with them instead of gliding.
	_console_view.command_ran.connect(
		func() -> void:
			_camera.rig.follow(_camera_target)
			_show_clock()
	)
	if not _start_console_lines.is_empty():
		_console_view.open()
		for line in _start_console_lines:
			_console_view.run_line(line)
	_menu = PauseMenu.new(_settings)
	_menu.resumed.connect(_resume)
	_menu.save_and_quit_requested.connect(_save_and_quit)
	add_child(_menu)
	_interior_view.hide()
	_world.add_child(_interior_view)
	_world.add_child(_weather_view)
	_show_clock()
	if _state.is_inside():
		_show_current_map()
	# A save made during the fade out has no energy left: finish the pass-out.
	if _state.is_out_of_energy():
		_pass_out()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_save_game()
		get_tree().quit()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("console") and _can_open_console():
		# The key that opens it must not be typed into the input line.
		get_viewport().set_input_as_handled()
		# BuildMode would still get clicks meant for the console.
		_build_mode.cancel()
		_console_view.open()
		return
	if event.is_action_pressed("pause"):
		# Escape closes the console, then the character screen, then leaves build mode, then opens
		# the menu.
		if _console_view.is_open():
			_console_view.close()
		elif _character_screen.is_open():
			_character_screen.toggle()
		elif _build_mode.is_active():
			_build_mode.cancel()
		else:
			_open_menu()
		return
	# The open console takes the input: the player neither walks nor acts.
	if _console_view.is_open():
		return
	# Decided before BuildMode sees the event: the click that places a house ends build mode,
	# and must not also be a use click.
	var can_use := _can_use()
	if event.is_action_pressed("inventory") and not _is_fading:
		_character_screen.toggle()
		return
	# The open character screen takes the input: the player neither walks nor acts.
	if _character_screen.is_open():
		return
	# A SubViewport only gets the events that are pushed into it. That does not mark the
	# event as handled here, so Main still sees what BuildMode consumed.
	_world.push_input(event)
	var hotbar_slot := _hotbar_slot_of(event)
	if event.is_action_pressed("toggle_coordinates"):
		_coordinates_hud.toggle()
	elif event.is_action_pressed("toggle_fast_forward"):
		_fast_forward = not _fast_forward
	elif hotbar_slot != -1:
		_state.player.inventory.select(hotbar_slot)
	elif event.is_action_pressed("interact") and not _is_fading:
		_try_sleep()
	elif _is_use_event(event) and can_use and _eat_held():
		pass  # Eating needs no target: a held food is eaten instead of used on a tile.
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
	var weather := _state.current_weather()
	_weather_view.show_weather(weather, _tint.color)
	_coordinates_hud.show_position(
		_state.player.tile(), _state.is_inside(), _weather_and_sun_text(weather)
	)
	_use_highlight.is_enabled = (
		not _build_mode.is_active()
		and not _state.is_inside()
		and not _character_screen.is_open()
		and not _console_view.is_open()
	)
	if not _is_fading:
		var direction := Vector2.ZERO
		if not _character_screen.is_open() and not _console_view.is_open():
			direction = Input.get_vector("move_left", "move_right", "move_up", "move_down")
		_state.player.move(_state.current_map, direction, delta, _state.walk_speed_factor())
		if _state.door_underfoot():
			_fade_through(_pass_door)
	if not _state.is_inside():
		_view.player_feet = _player_view.position
		_view.set_focus(_state.player.tile())
	if _enter_first_house:
		_enter_first_house_now()
	if _screenshot_path != "" and _debug_menu_page >= 0:
		_open_debug_menu_when_ready()
	elif _screenshot_path != "":
		# A few frames after everything is in place, for tile maps to catch up.
		_settled_frames = _settled_frames + 1 if _is_ready_to_shoot() else 0
		if _settled_frames > SCREENSHOT_SETTLE_FRAMES:
			_screenshot_delay -= delta
			if _screenshot_delay <= 0.0:
				_save_screenshot_and_quit()


func _open_menu(page := PauseMenu.Page.PAUSE) -> void:
	get_tree().paused = true
	_menu.open(page)


func _resume() -> void:
	get_tree().paused = false


func _save_and_quit() -> void:
	_save_game()
	get_tree().quit()


## Debug: opens the menu once the world is drawn, then takes the screenshot. The game is
## paused by then, so a timer that ignores the pause does the waiting.
func _open_debug_menu_when_ready() -> void:
	_settled_frames = _settled_frames + 1 if _is_ready_to_shoot() else 0
	if _settled_frames > SCREENSHOT_SETTLE_FRAMES:
		_open_menu(_debug_menu_page as PauseMenu.Page)
		_debug_menu_page = -1
		get_tree().create_timer(0.2, true).timeout.connect(_save_screenshot_and_quit)


## Eats the held food, if any, and says how much energy it gave. Returns whether it ate.
func _eat_held() -> bool:
	var energy_before := _state.player.energy
	if not _state.eat_held():
		return false
	_harvest_hud.show_note("+%s energy" % roundi(_state.player.energy - energy_before))
	return true


func _is_use_event(event: InputEvent) -> bool:
	return event.is_action_pressed("use") or event.is_action_pressed("use_click")


func _can_open_console() -> bool:
	return not _console_view.is_open() and not get_tree().paused and not _is_fading


func _can_use() -> bool:
	return not _is_fading and not _build_mode.is_active()


## The hotbar slot (0 to 9) whose key `event` presses, or -1.
func _hotbar_slot_of(event: InputEvent) -> int:
	for slot in Inventory.HOTBAR_SIZE:
		if event.is_action_pressed("hotbar_%d" % (slot + 1)):
			return slot
	return -1


## Uses the targeted tile if the player can reach it.
func _use_on(target: Targeting) -> void:
	if not target.is_in_reach:
		return
	match _state.use_tile(target.tile):
		GameState.Use.HARVEST:
			var crop_name: String = ItemTypes.TYPES[ItemTypes.TURNIP]["name"]
			_harvest_hud.show_note("+1 %s" % crop_name.to_lower())
		GameState.Use.NEEDS_BETTER_TOOL:
			var tool_name: String = ItemTypes.TYPES[_state.player.inventory.held_item()]["name"]
			_harvest_hud.show_note("Needs a better %s." % tool_name.to_lower())
		GameState.Use.INVENTORY_FULL:
			_harvest_hud.show_note("Inventory full")
	if _state.is_out_of_energy():
		_pass_out()


## Out of energy: fades out, and the player wakes in their home bed the next morning.
func _pass_out() -> void:
	_harvest_hud.show_note("You passed out")
	_fade_through(
		func() -> void:
			_state.pass_out()
			_show_current_map()
			_save_game()
	)


## Where the camera looks. The player is drawn on the art pixel grid (rounded), the camera
## is not, so the world scrolls smoothly and the player wobbles by up to half an art pixel
## against the screen (the user chose this over a pixel-locked camera).
func _camera_target() -> Vector2:
	return _state.player.position * TerrainTileset.TILE_SIZE + _camera_shift


## Real time to whole game minutes; the fraction carries over to the next frame.
func _tick_clock(delta: float) -> void:
	# A screenshot with TIME=... must show exactly that time, unless it is told to wait.
	if _screenshot_path != "" and _screenshot_delay == 0.0:
		return
	var rate := GAME_MINUTES_PER_REAL_SECOND * (FAST_FORWARD_FACTOR if _fast_forward else 1.0)
	_pending_minutes += delta * rate
	var whole_minutes := int(_pending_minutes)
	if whole_minutes > 0:
		_pending_minutes -= whole_minutes
		_state.clock.advance(whole_minutes)
		_weather_view.minutes_passed(whole_minutes)
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
	# No command runs during a fade: a teleport would meet a door half way through.
	_console_view.close()
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
	_weather_view.visible = not is_inside
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


## The settings, with the player's key bindings applied to the input map. `--settings-path=`
## picks another file (to keep tests and screenshots off the real one).
func _load_settings() -> GameSettings:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--settings-path="):
			_settings_path = arg.trim_prefix("--settings-path=")
	var settings := GameSettings.new(_settings_path)
	settings.load_file()
	return settings


## Scales the whole window's 2D canvas, the UI included. The world screen is a full-rect
## TextureRect drawn through UV, so it keeps filling the window and the world view is unchanged.
func _apply_ui_scale(ui_scale: float) -> void:
	get_tree().root.content_scale_factor = ui_scale


func _save_game() -> void:
	SaveFile.write(_state, _save_path)


func _force_weather(condition: StringName) -> void:
	if not Weather.FORCEABLE.has(condition):
		push_error("--weather expects one of %s, got '%s'" % [Weather.FORCEABLE, condition])
		return
	_state.weather_override = condition


## The F3 lines on the weather: the values, and sunrise and sunset.
func _weather_and_sun_text(weather: WeatherSample) -> String:
	var day := _state.clock.day
	return (
		"%s\nsunrise %s · sunset %s"
		% [
			weather.short_text(),
			Sun.time_text(_state.sun.sunrise(day)),
			Sun.time_text(_state.sun.sunset(day)),
		]
	)


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
		_tint.show_time(_state.clock, _state.current_weather().cloud_cover)
	_view.set_light_strength(_tint.light_strength())
	_view.set_season(_state.clock.season())
	_view.refresh_vegetation()
	_build_mode.set_season(_state.clock.season())
	_hud.show_time(_state.clock)


func _save_screenshot_and_quit() -> void:
	# Draws now instead of waiting for the next frame, which never comes while the window
	# can't be shown (e.g. a locked screen).
	RenderingServer.force_draw(false)
	# The window as the player sees it, not only the world viewport.
	get_viewport().get_texture().get_image().save_png(_screenshot_path)
	get_tree().quit()
