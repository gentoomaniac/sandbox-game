extends Node2D
## The game scene: owns the GameState, turns real time into game minutes and feeds the
## player's input to the state. The world is drawn into WorldViewport (one art pixel per
## pixel) and shown on the window by CameraController; the UI is drawn on the window itself.
## The camera and chunk streaming follow the player.
##
## The game is loaded from the save at start and saved after sleeping, after passing out and on
## quit (see SaveFile). Flags after `--` on the Godot command line (see `make screenshot`):
## `--new-game` ignores the save; `--save-path=<file>` uses another save file;
## `--settings-path=<file>` uses another settings file (see GameSettings). Debug flags:
## `--at=<x>,<y>` puts the player on that world tile instead of at the camp;
## `--ghost=<x>,<y>` holds the hammer (see BuildMode), `--building=<id>` picks the building it
## places; `--energy=<n>` and `--health=<n>` start with that much (0 to 100);
## `--screenshot=<path>` saves one frame as PNG once streaming has settled, then quits;
## `--screenshot-delay=<s>` waits that many real seconds after that, with the clock running
## (to see what a midnight changes, e.g. `--day=30 --time=23:50 --screenshot-delay=10`);
## `--day=<n>` sets the day number (days 1, 31, 61 and 91 are the first day of each season);
## `--time=<hh:mm>` sets the time of day; `--field=<x>,<y>` tills a small field there with
## crops in every growth stage (see DebugField); `--inside` walks into the first house as soon
## as one exists (see `--house`); `--drops=<x>,<y>` leaves what a felled tree, a mined stone, a
## harvested crop and a picked bush drop (see DebugDrops); `--forage=<x>,<y>` puts a stump,
## bushes and a sapling in a row from there and some of every new item in the inventory
## (see DebugForage); `--felled=<x>,<y>` shows trees felled from each side, with their stumps and
## trunks, and tree seeds on the ground (see DebugFelled);
## `--harvest=<x>,<y>` fells two oaks, cuts a trunk, breaks a stone and mows a patch in a row from
## that tile once the world is drawn, to catch the falling trees and the hopping items (see
## DebugHarvest; use `--day=45` and `--screenshot-delay=0.3`, say, and `--at=` ten tiles right of
## the tile);
## `--mow=<x>,<y>` mows twice with the scythe from that tile, leaving mown patches and hay
## (see DebugMow; with `--day=45` for summer);
## `--console=<line>;<line>` runs those console commands at start and leaves the console
## open (see ConsoleView); `--zoom=<z>` sets the camera zoom; `--coordinates` shows the
## coordinates (F3); `--inventory` opens the character screen at start, `--crafting` the
## crafting menu; `--hold=<item>` puts 5 of an item in the inventory and holds it (`chest`, say, to
## see its ghost, with `--mouse-tile`); `--chest=<x>,<y>` puts a chest with some items on that tile
## (see DebugChest), `--chest-inside=<x>,<y>` one inside the first house, on that tile of its
## room (with `--inside`), and `--storage` opens the storage screen of that chest at start;
## `--wear=<item>` puts a wearable item on (`straw_hat`, `shirt`, ...);
## `--weather=<condition>` forces the weather (`clear`, `rain`, `snow`, `fog`, `wind`, `storm`,
## `thunder`; see WeatherView), `--flash` keeps the flash of lightning on, `--snow=<0..1>` forces
## the snow cover;
## `--mouse-tile=<x>,<y>` pretends the mouse is always on that tile (for screenshots);
## `--camera-shift=<x>,<y>` moves the camera by that many art pixels, fractions included
## (to check smooth scrolling); `--menu=pause|settings|controls|display|game|audio` opens that menu
## page (with `--screenshot`, the shot is of the menu). The console's `snow <0..1>` forces the snow
## cover (`snow auto` ends it), and F3 shows the snow cover and the frost.
## `--tooltip=<id>` shows the tooltip of a control as if the mouse rested on it: `hotbar_<0..9>`,
## `inventory_<n>` and `equipment_<slot>` (with `--inventory`), `recipe_<id>` (with `--crafting`),
## `inventory_<n>` and `chest_<n>` (with `--storage`), `setting_ui_scale` and
## `setting_day_length` (with `--menu=game`), `setting_master_volume`, `setting_effects_volume`,
## `setting_ambience_volume` and `setting_sound_in_background` (with `--menu=audio`),
## `action_<action>` (with `--menu=controls`).
## `--sound-log` prints every sound event as it plays (see AudioService).
## `--mute` silences all sound (events still play and log); `--background` makes the window
## unfocusable, so it can't take the focus but takes no keyboard input at all: not for playing.
## Both are for test runs (`make screenshot` passes them).
## `--wildlife=<kind>[,<kind>]` puts a few animals of those kinds near the player once the
## world is drawn and leaves it at that (`bird`, `rabbit`, `squirrel`, `deer`, `bee`,
## `butterfly`, `flock`; see WildlifeView), `--wildlife-calm` makes them take no notice of the
## player; `--hit=<x>,<y>` hits the object on that tile once, without damage, as soon as the
## world is drawn (to see its shake and what flies off, see HitEffect, and the sweat of a tired
## player; the particles last about a second, so use a short `--screenshot-delay`). `--hit`
## throws sweat only for a tired player: add `--energy=15`, say. `--sleep` goes to bed as soon
## as the world is drawn (a new game starts beside the sleeping bag); `--energy=0` passes out at
## start, and `--time=00:59` with a `--screenshot-delay` of a second or more stays up too late
## (see `_pass_out`). PlayerView parses `--hair=<n>` and `--pose=<direction>`, and F6 cycles the
## hair (see there). BuildMode parses `--ghost=<x>,<y>` and `--house=<x>,<y>` (see there).

const WORLD_SEED := 1
## The build ghost has snow on its roof while the snow cover is above this.
const SNOWY_GHOST_COVER := 0.5
## One game day lasts 16 real minutes (24 h * 60 min / 1.5 / 60 s).
const GAME_MINUTES_PER_REAL_SECOND := 1.5
## Debug speed-up, toggled with F2: a game day in 16 real seconds.
const FAST_FORWARD_FACTOR := 60.0
## Frames to wait before a screenshot once the scene is ready.
const SCREENSHOT_SETTLE_FRAMES := 3
## Animals of each kind (but one flock) that `--wildlife` puts in view.
const START_WILDLIFE_COUNT := 4
## `_debug_hit_tile` while there is no `--hit` to do.
const NO_TILE := Vector2i(1 << 30, 1 << 30)

var _state: GameState
var _builder: Builder
var _settings: GameSettings
var _audio := AudioService.new()
var _sounds := GameSounds.new()
var _ambience := AmbienceSounds.new()
var _menu: PauseMenu
var _tooltip_view := TooltipView.new()
var _save_path := SaveFile.DEFAULT_PATH
var _settings_path := GameSettings.DEFAULT_PATH
var _debug_menu_page := -1
var _player_view := PlayerView.new()
var _tiredness_view := TirednessView.new()
var _use_highlight := UseHighlight.new()
var _harvest_hud := HarvestHud.new()
var _ground_item_view := GroundItemView.new()
var _coordinates_hud := CoordinatesHud.new()
var _hotbar := HotbarHud.new()
var _build_panel := BuildPanel.new()
var _vitals := VitalsHud.new()
var _character_screen := CharacterScreen.new()
var _crafting_screen := CraftingScreen.new()
var _storage_screen := StorageScreen.new()
var _console_view := ConsoleView.new()
var _cheat_hud := CheatHud.new()
var _start_console_lines := PackedStringArray()
var _interior_view := InteriorView.new()
var _weather_view := WeatherView.new()
var _wildlife := WildlifeView.new()
var _start_wildlife := PackedStringArray()
var _debug_hit_tile := NO_TILE
var _debug_harvest_tile := NO_TILE
var _weather: WeatherSample
var _snow_cover := 0.0
var _frost := 0.0
var _screenshot_path := ""
var _fast_forward := false
## A fade (through a door, into sleep) or passing out is running: the player neither walks nor
## acts.
var _is_in_transition := false
var _fade_screen := FadeScreen.new()
var _sleep_at_start := false
var _enter_first_house := false
var _open_character_screen_at_start := false
var _open_crafting_screen_at_start := false
var _open_storage_screen_at_start := false
var _debug_chest_tile := NO_TILE
var _debug_chest_inside_tile := NO_TILE
var _debug_chest: WorldObject
var _settled_frames := 0
var _screenshot_delay := 0.0
var _pending_minutes := 0.0
var _camera_shift := Vector2.ZERO
var _start_zoom := 1.0
var _start_building := &""
var _is_hammer_held_at_start := false

@onready var _world: SubViewport = $WorldViewport
@onready var _view: WorldView = $WorldViewport/WorldView
@onready var _tint: DayNightTint = $WorldViewport/DayNightTint
@onready var _build_mode: BuildMode = $WorldViewport/BuildMode
@onready var _camera: CameraController = $CameraController
@onready var _hud: ClockHud = $ClockHud
@onready var _message: Label = $MessageHud/Message


func _ready() -> void:
	# First thing, before anything else can raise or focus the window.
	if OS.get_cmdline_user_args().has("--background"):
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true)
	if (
		not EnergyRules.default_rules().is_valid()
		or not CropRules.default_rules().is_valid()
		or not Vegetation.default_vegetation().is_valid()
		or not WildlifeRules.default_rules().is_valid()
		or not SeasonRules.default_rules().is_valid()
		or not BuildingRules.default_rules().is_valid()
		or not RecipeRules.default_rules().is_valid()
		or not SoundRules.default_rules().is_valid()
		or not AmbienceRules.default_rules().is_valid()
		or not AssetCheck.report()
	):
		# The load has reported the missing rules, crops, curves or pictures. Nothing else runs
		# before the quit.
		set_process(false)
		set_process_unhandled_input(false)
		get_tree().quit(1)
		return
	_settings = _load_settings()
	_apply_ui_scale(_settings.ui_scale)
	add_child(_audio)
	_audio.is_muted = OS.get_cmdline_user_args().has("--mute")
	_world.audio_listener_enable_2d = true
	_audio.use_world(_world)
	_audio.apply_settings(_settings)
	_settings.audio_changed.connect(func() -> void: _audio.apply_settings(_settings))
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
		elif arg.begins_with("--felled="):
			var tile := arg.trim_prefix("--felled=").split_floats(",")
			DebugFelled.create(_state.world, Vector2i(int(tile[0]), int(tile[1])))
		elif arg.begins_with("--mow="):
			var tile := arg.trim_prefix("--mow=").split_floats(",")
			DebugMow.create(_state, Vector2i(int(tile[0]), int(tile[1])))
		elif arg.begins_with("--drops="):
			var tile := arg.trim_prefix("--drops=").split_floats(",")
			DebugDrops.create(_state.world, Vector2i(int(tile[0]), int(tile[1])))
		elif arg.begins_with("--building="):
			_start_building = StringName(arg.trim_prefix("--building="))
		elif arg.begins_with("--ghost="):
			# BuildMode pins the ghost there; here the hammer is taken to see it.
			_is_hammer_held_at_start = true
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
		elif arg == "--sleep":
			_sleep_at_start = true
		elif arg == "--inventory":
			_open_character_screen_at_start = true
		elif arg == "--crafting":
			_open_crafting_screen_at_start = true
		elif arg == "--storage":
			_open_storage_screen_at_start = true
		elif arg.begins_with("--hold="):
			_hold(StringName(arg.trim_prefix("--hold=")))
		elif arg.begins_with("--chest="):
			var tile := arg.trim_prefix("--chest=").split_floats(",")
			_debug_chest_tile = Vector2i(int(tile[0]), int(tile[1]))
		elif arg.begins_with("--chest-inside="):
			var tile := arg.trim_prefix("--chest-inside=").split_floats(",")
			_debug_chest_inside_tile = Vector2i(int(tile[0]), int(tile[1]))
		elif arg.begins_with("--console="):
			_start_console_lines = arg.trim_prefix("--console=").split(";")
		elif arg.begins_with("--zoom="):
			_start_zoom = float(arg.trim_prefix("--zoom="))
		elif arg.begins_with("--mouse-tile="):
			var tile := arg.trim_prefix("--mouse-tile=").split_floats(",")
			_use_highlight.debug_mouse_tile = Vector2i(int(tile[0]), int(tile[1]))
		elif arg.begins_with("--tooltip="):
			_tooltip_view.show_by_id(arg.trim_prefix("--tooltip="))
		elif arg.begins_with("--menu="):
			_debug_menu_page = PauseMenu.Page.get(arg.trim_prefix("--menu=").to_upper(), -1)
		elif arg.begins_with("--weather="):
			_force_weather(StringName(arg.trim_prefix("--weather=")))
		elif arg.begins_with("--wildlife="):
			_start_wildlife = arg.trim_prefix("--wildlife=").split(",")
			_wildlife.is_spawning_naturally = false
		elif arg.begins_with("--hit="):
			var tile := arg.trim_prefix("--hit=").split_floats(",")
			_debug_hit_tile = Vector2i(int(tile[0]), int(tile[1]))
		elif arg.begins_with("--harvest="):
			var tile := arg.trim_prefix("--harvest=").split_floats(",")
			_debug_harvest_tile = Vector2i(int(tile[0]), int(tile[1]))
		elif arg == "--wildlife-calm":
			_wildlife.is_player_ignored = true
		elif arg == "--flash":
			_weather_view.is_flash_held = true
		elif arg.begins_with("--snow="):
			_state.snow_cover.forced = float(arg.trim_prefix("--snow="))
		elif arg.begins_with("--camera-shift="):
			var shift := arg.trim_prefix("--camera-shift=").split_floats(",")
			_camera_shift = Vector2(shift[0], shift[1])
	_view.show_world(_state.world)
	_view.add_child(_ground_item_view)
	_ground_item_view.show_items(_state.world, _view.entities)
	_view.tree_felled.connect(_ground_item_view.hold_hops_from)
	_view.add_child(_wildlife)
	_wildlife.show_wildlife(_state, _view, _camera)
	_builder = Builder.new(_state)
	if _start_building != &"":
		if BuildingTypes.TYPES.has(_start_building):
			_builder.choice = _start_building
		else:
			push_error(
				"--building expects one of %s, got '%s'" % [BuildingTypes.ids(), _start_building]
			)
	if _is_hammer_held_at_start:
		_builder.select_hammer()
	_build_mode.world = _state.world
	_build_mode.builder = _builder
	_build_mode.camera = _camera
	_build_mode.message_changed.connect(_show_build_message)
	_camera.rig.follow(_camera_target)
	_camera.rig.set_zoom_clamped(_start_zoom)
	# Among the objects, so the player walks behind tree canopies.
	_view.entities.add_child(_player_view)
	_player_view.show_player(_state.player)
	_tiredness_view.watch(_state.player, _state.clock, _state.energy_rules)
	_player_view.add_child(_tiredness_view)
	_view.add_child(_use_highlight)
	_use_highlight.show_for(_state, _camera)
	add_child(_harvest_hud)
	add_child(_coordinates_hud)
	add_child(_hotbar)
	_hotbar.show_inventory(_state.player.inventory)
	add_child(_build_panel)
	_build_panel.bind(_builder, _state.player.inventory)
	add_child(_vitals)
	_vitals.show_state(_state)
	add_child(_character_screen)
	_character_screen.show_player(_state.player)
	if _open_character_screen_at_start:
		_character_screen.toggle()
	add_child(_crafting_screen)
	_crafting_screen.show_crafting(Crafting.new(_state), _state.player.inventory)
	if _open_crafting_screen_at_start:
		_crafting_screen.toggle()
	add_child(_storage_screen)
	add_child(_cheat_hud)
	_cheat_hud.show_cheats(_state.cheats)
	add_child(_console_view)
	_console_view.show_state(_state, _wildlife.spawn_in_view)
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
	add_child(_tooltip_view)
	add_child(_fade_screen)
	_start_sounds()
	_interior_view.hide()
	_world.add_child(_interior_view)
	_world.add_child(_weather_view)
	_show_clock()
	if _state.is_inside():
		_show_current_map()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_save_game()
		get_tree().quit()


func _unhandled_input(event: InputEvent) -> void:
	# A collapse, the message on black and the sleep fade take all input (the message screen
	# reads its own key): no menu, console, hotbar or hammer until the player is up again.
	if _is_in_transition:
		return
	if event.is_action_pressed("console") and _can_open_console():
		# The key that opens it must not be typed into the input line.
		get_viewport().set_input_as_handled()
		_console_view.open()
		return
	if event.is_action_pressed("pause"):
		# Escape closes the console, then a screen, then dismisses build mode (until the player
		# holds the hammer again), then opens the menu.
		if _console_view.is_open():
			_console_view.close()
		elif _character_screen.is_open():
			_character_screen.toggle()
		elif _crafting_screen.is_open():
			_crafting_screen.toggle()
		elif _storage_screen.is_open():
			_storage_screen.close()
		elif _build_mode.is_active():
			_builder.dismiss()
		else:
			_open_menu()
		return
	# The open console takes the input: the player neither walks nor acts.
	if _console_view.is_open():
		return
	var can_use := _can_use()
	if _screens_take(event):
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
	elif event.is_action_pressed("select_hammer"):
		_builder.select_hammer()
	# E also picks the next building (outdoors), so the hammer in hand doesn't open a chest or put
	# the player to bed.
	elif event.is_action_pressed("interact") and not _build_mode.is_active():
		_interact()
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
	_tiredness_view.is_awake = not _is_in_transition
	_weather_view.show_weather(_weather, _tint.color)
	_view.ambient_motion.update(delta, _weather_view.wind, _weather_view.rain)
	_coordinates_hud.show_position(
		_state.player.tile(), _state.is_inside(), _weather_and_sun_text(_weather)
	)
	var is_in_play := not _is_screen_open() and not _console_view.is_open()
	_use_highlight.is_enabled = (
		is_in_play and not _builder.is_building() and not _is_in_transition
	)
	# Build mode only counts outdoors, in play and not during a transition; it keeps processing,
	# to clear its message when it goes off.
	_build_mode.visible = is_in_play and not _state.is_inside() and not _is_in_transition
	_build_panel.visible = _build_mode.is_active()
	# Out of energy after a use (or in a game saved while passing out), or up too late. A game
	# that starts so shows the world first.
	var is_drawn := _view.is_settled or _state.is_inside()
	if (_state.is_out_of_energy() or _state.is_up_too_late) and is_drawn and not _is_in_transition:
		_pass_out()
	if not _is_in_transition:
		var direction := Vector2.ZERO
		if not _is_screen_open() and not _console_view.is_open():
			direction = Input.get_vector("move_left", "move_right", "move_up", "move_down")
		_player_view.walk_speed = _state.walk_speed_factor()
		_state.player.move(_state.current_map, direction, delta, _player_view.walk_speed)
		_state.collect_ground_items(delta)
		if _state.door_underfoot():
			_fade_through(_pass_door)
	if not _state.is_inside():
		_view.player_feet = _player_view.position
		_view.set_focus(_state.player.tile())
	if _enter_first_house:
		_enter_first_house_now()
	if _sleep_at_start and _view.is_settled:
		_sleep_at_start = false
		_try_sleep()
	_place_debug_chests()
	if not _start_wildlife.is_empty() and _view.is_settled and not _state.is_inside():
		_spawn_start_wildlife()
	if _debug_hit_tile != NO_TILE and _view.is_settled and not _state.is_inside():
		_hit_debug_tile()
	if _debug_harvest_tile != NO_TILE and _view.is_settled and not _state.is_inside():
		DebugHarvest.run(_state, _debug_harvest_tile)
		_debug_harvest_tile = NO_TILE
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


## Whether a screen that takes the input (not the console) is open.
func _is_screen_open() -> bool:
	return _character_screen.is_open() or _crafting_screen.is_open() or _storage_screen.is_open()


func _can_open_console() -> bool:
	return not _console_view.is_open() and not get_tree().paused and not _is_in_transition


func _can_use() -> bool:
	return not _is_in_transition and not _build_mode.is_active()


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
	var use := _state.use_tile(target.tile)
	_sounds.used(use, target.tile)
	_tiredness_view.acted(use)
	if _state.is_inside() and use in [GameState.Use.PLACE, GameState.Use.TAKE_DOWN]:
		_interior_view.show_interior(_state.current_map)
	if use == GameState.Use.NO_ROOM:
		_harvest_hud.show_note("Not enough room in the inventory.")
	if use == GameState.Use.NEEDS_BETTER_TOOL:
		var tool_name: String = ItemTypes.TYPES[_state.player.inventory.held_item()]["name"]
		_harvest_hud.show_note("Needs a better %s." % tool_name.to_lower())


## Out of energy or up too late: the player collapses where they stand (the world keeps
## running), the screen goes black, and a message says what happened until a key or a click.
## Then they wake in their home bed (see GameState `pass_out`).
func _pass_out() -> void:
	_is_in_transition = true
	# Nothing else may move the player meanwhile.
	_console_view.close()
	if _character_screen.is_open():
		_character_screen.toggle()
	var was_up_too_late := _state.is_up_too_late
	_player_view.collapse()
	await get_tree().create_timer(PlayerView.COLLAPSE_SECONDS).timeout
	await _fade_screen.fade_out()
	var minutes_slept := _state.pass_out()
	_player_view.stand_up()
	_show_current_map()
	_save_game()
	await _fade_screen.show_message(PassOutMessage.text(_state, was_up_too_late, minutes_slept))
	await _fade_screen.fade_in()
	_is_in_transition = false


## Where the camera looks. The player is drawn on the art pixel grid (rounded), the camera
## is not, so the world scrolls smoothly and the player wobbles by up to half an art pixel
## against the screen (the user chose this over a pixel-locked camera).
func _camera_target() -> Vector2:
	return _state.player.position * TerrainTileset.TILE_SIZE + _camera_shift


## Real time to whole game minutes; the fraction carries over to the next frame.
func _tick_clock(delta: float) -> void:
	# A screenshot with TIME=... must show exactly that time, unless it is told to wait. Time
	# stands still while the screen is black (a message there may wait long for a key).
	if (_screenshot_path != "" and _screenshot_delay == 0.0) or _fade_screen.is_black():
		return
	var rate := GAME_MINUTES_PER_REAL_SECOND * (FAST_FORWARD_FACTOR if _fast_forward else 1.0)
	_pending_minutes += delta * rate
	var whole_minutes := int(_pending_minutes)
	if whole_minutes > 0:
		_pending_minutes -= whole_minutes
		_state.pass_awake_time(whole_minutes)
		_weather_view.minutes_passed(whole_minutes)
		_show_clock()


## Opens and closes the screens on their keys. Returns whether a screen took the event: one that
## is open takes all the input, so the player neither walks nor acts.
func _screens_take(event: InputEvent) -> bool:
	if _storage_screen.is_open():
		if event.is_action_pressed("interact"):
			_storage_screen.close()
		return true
	if event.is_action_pressed("crafting") and not _character_screen.is_open():
		_crafting_screen.toggle()
		return true
	if event.is_action_pressed("inventory") and not _crafting_screen.is_open():
		_character_screen.toggle()
		return true
	return _character_screen.is_open() or _crafting_screen.is_open()


## E: opens the chest in reach, else sleeps in the bed in reach.
func _interact() -> void:
	var chest := _state.chest_to_open(_use_highlight.targeting().tile)
	if chest == null:
		_try_sleep()
	else:
		_storage_screen.open(chest, _state.player)


## Sleeps in the bed in reach until the morning: the new day shows on the black for a moment.
func _try_sleep() -> void:
	var bed := _state.bed_in_reach()
	if bed == null:
		return
	_fade_through(
		func() -> String:
			_state.sleep_in(bed)
			_show_clock()
			_save_game()
			return _state.clock.date_text()
	)


## Fades to black, runs `change` while the screen is black, and fades back in. A `change` that
## returns text has it shown on the black for a moment first.
func _fade_through(change: Callable) -> void:
	_is_in_transition = true
	# No command runs during a fade: a teleport would meet a door half way through.
	_console_view.close()
	await _fade_screen.fade_out()
	var note: Variant = change.call()
	if note is String:
		await _fade_screen.show_note(note)
	await _fade_screen.fade_in()
	_is_in_transition = false


func _pass_door() -> void:
	_state.pass_door()
	_show_current_map()


## Shows the map the player is on: the world, or the interior (which pauses the world's
## chunk streaming, leaving it as it is).
func _show_current_map() -> void:
	var is_inside := _state.is_inside()
	_audio.set_inside(is_inside)
	_view.visible = not is_inside
	_weather_view.visible = not is_inside
	_view.process_mode = PROCESS_MODE_DISABLED if is_inside else PROCESS_MODE_INHERIT
	_interior_view.visible = is_inside
	if is_inside:
		_wildlife.clear()
		_interior_view.show_interior(_state.current_map)
	_player_view.reparent(_interior_view.entities if is_inside else _view.entities, false)
	_use_highlight.reparent(_interior_view if is_inside else _view, false)
	_show_clock()


## Starts the sounds of the game once everything that makes one exists: the footsteps, work and
## pickups, the buttons of the menus, the opening and closing of menus, screens and console, and
## the weather's and the animals' ambience.
func _start_sounds() -> void:
	add_child(_sounds)
	_sounds.listen(_audio, _state, _view, _player_view, _build_mode)
	_sounds.click_on_press_in(_menu)
	_sounds.click_on_press_in(_character_screen)
	_sounds.click_on_press_in(_crafting_screen)
	_sounds.click_on_press_in(_storage_screen)
	_sounds.watch_panel(func() -> bool: return _menu.visible)
	_sounds.watch_panel(_character_screen.is_open)
	_sounds.watch_panel(_crafting_screen.is_open)
	_sounds.watch_panel(_storage_screen.is_open, &"chest_open", &"chest_close")
	_sounds.watch_panel(_console_view.is_open)
	add_child(_ambience)
	_ambience.listen(_audio, _state, _wildlife, _weather_view)


## Debug (`--hold`): puts 5 of an item in the inventory and holds it, if it is on the hotbar.
func _hold(item: StringName) -> void:
	if not ItemTypes.TYPES.has(item):
		push_error("--hold expects an item, got '%s'" % item)
		return
	var inventory := _state.player.inventory
	inventory.add(item, 5)
	for slot in Inventory.HOTBAR_SIZE:
		if inventory.item_in(slot) == item:
			inventory.select(slot)
			return


## Debug (`--chest`, `--chest-inside`, `--storage`): puts the asked chests where they go once
## their map is drawn, and opens the storage screen of the last.
func _place_debug_chests() -> void:
	if _debug_chest_tile != NO_TILE and _view.is_settled and not _state.is_inside():
		_debug_chest = DebugChest.create(_state.world, _debug_chest_tile)
		_debug_chest_tile = NO_TILE
	if _debug_chest_inside_tile != NO_TILE and _state.is_inside() and not _enter_first_house:
		_debug_chest = DebugChest.create(_state.current_map, _debug_chest_inside_tile)
		_interior_view.show_interior(_state.current_map)
		_debug_chest_inside_tile = NO_TILE
	if _open_storage_screen_at_start and _debug_chest != null:
		_open_storage_screen_at_start = false
		_storage_screen.open(_debug_chest, _state.player)


## Debug (`--hit`): hits the object on the asked tile, if there is one.
func _hit_debug_tile() -> void:
	var object := _state.world.object_at(_debug_hit_tile)
	if object != null:
		_state.world.hit_object(object, 0)
	_tiredness_view.acted(GameState.Use.HIT)
	_debug_hit_tile = NO_TILE


## Debug (`--wildlife`): puts a few animals of each asked kind in view.
func _spawn_start_wildlife() -> void:
	for kind in _start_wildlife:
		var count := 1 if kind == "flock" else START_WILDLIFE_COUNT
		_wildlife.spawn_in_view(StringName(kind), count)
	_start_wildlife.clear()


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
		"%s\nsnow cover %d %% · frost %d %%\nsunrise %s · sunset %s"
		% [
			weather.short_text(),
			roundi(_snow_cover * 100.0),
			roundi(_frost * 100.0),
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
	return (
		(_view.is_settled or _state.is_inside())
		and not _enter_first_house
		and _debug_harvest_tile == NO_TILE
		and _debug_chest_tile == NO_TILE
		and _debug_chest_inside_tile == NO_TILE
		and not _open_storage_screen_at_start
	)


func _show_build_message(text: String) -> void:
	_message.text = text


func _show_clock() -> void:
	# The weather only changes with the minute, the map or a console command, which all end here.
	_weather = _state.current_weather()
	if _state.is_inside():
		_tint.show_interior()
	else:
		_tint.show_time(_state.clock, _weather.cloud_cover)
	_view.set_light_strength(_tint.light_strength())
	# Snow and frost are those of the start of the hour, so the view redraws once an hour.
	_snow_cover = _state.current_snow_cover()
	_frost = _state.current_frost()
	_view.refresh_looks(_state.clock.day, _snow_cover, _frost)
	_build_mode.set_snowy(_snow_cover > SNOWY_GHOST_COVER)
	_hud.show_time(_state.clock)


func _save_screenshot_and_quit() -> void:
	# Draws now instead of waiting for the next frame, which never comes while the window
	# can't be shown (e.g. a locked screen).
	RenderingServer.force_draw(false)
	# The window as the player sees it, not only the world viewport.
	get_viewport().get_texture().get_image().save_png(_screenshot_path)
	get_tree().quit()
