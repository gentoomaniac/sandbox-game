extends Node2D
## The game scene: owns the GameState, turns real time into game minutes and feeds the
## player's input to the state. The world is drawn into WorldViewport (one art pixel per
## pixel) and shown on the window by CameraController; the UI is drawn on the window itself.
## The camera and chunk streaming follow the player.
##
## The game is loaded from the save at start and saved after sleeping, after passing out and on
## quit (see SaveFile). The debug flags after `--` on the Godot command line are documented in
## StartupOptions.

const WORLD_SEED := 1
## The build ghost has snow on its roof while the snow cover is above this.
const SNOWY_GHOST_COVER := 0.5
## One game day lasts 16 real minutes (24 h * 60 min / 1.5 / 60 s).
const GAME_MINUTES_PER_REAL_SECOND := 1.5
## Debug speed-up, toggled with F2: a game day in 16 real seconds.
const FAST_FORWARD_FACTOR := 60.0

var _state: GameState
var _builder: Builder
var _settings: GameSettings
var _audio := AudioService.new()
var _sounds := GameSounds.new()
var _ambience := AmbienceSounds.new()
var _menu: PauseMenu
var _tooltip_view := TooltipView.new()
var _options := StartupOptions.from_command_line()
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
var _chat_screen := ChatScreen.new()
var _npc_name_tag := NpcNameTag.new()
var _cheat_hud := CheatHud.new()
## The screens, in the order Escape closes them. The pause menu is not among them: Escape
## opens it, it pauses the game, and it has its own input.
## The chat pauses the game like the pause menu, but takes Escape itself.
var _screens: Array = [
	_console_view, _chat_screen, _character_screen, _crafting_screen, _storage_screen
]
var _interior_view := InteriorView.new()
var _object_cover := ObjectCover.new()
var _weather_view := WeatherView.new()
var _wildlife := WildlifeView.new()
var _weather: WeatherSample
var _snow_cover := 0.0
var _frost := 0.0
var _fast_forward := false
## A fade (through a door, into sleep) or passing out is running: the player neither walks nor
## acts.
var _is_in_transition := false
var _fade_screen := FadeScreen.new()
var _debug: DebugRunner
var _pending_minutes := 0.0
## The map the views show: the world or the interior of a house.
var _shown_map: GameMap

@onready var _world: SubViewport = $WorldViewport
@onready var _view: WorldView = $WorldViewport/WorldView
@onready var _tint: DayNightTint = $WorldViewport/DayNightTint
@onready var _build_mode: BuildMode = $WorldViewport/BuildMode
@onready var _camera: CameraController = $CameraController
@onready var _hud: ClockHud = $ClockHud
@onready var _message: Label = $MessageHud/Message


func _ready() -> void:
	# First thing, before anything else can raise or focus the window.
	if _options.background:
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true)
	if (
		not EnergyRules.default_rules().is_valid()
		or not CropRules.default_rules().is_valid()
		or not Vegetation.default_vegetation().is_valid()
		or not WildlifeRules.default_rules().is_valid()
		or not LivestockRules.default_rules().is_valid()
		or not NpcRules.default_rules().is_valid()
		or not VillagerRules.default_rules().is_valid()
		or not SeasonRules.default_rules().is_valid()
		or not BuildingRules.default_rules().is_valid()
		or not RecipeRules.default_rules().is_valid()
		or not SkillRules.default_rules().is_valid()
		or not StationRules.default_rules().is_valid()
		or not SoundRules.default_rules().is_valid()
		or not AmbienceRules.default_rules().is_valid()
		or not LandscapeRules.default_rules().is_valid()
		or not PathRules.default_rules().is_valid()
		or not AssetCheck.report()
	):
		# The load has reported the missing rules, crops, curves or pictures. Nothing else runs
		# before the quit.
		set_process(false)
		set_process_unhandled_input(false)
		get_tree().quit(1)
		return
	_load_game()
	# The steps depend on each other in this order:
	# - the views are made before they are connected, and all of them before the options act on
	#   them;
	# - the state is complete (the game options applied) before any view reads it;
	# - `_view.show_world` comes before `_ground_item_view.show_items`, which draws into the
	#   world view's entities, and `_builder` before the build mode and panel that use it;
	# - the sounds start last, after the options, so a screen that is open at start makes no sound.
	_make_views()
	_connect_state_and_views()
	_apply_start_options()
	_start_sounds()
	_show_clock()
	_shown_map = _state.current_map
	if _state.is_inside():
		_show_current_map()


## The settings, the audio and the game, with the flags that change the game applied.
func _load_game() -> void:
	_settings = _load_settings()
	_apply_ui_scale(_settings.ui_scale)
	# Before add_child: AudioService._ready reads is_logging.
	_audio.is_muted = _options.mute
	_audio.is_logging = _options.sound_log
	add_child(_audio)
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
	_apply_game_options()


## Puts every view in the tree, in the order they are drawn and take input.
func _make_views() -> void:
	_view.add_child(_ground_item_view)
	_view.add_child(_wildlife)
	# Among the objects, so the player walks behind tree canopies.
	_view.entities.add_child(_player_view)
	_view.entities.add_child(_object_cover)
	_player_view.add_child(_tiredness_view)
	_view.add_child(_use_highlight)
	add_child(_harvest_hud)
	add_child(_coordinates_hud)
	add_child(_npc_name_tag)
	add_child(_hotbar)
	add_child(_build_panel)
	add_child(_vitals)
	add_child(_character_screen)
	add_child(_crafting_screen)
	add_child(_storage_screen)
	add_child(_cheat_hud)
	add_child(_console_view)
	add_child(_chat_screen)
	_menu = PauseMenu.new(_settings)
	add_child(_menu)
	add_child(_tooltip_view)
	add_child(_fade_screen)
	_interior_view.hide()
	_world.add_child(_interior_view)
	_world.add_child(_weather_view)


## Shows the state in the views and wires what they report back.
func _connect_state_and_views() -> void:
	_view.show_world(_state.world)
	_ground_item_view.show_items(_state.world, _view.entities)
	_view.tree_felled.connect(_ground_item_view.hold_hops_from)
	_wildlife.show_wildlife(_state, _view, _camera)
	for npc in _state.npcs.all():
		_show_npc(npc)
	_state.npcs.added.connect(_show_npc)
	_builder = Builder.new(_state)
	_build_mode.world = _state.world
	_build_mode.builder = _builder
	_build_mode.camera = _camera
	_build_mode.message_changed.connect(_show_build_message)
	_camera.rig.follow(_camera_target)
	_player_view.show_player(_state.player, _options)
	_tiredness_view.watch(_state.player, _state.clock, _state.energy_rules)
	_use_highlight.show_for(_state, _camera)
	_hotbar.show_inventory(_state.player.inventory)
	_build_panel.bind(_builder, _state.player.inventory)
	_vitals.show_state(_state)
	_character_screen.show_player(_state.player)
	_crafting_screen.show_crafting(Crafting.new(_state), _state.player.inventory)
	_cheat_hud.show_cheats(_state.cheats)
	_console_view.show_state(_state, _wildlife.spawn_in_view)
	# A teleport moves the player far: the camera jumps with them instead of gliding.
	_console_view.command_ran.connect(
		func() -> void:
			_camera.rig.follow(_camera_target)
			# `reset` and `tp` can take the player to another map.
			if _state.current_map != _shown_map:
				_show_current_map()
			_show_clock()
	)
	_menu.resumed.connect(_resume)
	_menu.save_and_quit_requested.connect(_save_and_quit)


## Applies the flags that put the views in a situation, and hands the ones that wait for the
## drawn world to the DebugRunner.
func _apply_start_options() -> void:
	if _options.building != &"":
		if BuildingTypes.TYPES.has(_options.building):
			_builder.choice = _options.building
		else:
			push_error(
				"--building expects one of %s, got '%s'" % [BuildingTypes.ids(), _options.building]
			)
	# BuildMode pins the ghost there; here the hammer is taken to see it.
	if _options.ghost != StartupOptions.NO_TILE:
		_builder.select_hammer()
		if _options.taking_down:
			_builder.toggle_taking_down()
	_build_mode.start_options = _options
	_camera.rig.set_zoom_clamped(_options.zoom)
	if _options.coordinates:
		_coordinates_hud.toggle()
	if _options.mouse_tile != StartupOptions.NO_TILE:
		_use_highlight.debug_mouse_tile = _options.mouse_tile
	if _options.tooltip != "":
		_tooltip_view.show_by_id(_options.tooltip)
	_wildlife.is_spawning_naturally = _options.wildlife.is_empty()
	_wildlife.is_player_ignored = _options.wildlife_calm
	_weather_view.is_flash_held = _options.flash
	if _options.inventory:
		_character_screen.open()
	if _options.skills:
		_character_screen.open(CharacterScreen.Tab.SKILLS)
	if _options.crafting:
		_crafting_screen.open()
	if not _options.console.is_empty():
		_console_view.open()
		for line in _options.console:
			_console_view.run_line(line)
	_debug = DebugRunner.new(_options)
	_debug.state = _state
	_debug.view = _view
	_debug.wildlife = _wildlife
	_debug.tiredness_view = _tiredness_view
	_debug.interior_view = _interior_view
	_debug.storage_screen = _storage_screen
	_debug.crafting_screen = _crafting_screen
	_debug.chat_screen = _chat_screen
	_debug.open_chat = _open_chat
	_debug.try_sleep = _try_sleep
	_debug.pass_door = _pass_door
	_debug.open_menu = _open_menu
	_debug.save_screenshot_and_quit = _save_screenshot_and_quit


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
		# Escape closes the topmost screen, then dismisses build mode (until the player holds
		# the hammer again), then opens the menu.
		if _close_topmost_screen():
			return
		if _build_mode.is_active():
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
	_view.ambient_motion.show_tide(Tide.level(_state.clock.total_minutes()))
	if _coordinates_hud.visible:
		_coordinates_hud.show_position(
			_state.player.tile(), _state.is_inside(), _weather_and_sun_text(_weather)
		)
	var is_in_play := not _is_any_screen_open()
	_use_highlight.is_enabled = (
		is_in_play and not _builder.is_building() and not _is_in_transition
	)
	var can_chat := is_in_play and not _build_mode.is_active() and not _is_in_transition
	_npc_name_tag.show_over(
		Interaction.npc_to_chat(_state, _use_highlight.targeting().tile) if can_chat else null,
		_camera
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
		if not _is_any_screen_open():
			direction = Input.get_vector("move_left", "move_right", "move_up", "move_down")
		_player_view.walk_speed = _state.walk_speed_factor()
		_state.walk(direction, delta, _player_view.walk_speed)
		_state.collect_ground_items(delta)
		_interior_view.cover_bed(_state.player.bed_lying_in)
		_object_cover.cover(_state.player.bed_lying_in)
		if _state.door_underfoot():
			_fade_through(_pass_door)
	# The world, its animals and villagers too, stands still while the player is in a house.
	if not _state.is_inside():
		_state.livestock.update(delta, _state.world, _state.player.position, _state.clock)
		_state.npcs.update(delta, _state.world, _state.player.position, _state.clock)
		_view.player_feet = _player_view.position
		_view.set_focus(_state.player.tile())
	_debug.update(delta)


func _open_menu(page := PauseMenu.Page.PAUSE) -> void:
	get_tree().paused = true
	_menu.open(page)


func _resume() -> void:
	get_tree().paused = false


func _save_and_quit() -> void:
	_save_game()
	get_tree().quit()


## Eats the held food, if any, and says how much energy it gave. Returns whether it ate.
func _eat_held() -> bool:
	var energy_before := _state.player.energy
	if not _state.eat_held():
		return false
	_harvest_hud.show_note("+%s energy" % roundi(_state.player.energy - energy_before))
	return true


func _is_use_event(event: InputEvent) -> bool:
	return event.is_action_pressed("use") or event.is_action_pressed("use_click")


## Whether a screen or the console is open: the player neither walks nor acts.
func _is_any_screen_open() -> bool:
	return _screens.any(func(screen: Node) -> bool: return screen.is_open())


## Closes the first open screen of `_screens`. Returns whether there was one.
func _close_topmost_screen() -> bool:
	for screen in _screens:
		if screen.is_open():
			screen.close()
			return true
	return false


func _close_all_screens() -> void:
	for screen in _screens:
		screen.close()


func _can_open_console() -> bool:
	return not _console_view.is_open() and not get_tree().paused and not _is_in_transition


func _can_use() -> bool:
	return not _is_in_transition and not _build_mode.is_active()


## The hotbar slot (0 to 7) whose key `event` presses, or -1.
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
	if _state.is_inside() and use in [ToolUse.Use.PLACE, ToolUse.Use.TAKE_DOWN]:
		_interior_view.show_interior(_state.current_map)
	if use == ToolUse.Use.GIVE_BONE:
		_harvest_hud.show_note("The dog follows you.")
	if use == ToolUse.Use.NO_ROOM:
		_harvest_hud.show_note("Not enough room in the inventory.")
	if use == ToolUse.Use.NEEDS_BETTER_TOOL:
		var tool_name: String = ItemTypes.TYPES[_state.player.inventory.held_item()]["name"]
		_harvest_hud.show_note("Needs a better %s." % tool_name.to_lower())


## Out of energy or up too late: the player collapses where they stand (the world keeps
## running), the screen goes black, and a message says what happened until a key or a click.
## Then they wake in their home bed (see GameState `pass_out`).
func _pass_out() -> void:
	_is_in_transition = true
	# Nothing else may move the player meanwhile.
	_close_all_screens()
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
	return _state.player.position * TerrainTileset.TILE_SIZE + _options.camera_shift


## Real time to whole game minutes; the fraction carries over to the next frame.
func _tick_clock(delta: float) -> void:
	# A screenshot with TIME=... must show exactly that time, unless it is told to wait. Time
	# stands still while the screen is black (a message there may wait long for a key).
	if _debug.is_clock_stopped() or _fade_screen.is_black():
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
	for screen: Node in [_storage_screen, _crafting_screen]:
		if screen.is_open() and event.is_action_pressed("interact"):
			screen.close()
			return true
	if _storage_screen.is_open():
		return true
	if event.is_action_pressed("crafting") and not _character_screen.is_open():
		_crafting_screen.toggle()
		return true
	if event.is_action_pressed("inventory") and not _crafting_screen.is_open():
		_character_screen.toggle()
		return true
	if event.is_action_pressed("skills") and not _crafting_screen.is_open():
		_character_screen.toggle(CharacterScreen.Tab.SKILLS)
		return true
	return _is_any_screen_open()


## E: speaks to the villager in front, else opens the chest or the station in reach, else sleeps
## in the bed in reach.
func _interact() -> void:
	var target := _use_highlight.targeting().tile
	var npc := Interaction.npc_to_chat(_state, target)
	if npc != null:
		_open_chat(npc)
		return
	var object := Interaction.object_to_open(_state, target)
	if object == null:
		_try_sleep()
	elif object.storage != null:
		_storage_screen.open(object, _state.player)
	else:
		_crafting_screen.open(object)


## Puts a villager among the world's entities, where it stands among the objects like the player.
func _show_npc(npc: Npc) -> void:
	_view.entities.add_child(NpcView.new(npc))


## Opens the chat with a villager, who turns to the player (the chat pauses the game).
func _open_chat(npc: Npc) -> void:
	_state.npcs.talk_to(npc, _state.player.position)
	_chat_screen.open(npc, _state.player, _state.clock)


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
	_shown_map = _state.current_map
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
	_sounds.watch_panel(_menu.is_open)
	for screen in _screens:
		_sounds.click_on_press_in(screen)
		if screen == _storage_screen:
			_sounds.watch_panel(screen.is_open, &"chest_open", &"chest_close")
		else:
			_sounds.watch_panel(screen.is_open)
	add_child(_ambience)
	_ambience.listen(_audio, _state, _wildlife, _weather_view)


## Applies the flags that change the game itself, before any view reads it.
func _apply_game_options() -> void:
	if _options.at != StartupOptions.NO_TILE:
		_state.player.position = Vector2(_options.at) + Vector2(0.5, 0.5)
	if _options.day > 0:
		_state.clock.day = _options.day
	if _options.time_hour >= 0:
		_state.clock.set_time(_options.time_hour, _options.time_minute)
	if _options.field != StartupOptions.NO_TILE:
		DebugField.create(_state.world, _options.field)
	if _options.forage != StartupOptions.NO_TILE:
		DebugForage.create(_state, _options.forage)
	if _options.felled != StartupOptions.NO_TILE:
		DebugFelled.create(_state.world, _options.felled)
	if _options.mow != StartupOptions.NO_TILE:
		DebugMow.create(_state, _options.mow)
	if _options.path != StartupOptions.NO_TILE:
		DebugPath.create(_state.world, _options.path, _options.path_days.x, _options.path_days.y)
	if _options.drops != StartupOptions.NO_TILE:
		DebugDrops.create(_state.world, _options.drops)
	if _options.energy >= 0.0:
		_state.player.energy = _options.energy
	if _options.health >= 0.0:
		_state.player.health = _options.health
	if _options.wear != &"":
		_state.player.equipment.equip(Equipment.slot_of(_options.wear), _options.wear)
	if _options.hold != &"":
		_hold(_options.hold)
	if _options.weather != &"":
		_force_weather(_options.weather)
	if _options.snow >= 0.0:
		_state.snow_cover.forced = _options.snow


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


## The saved game, or a new one if there is no save or `--new-game` is given. The first
## autosave after `--new-game` replaces the old save.
func _load_or_start_game() -> GameState:
	var saved := null if _options.new_game else SaveFile.read(_options.save_path)
	return saved if saved != null else GameState.new_game(WORLD_SEED)


## The settings, with the player's key bindings applied to the input map.
func _load_settings() -> GameSettings:
	var settings := GameSettings.new(_options.settings_path)
	settings.load_file()
	return settings


## Scales the whole window's 2D canvas, the UI included. The world screen is a full-rect
## TextureRect drawn through UV, so it keeps filling the window and the world view is unchanged.
func _apply_ui_scale(ui_scale: float) -> void:
	get_tree().root.content_scale_factor = ui_scale


func _save_game() -> void:
	SaveFile.write(_state, _options.save_path)


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
	get_viewport().get_texture().get_image().save_png(_options.screenshot)
	# Quitting takes effect at the end of the frame; nothing more to do until then, so the
	# shot is not saved again on every frame while the engine shuts down.
	set_process(false)
	get_tree().quit()
