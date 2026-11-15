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
## Debug speed-up, toggled with F2: a game day in 16 real seconds.
const FAST_FORWARD_FACTOR := 60.0
## What the player is told when they try on horseback what needs them on foot.
const GET_OFF_FIRST := "Get off the horse first."
## What the note says about a use of the held item, for the uses that have one.
const USE_NOTES := {
	ToolUse.Use.GIVE_BONE: "The dog follows you.",
	ToolUse.Use.SADDLE: "The horse is saddled: E to get on.",
	ToolUse.Use.UNSADDLE: "You take the saddle off.",
	ToolUse.Use.FILL_CAN: "You fill the watering can.",
	ToolUse.Use.CAN_EMPTY: "The watering can is empty: fill it at a well or at fresh water.",
	ToolUse.Use.RIDING: GET_OFF_FIRST,
	ToolUse.Use.NO_ROOM: "Not enough room in the inventory.",
	ToolUse.Use.STANDING_ON: "Step off it first.",
	ToolUse.Use.THE_VILLAGES: GameState.THE_VILLAGES,
}
## The key of the notification about a save (see NotificationHud).
const SAVE_NOTE := &"save"

var _state: GameState
## The game F8 loaded, if it started this scene (see QuickLoad); told once the HUD is up.
var _resumed_state: GameState
var _builder: Builder
var _settings: GameSettings
var _audio := AudioService.new()
## The music: what the console's `play` and `stop` drive, and the MusicDirector.
var _music := MusicPlayer.new()
var _sounds := GameSounds.new()
var _ambience := AmbienceSounds.new()
var _sea_sounds := SeaSounds.new()
var _menu: PauseMenu
## Asks the player what the game must not decide: a save with content the game no longer has, a
## save that is refused, a save that failed before quitting.
var _choice_dialog := ChoiceDialog.new()
var _save_questions := SaveQuestions.new(_choice_dialog)
var _load_dialog := LoadDialog.new()
## The hammer's menu on a building has a dialog of its own: nobody else is to hear its answer.
var _house_dialog := ChoiceDialog.new()
var _house_menu: HouseMenu
var _tooltip_view := TooltipView.new()
var _options := StartupOptions.from_command_line()
var _player_view := PlayerView.new()
var _tiredness_view := TirednessView.new()
var _use_swing: UseSwing
var _use_highlight := UseHighlight.new()
var _harvest_hud := HarvestHud.new()
var _notifications := NotificationHud.new()
var _saves := SaveService.new()
var _autosave_timer := AutosaveTimer.new()
var _ground_item_view := GroundItemView.new()
var _npc_views := NpcViews.new()
var _interior_npc_views := InteriorNpcViews.new()
var _coordinates_hud := CoordinatesHud.new()
var _paths_hud := PathsHud.new()
var _hotbar := HotbarHud.new()
var _build_menu := BuildMenu.new()
var _vitals := VitalsHud.new()
var _bag_screen := BagScreen.new(_hotbar)
var _character_screen := CharacterScreen.new(_hotbar)
var _crafting_screen := CraftingScreen.new()
var _storage_screen := StorageScreen.new(_hotbar)
var _process_screen := ProcessScreen.new(_hotbar)
var _fire_screen := CampfireScreen.new(_hotbar)
var _console_view := ConsoleView.new()
var _chat_screen := ChatScreen.new()
var _npc_name_tag := NpcNameTag.new()
var _action_hint := ActionHintView.new()
var _cheat_hud := CheatHud.new()
var _interior_view := InteriorView.new()
var _object_cover := ObjectCover.new()
var _weather_view := WeatherView.new()
var _wildlife := WildlifeView.new()
var _weather: WeatherSample
var _snow_cover := 0.0
var _frost := 0.0
var _fast_forward := false
## The mouse wheel's turns not yet a whole hotbar slot (see HotbarWheel).
var _wheel_progress := 0.0
var _fade_screen := FadeScreen.new()
var _blackout: BlackoutFlow
var _debug: DebugRunner
var _pending_minutes := 0.0
## The game hour the wetness of the soil was last shown for.
var _soil_shown_hour := -1
## The map the views show: the world or the interior of a house.
var _shown_map: GameMap
## Which chunks of the world are loaded; the world view draws them.
var _residency: ChunkResidency

@onready var _world: SubViewport = $WorldViewport
@onready var _view: WorldView = $WorldViewport/WorldView
@onready var _tint: DayNightTint = $WorldViewport/DayNightTint
@onready var _build_mode: BuildMode = $WorldViewport/BuildMode
@onready var _camera: CameraController = $CameraController
@onready var _hud: ClockHud = $ClockHud
@onready var _message: Label = $MessageHud/Message


func _ready() -> void:
	_resumed_state = QuickLoad.take()
	var is_new_game := QuickLoad.is_new_game
	if _resumed_state != null:
		# The game is the save's: no flag may change it or open a window again.
		_options = _options.kept_for_quick_load()
	# First thing, before anything else can raise or focus the window.
	if _options.background:
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true)
	if _options.with_working_window_title:
		DisplayServer.window_set_title(StartupOptions.WORKING_WINDOW_TITLE)
	if not RulesCheck.is_everything_valid():
		# The load has reported the missing rules, crops, curves or pictures. Nothing else runs
		# before the quit.
		set_process(false)
		set_process_unhandled_input(false)
		get_tree().quit(1)
		return
	await _load_game()
	if _state == null:
		# The player cancelled. Nothing else runs before the quit, which takes effect at the end
		# of the frame: there is no game for `_process` to tick.
		set_process(false)
		set_process_unhandled_input(false)
		get_tree().quit()
		return
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
	if _resumed_state != null:
		_notifications.post(QuickLoadFlow.LOAD_NOTE, "New game" if is_new_game else "Loaded")
	if is_new_game:
		# Saved at once, so F8 or a crash comes back to the new world, not to the game before it.
		_saves.save_and_wait(_state, _options.save_path, SaveHeader.Kind.QUICK_SAVE)
	_shown_map = _state.current_map
	if _state.is_inside():
		_show_current_map()


## The settings, the audio and the game, with the flags that change the game applied.
func _load_game() -> void:
	_settings = _load_settings()
	add_child(_choice_dialog)
	add_child(_house_dialog)
	_apply_ui_scale(_settings.ui_scale)
	Engine.max_fps = _options.max_fps_or(_settings.max_fps)
	_settings.max_fps_changed.connect(Engine.set_max_fps)
	# Before add_child: AudioService._ready reads is_logging.
	_audio.is_muted = _options.mute
	_audio.is_logging = _options.sound_log
	add_child(_audio)
	add_child(_music)
	if MusicDirector.is_wanted(_options.mute):
		add_child(MusicDirector.new(_music, _music_moment))
	_world.audio_listener_enable_2d = true
	_audio.use_world(_world)
	_audio.apply_settings(_settings)
	_settings.audio_changed.connect(func() -> void: _audio.apply_settings(_settings))
	_settings.ui_scale_changed.connect(_apply_ui_scale)
	ArtSet.is_classic = _settings.is_classic_art or _options.classic_art
	_settings.art_set_changed.connect(
		func() -> void: ArtSet.show(_settings.is_classic_art, get_tree())
	)
	_state = await _load_or_start_game()
	if _state == null:
		return
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
	DebugGameOptions.apply(_options, _state)


## What the music is chosen by now (see MusicDirector); null until the game is loaded.
func _music_moment() -> MusicMoment:
	return null if _state == null else MusicMoment.of(_state, ArtSet.is_classic)


## Puts every view in the tree, in the order they are drawn and take input.
func _make_views() -> void:
	_view.add_child(_ground_item_view)
	_view.add_child(_npc_views)
	_view.add_child(_wildlife)
	# Among the objects, so the player walks behind tree canopies.
	_view.entities.add_child(_player_view)
	_view.entities.add_child(_object_cover)
	_player_view.figure.add_child(_tiredness_view)
	_view.add_child(_use_highlight)
	add_child(_harvest_hud)
	add_child(_notifications)
	add_child(_coordinates_hud)
	_paths_hud.setup(_state.npcs, _state.player)
	add_child(_paths_hud)
	add_child(_npc_name_tag)
	add_child(_action_hint)
	add_child(_hotbar)
	add_child(_build_menu)
	add_child(_vitals)
	add_child(_bag_screen)
	add_child(_character_screen)
	add_child(_crafting_screen)
	add_child(_storage_screen)
	add_child(_process_screen)
	add_child(_fire_screen)
	add_child(_cheat_hud)
	add_child(_console_view)
	_chat_screen.dialogue = NpcDialogue.new(_settings)
	add_child(_chat_screen.dialogue)
	add_child(ModelNotices.new(_chat_screen.dialogue, _notifications))
	add_child(_chat_screen)
	_chat_screen.art_set_switch_pressed.connect(_toggle_classic_art)
	_hotbar.crafting_requested.connect(_on_crafting_requested)
	_menu = PauseMenu.new(_settings)
	add_child(_menu)
	add_child(_load_dialog)
	add_child(_tooltip_view)
	add_child(_fade_screen)
	_interior_view.hide()
	_world.add_child(_interior_view)
	add_child(_interior_npc_views)
	_world.add_child(_weather_view)


## Brings the stories and memories a villager keeps to the settings: the deed log needs them for
## the stories it hands out, and what is over the limit is dropped now.
func _apply_villager_memory_settings() -> void:
	var profile := _settings.profiles.active
	_state.deeds.stories_kept = profile["stories_kept"]
	_state.deeds.memories_kept = profile["memories_kept"]
	_chat_screen.dialogue.compact_all(_state)


## Shows the state in the views and wires what they report back.
func _connect_state_and_views() -> void:
	_residency = ChunkResidency.new(_state.world)
	_blackout = BlackoutFlow.new()
	_blackout.state = _state
	_blackout.view = _view
	_blackout.residency = _residency
	_blackout.player_view = _player_view
	_blackout.console_view = _console_view
	_blackout.fade_screen = _fade_screen
	_blackout.saves = _saves
	_blackout.save_path = _options.save_path
	_blackout.show_current_map = _show_current_map
	_blackout.show_clock = _show_clock
	add_child(_blackout)
	_view.show_world(_residency)
	_ground_item_view.show_items(_state.world, _view.entities)
	_view.tree_felled.connect(_ground_item_view.hold_hops_from)
	_wildlife.show_wildlife(_state, _view, _camera)
	_state.simulation.skipped.connect(_on_time_skipped)
	_state.crop_warnings.warned.connect(_notifications.post_line)
	_npc_views.show_npcs(_state.npcs, _view.entities, _state.world)
	_interior_npc_views.show_npcs(_state.npcs, _interior_view.entities)
	# Chats longer than the setting (a saved game's, or one lowered in the menu, which is
	# applied once it is closed rather than at every step) are compacted.
	_apply_villager_memory_settings()
	_menu.closed.connect(_apply_villager_memory_settings)
	add_child(StoryJudging.new(_chat_screen.dialogue, _state))
	var day_planner := DayPlanner.new(_chat_screen.dialogue, _state)
	add_child(day_planner)
	var speech := NpcSpeech.new()
	add_child(speech)
	speech.is_nonstop = _options.bubbles
	speech.show_for(_state, _chat_screen.dialogue, _camera.view_rect, _camera.world_to_ui)
	_builder = Builder.new(_state)
	_build_mode.world = _state.world
	_build_mode.builder = _builder
	_build_mode.camera = _camera
	_build_mode.message_changed.connect(_show_build_message)
	_house_menu = HouseMenu.new(_house_dialog, _state.homes)
	_build_mode.building_menu_requested.connect(_house_menu.open)
	_bag_screen.drop_requested.connect(_state.drop_from_inventory)
	_storage_screen.drop_requested.connect(_state.drop_from_inventory)
	_fire_screen.cook_requested.connect(_crafting_screen.open_station)
	_camera.rig.follow(_camera_target)
	_player_view.show_player(_state.player, _options)
	_use_swing = UseSwing.new(_state, _player_view)
	_use_swing.used.connect(_after_use)
	_player_view.swing_ended.connect(_repeat_held_use)
	_tiredness_view.watch(_state.player, _state.clock, _state.energy_rules, _state.cheats)
	_use_highlight.show_for(_state, _camera)
	_hotbar.show_inventory(_state.player.inventory)
	_build_menu.bind(_builder, _state.player.inventory)
	_vitals.show_state(_state)
	_bag_screen.show_player(_state.player)
	_character_screen.show_player(_state.player)
	_crafting_screen.show_crafting(Crafting.new(_state), _state.player.inventory)
	_cheat_hud.show_cheats(_state.cheats)
	_console_view.show_state(
		_state, _wildlife.spawn_in_view, _wildlife.remove_kind, _music, day_planner.replan
	)
	# A teleport moves the player far: the camera jumps with them instead of gliding.
	_console_view.command_ran.connect(
		func() -> void:
			_camera.rig.follow(_camera_target)
			# `reset` and `tp` can take the player to another map.
			if _state.current_map != _shown_map:
				_show_current_map()
			_show_clock()
	)
	_menu.save_and_quit_requested.connect(_save_and_quit)
	_menu.load_requested.connect(_load_dialog.open_saves.bind(_options.save_path))
	_menu.new_game_requested.connect(_start_new_game)
	_load_dialog.load_requested.connect(_load_picked)
	_menu.volume_tested.connect(_audio.play_volume_test)
	_saves.started.connect(
		func() -> void:
			_notifications.hold(SAVE_NOTE, "Saving...")
			_autosave_timer.restart()
	)
	_saves.finished.connect(_show_save_result)


## Where the mouse is, in UI units; with `--mouse-tile`, the middle of that tile.
func _mouse_in_ui_units() -> Vector2:
	if _options.mouse_tile == StartupOptions.NO_TILE:
		return get_viewport().get_mouse_position()
	return _camera.world_to_ui(
		(Vector2(_options.mouse_tile) + Vector2(0.5, 0.5)) * TerrainTileset.TILE_SIZE
	)


## Time passed without being played (a sleep, passing out, the console's skip): the ambient
## animals and the weather show the new time at once.
func _on_time_skipped(_minutes: int) -> void:
	_wildlife.settle()
	_weather_view.snap()


## Applies the flags that put the views in a situation, and hands the ones that wait for the
## drawn world to the DebugRunner.
func _apply_start_options() -> void:
	_build_mode.start_options = _options
	_build_mode.apply_start_options()
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
		_bag_screen.open()
	if _options.character:
		_character_screen.open()
	if _options.skills:
		_character_screen.open_tab(CharacterScreen.Tab.SKILLS)
	if _options.crafting:
		_crafting_screen.open()
	if not _options.console.is_empty():
		_console_view.open()
		for line in _options.console:
			_console_view.run_line(line)
	if _options.footprints != StartupOptions.NO_TILE:
		DebugFootprints.create(_state.world, _options.footprints, _options.snow >= 0.5)
	_debug = DebugRunner.new(_options)
	_debug.state = _state
	_debug.view = _view
	_debug.wildlife = _wildlife
	_debug.tiredness_view = _tiredness_view
	_debug.interior_view = _interior_view
	_debug.storage_screen = _storage_screen
	_debug.crafting_screen = _crafting_screen
	_debug.process_screen = _process_screen
	_debug.chat_screen = _chat_screen
	_debug.open_chat = _open_chat
	_debug.try_sleep = _blackout.try_sleep
	_debug.pass_door = _pass_door
	_debug.open_menu = _menu.open_page
	_debug.open_load_dialog = _load_dialog.open_saves.bind(_options.save_path)
	_debug.save_screenshot_and_quit = _save_screenshot_and_quit


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		# Closed while the question about the save is up: there is no game to save yet.
		if _state == null:
			get_tree().quit()
			return
		_save_and_quit()


func _unhandled_input(event: InputEvent) -> void:
	# A collapse, the message on black and the sleep fade take all input (the message screen
	# reads its own key): no menu, console, hotbar or hammer until the player is up again.
	if _blackout.is_in_transition:
		return
	if event.is_action_pressed("console") and _can_open_console():
		# The key that opens it must not be typed into the input line.
		get_viewport().set_input_as_handled()
		_console_view.open()
		return
	if event.is_action_pressed("pause"):
		# The windows close themselves on Escape (see Modal). Here it closes the console, then
		# dismisses build mode (until the player holds the hammer again), then opens the menu.
		if _console_view.is_open():
			_console_view.close()
			return
		if _build_mode.is_active():
			_builder.dismiss()
		else:
			_menu.open()
		return
	# The open console takes the input: the player neither walks nor acts.
	if _console_view.is_open():
		return
	var can_use := _can_use()
	# The art switches with a screen open too, so the character screen shows the switch.
	if _switch_art_set(event) or _quick_save_or_load(event) or _screens_take(event):
		return
	# A SubViewport only gets the events that are pushed into it. That does not mark the
	# event as handled here, so Main still sees what BuildMode consumed.
	_world.push_input(event)
	var hotbar_slot := _hotbar_slot_of(event)
	if event.is_action_pressed("toggle_coordinates"):
		_coordinates_hud.toggle()
	elif event.is_action_pressed("toggle_paths"):
		_paths_hud.toggle()
	elif event.is_action_pressed("toggle_fast_forward"):
		_fast_forward = not _fast_forward
	elif hotbar_slot != -1:
		_state.player.inventory.select(hotbar_slot)
		_builder.resume()
	elif HotbarWheel.is_hotbar_wheel(event):
		_wheel_progress = HotbarWheel.turned(_wheel_progress, HotbarWheel.turn_of(event))
		var steps := HotbarWheel.whole_slots(_wheel_progress)  # the rest waits for more turning
		_wheel_progress -= steps
		if steps != 0:
			_state.player.inventory.select_next(steps)
			_builder.resume()
	elif event.is_action_pressed("drop_item") and can_use:
		_state.drop_from_inventory(_state.player.inventory.selected_slot)
	# E also picks the next building (outdoors), so the hammer in hand doesn't open a chest or put
	# the player to bed.
	elif event.is_action_pressed("interact") and not _build_mode.is_active():
		_interact()
	elif _is_use_event(event) and can_use and (_eat_held() or _state.switch_held_lantern()):
		pass  # No target: a held food is eaten, the lantern lit or put out, instead of a tile used.
	elif event.is_action_pressed("use") and can_use:
		_use_swing.use_on(_use_highlight.targeting())
	elif event.is_action_pressed("use_click") and can_use:
		var target := _use_highlight.targeting()
		if target.source == Targeting.Source.MOUSE and not _state.ring_bell_in_reach(target.tile):
			_use_swing.use_on(target)
		# A click also counts as the mouse being in use. One that wakes an idle mouse (the target
		# is then the facing tile) does not act.
		_use_highlight.note_mouse_activity()


func _process(delta: float) -> void:
	_tick_clock(delta)
	var hour := _state.clock.total_minutes() / GameClock.MINUTES_PER_HOUR
	if hour != _soil_shown_hour:
		_soil_shown_hour = hour
		_view.refresh_soil(_state.last_hour_rain())
		_state.refresh_mud()
	_autosave_on_time(delta)
	_tiredness_view.is_awake = not _blackout.is_in_transition
	_weather_view.visible_region = _camera.visible_region()
	_weather_view.show_weather(_weather, _tint.color, _tint.daylight)
	_view.ambient_motion.update(delta, _weather_view.wind, _weather_view.rain)
	_view.ambient_motion.show_tide(Tide.level(_state.clock.total_minutes()))
	if _coordinates_hud.visible:
		_coordinates_hud.show_position(
			_state.player.tile(),
			_state.is_inside(),
			CoordinatesHud.weather_and_sun_text(
				_weather, _state.sun, _state.clock.day, _snow_cover, _frost
			)
		)
	var is_in_play := not _is_any_screen_open()
	var is_pointer_on_gui := (
		Modal.is_any_open()
		and (get_viewport().gui_get_hovered_control() != null or get_viewport().gui_is_dragging())
	)
	_use_highlight.is_pointer_on_gui = is_pointer_on_gui
	_build_mode.is_pointer_on_gui = is_pointer_on_gui
	_use_highlight.is_enabled = (
		is_in_play
		and not is_pointer_on_gui
		and not _builder.is_building()
		and not _blackout.is_in_transition
	)
	# On horseback E gets off instead.
	var can_act := is_in_play and not _build_mode.is_active() and not _blackout.is_in_transition
	var can_chat := can_act and _state.player.horse == null
	var aim := _use_highlight.targeting()
	_action_hint.show_for(_state, _settings, aim.tile, can_act)
	var is_aiming_at_world := is_in_play and not is_pointer_on_gui and not _builder.is_building()
	_tooltip_view.world_text = WorldHoverText.text_for(_state, aim, is_aiming_at_world)
	_tooltip_view.world_cursor = (
		_mouse_in_ui_units()
		if aim.source == Targeting.Source.MOUSE
		else _camera.world_to_ui((Vector2(aim.tile) + Vector2(0.5, 0.5)) * TerrainTileset.TILE_SIZE)
	)
	_npc_name_tag.show_over(
		Interaction.npc_to_chat(_state, aim.tile) if can_chat else null, _camera
	)
	# Build mode only counts outdoors, in play and not during a transition; it keeps processing,
	# to clear its message when it goes off.
	_build_mode.visible = is_in_play and not _state.is_inside() and not _blackout.is_in_transition
	_build_menu.visible = _build_mode.is_active()
	# Out of energy after a use (or in a game saved while passing out), or up too late. A game
	# that starts so shows the world first.
	var is_drawn := _view.is_settled or _state.is_inside()
	if (
		(_state.is_out_of_energy() or _state.is_up_too_late)
		and is_drawn
		and not _blackout.is_in_transition
	):
		_blackout.pass_out()
	if not _blackout.is_in_transition:
		var direction := Vector2.ZERO
		if not _is_any_screen_open():
			var is_menu_up := _build_mode.is_active() and not _builder.is_taking_down()
			direction = BuildMode.walk_direction(is_menu_up)
		_state.is_sprint_held = Input.is_action_pressed("sprint")
		_player_view.walk_speed = _state.walk_speed_factor()
		_player_view.is_trotting = _state.is_trotting()
		_state.walk(direction, delta, _player_view.walk_speed)
		if _state.player.horse != null and direction != Vector2.ZERO and _state.is_door_ahead():
			_harvest_hud.show_note(GET_OFF_FIRST)
		_state.collect_ground_items(delta)
		_interior_view.cover_bed(_state.player.bed_lying_in)
		_object_cover.cover(_state.player.bed_lying_in)
		if _state.door_underfoot():
			_blackout.fade_through(_pass_door)
	# The world, its animals too, stands still while the player is in a house, and while the sleep
	# is made up for in steps; but the villagers on a trip go on over the masks, so they are where
	# one expects them when the player comes out.
	if not _blackout.is_making_up_time:
		if _state.is_inside():
			_state.npcs.update_unseen(delta, _state.world, _state.clock)
			_state.npcs.update_inside(delta, _state.current_map as Interior, _state.clock)
		else:
			_state.livestock.update(delta, _state.world, _state.player.position, _state.clock)
			_state.npcs.update(delta, _state.world, _state.player.position, _state.clock)
			_view.player_feet = _player_view.position
			_view.player_size = (
				Occlusion.RIDER_SIZE if _state.player.horse != null else Occlusion.PLAYER_SIZE
			)
			_residency.set_focus(_state.player.tile())
			_residency.update(func() -> bool: return not _view.is_drawing())
			_ground_item_view.set_focus(_state.player.tile())
			_npc_views.set_focus(_state.player.tile())
	_debug.update(delta)


## Quits once the game is saved, or the player chose to quit without (see SaveBeforeQuit).
func _save_and_quit() -> void:
	if await _is_saved_for_quit():
		get_tree().quit()


## Whether quitting may go on: the game is saved, or the player chose to quit without (see
## SaveBeforeQuit). A sleep that is being made up for ends first, the waking included, so that the
## save is of a whole morning.
func _is_saved_for_quit() -> bool:
	while _blackout.is_making_up_time:
		await get_tree().process_frame
	var saving := SaveBeforeQuit.new(_saves, _state, _options.save_path, _choice_dialog)
	return await saving.is_quit_allowed()


## Eats the held food, if any, and says how much energy it gave. Returns whether it ate.
func _eat_held() -> bool:
	var energy_before := _state.player.energy
	if not _state.eat_held():
		return false
	_harvest_hud.show_note("+%s energy" % roundi(_state.player.energy - energy_before))
	return true


func _is_use_event(event: InputEvent) -> bool:
	return event.is_action_pressed("use") or event.is_action_pressed("use_click")


## Whether a window or the console is open: the player neither walks nor acts. The bag and the
## character window are played beside (see Modal `dock`).
func _is_any_screen_open() -> bool:
	return Modal.is_blocking_open() or _console_view.is_open()


func _can_open_console() -> bool:
	return not _console_view.is_open() and not get_tree().paused and not _blackout.is_in_transition


func _can_use() -> bool:
	return not _blackout.is_in_transition and not _build_mode.is_active()


## The hotbar slot (0 to 7) whose key `event` presses, or -1.
func _hotbar_slot_of(event: InputEvent) -> int:
	for slot in Inventory.HOTBAR_SIZE:
		if event.is_action_pressed("hotbar_%d" % (slot + 1)):
			return slot
	return -1


## Holding the use key or the mouse button swings again as soon as the swing is over. A click on a
## bell frame rang it once when it was pressed: it does not ring again, nor swing.
func _repeat_held_use() -> void:
	if not _can_use() or _console_view.is_open():
		return
	var target := _use_highlight.targeting()
	var is_click_held := (
		Input.is_action_pressed("use_click")
		and target.source == Targeting.Source.MOUSE
		and Interaction.bell_frame_to_ring(_state, target.tile) == null
	)
	if Input.is_action_pressed("use") or is_click_held:
		_use_swing.use_on(target)


## What follows a use of a tile, when it is done: the sound of a use that failed, the signs of
## tiredness, a note.
func _after_use(use: ToolUse.Use, target_tile: Vector2i) -> void:
	_sounds.failed_use(use, target_tile)
	_tiredness_view.acted(use)
	if USE_NOTES.has(use):
		_harvest_hud.show_note(USE_NOTES[use])
	if use == ToolUse.Use.NEEDS_BETTER_TOOL:
		var tool_name := ItemTypes.tool_name(_state.player.inventory.held_item())
		_harvest_hud.show_note("Needs a better %s." % tool_name)


## Where the camera looks. The player is drawn on the art pixel grid (rounded), the camera
## is not, so the world scrolls smoothly and the player wobbles by up to half an art pixel
## against the screen (the user chose this over a pixel-locked camera).
func _camera_target() -> Vector2:
	return _state.player.position * TerrainTileset.TILE_SIZE + _options.camera_shift


## Saves in the background when the player's interval of play has passed. A fade, a collapse or
## an open window (the console too) holds it back to the next frame that is free of them; time that
## the game is paused for (the pause menu, a chat) is not counted, as `_process` does not run.
func _autosave_on_time(delta: float) -> void:
	_autosave_timer.tick(delta)
	var is_free := not _blackout.is_in_transition and not _is_any_screen_open()
	if is_free and _autosave_timer.is_due(_settings.autosave_minutes):
		_saves.save_in_background(_state, _options.save_path, SaveHeader.Kind.AUTOSAVE)


## Real time to whole game minutes; the fraction carries over to the next frame.
func _tick_clock(delta: float) -> void:
	# A screenshot with TIME=... must show exactly that time, unless it is told to wait. Time
	# stands still while the screen is black (a message there may wait long for a key), and
	# while the console's freeze is on.
	if _debug.is_clock_stopped() or _fade_screen.is_black() or _state.cheats.is_time_stopped:
		return
	var rate := (
		GameClock.GAME_MINUTES_PER_REAL_SECOND * (FAST_FORWARD_FACTOR if _fast_forward else 1.0)
	)
	_pending_minutes += delta * rate
	var whole_minutes := int(_pending_minutes)
	if whole_minutes > 0:
		_pending_minutes -= whole_minutes
		_state.pass_awake_time(whole_minutes)
		_weather_view.minutes_passed(whole_minutes)
		_show_clock()


## Switches between the classic and the new art (see ArtSet) on its key; whether it was that key.
func _switch_art_set(event: InputEvent) -> bool:
	if not event.is_action_pressed("toggle_art_set"):
		return false
	_toggle_classic_art()
	return true


func _toggle_classic_art() -> void:
	_settings.set_classic_art(not ArtSet.is_classic)


## The crafting button beside the bag button does what the crafting key does.
func _on_crafting_requested() -> void:
	if _crafting_screen.can_open_on_key():
		_toggle_crafting()


func _toggle_crafting() -> void:
	# On horseback only the inventory and eating are possible; an open screen still closes.
	if _crafting_screen.is_open() or _state.player.horse == null:
		_crafting_screen.toggle()
	else:
		_harvest_hud.show_note(GET_OFF_FIRST)


## Opens and closes the windows on their keys; a window's key does nothing while another window is
## open (see Modal.can_open_on_key). Returns whether a window took the event: one that is open
## takes all the input, so the player neither walks nor acts.
func _screens_take(event: InputEvent) -> bool:
	if event.is_action_pressed("crafting") and _crafting_screen.can_open_on_key():
		_toggle_crafting()
		return true
	if event.is_action_pressed("inventory") and _bag_screen.can_open_on_key():
		_bag_screen.toggle()
		return true
	if event.is_action_pressed("character", false, true) and _character_screen.can_open_on_key():
		_character_screen.toggle_tab(CharacterScreen.Tab.CHARACTER)
		return true
	if event.is_action_pressed("skills") and _character_screen.can_open_on_key():
		_character_screen.toggle_tab(CharacterScreen.Tab.SKILLS)
		return true
	return _is_any_screen_open()


## E: on horseback, gets off. Else speaks to the villager in front, gets on the saddled horse in
## front, opens the chest or station in reach, rings the bell frame in reach or sleeps in the bed.
func _interact() -> void:
	var choice := Interaction.choice_at(_state, _use_highlight.targeting().tile)
	match choice.kind:
		Interaction.Kind.DISMOUNT:
			if not _state.dismount():
				_harvest_hud.show_note("No room to get off here.")
		Interaction.Kind.CHAT:
			_open_chat(choice.subject)
		Interaction.Kind.MOUNT:
			_state.mount(choice.subject)
		Interaction.Kind.OPEN_STATION_GRID:
			_process_screen.open_station(
				ProcessStation.new(_state, Crafting.new(_state), choice.subject)
			)
		Interaction.Kind.OPEN_CHEST:
			_storage_screen.open_chest(choice.subject, _state.player)
		Interaction.Kind.OPEN_FIRE:
			_fire_screen.open_fire(choice.subject, _state)
		Interaction.Kind.OPEN_CRAFTING:
			_crafting_screen.open_station(choice.subject)
		Interaction.Kind.RING_BELL:
			_state.ring_bell_in_reach()
		Interaction.Kind.SLEEP:
			_blackout.try_sleep()


## Opens the chat with a villager, who turns to the player (the chat pauses the game).
func _open_chat(npc: Npc) -> void:
	_state.npcs.talk_to(npc, _state.player.position)
	_chat_screen.open_chat(npc, _state)


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
	_residency.is_held = is_inside or _blackout.is_making_up_time
	_interior_view.visible = is_inside
	if is_inside:
		_wildlife.clear()
		_interior_view.show_interior(_state.current_map)
	_interior_npc_views.show_room(_state.current_map as Interior if is_inside else null)
	_player_view.reparent(_interior_view.entities if is_inside else _view.entities, false)
	_use_highlight.reparent(_interior_view if is_inside else _view, false)
	_show_clock()


## Starts the sounds of the game once everything that makes one exists: the footsteps, work and
## pickups, the buttons of the menus, the opening and closing of menus, screens and console, and
## the weather's and the animals' ambience.
func _start_sounds() -> void:
	add_child(_sounds)
	_sounds.listen(_audio, _state, _view, _player_view, _build_mode)
	_sounds.click_on_press_in(_hotbar)
	for panel: Node in [
		_menu, _console_view, _chat_screen, _bag_screen, _character_screen, _crafting_screen
	]:
		_sounds.click_on_press_in(panel)
		_sounds.watch_panel(panel.is_open)
	_sounds.click_on_press_in(_storage_screen)
	_sounds.click_on_press_in(_process_screen)
	_sounds.click_on_press_in(_fire_screen)
	_sounds.watch_panel(_process_screen.is_open)
	_sounds.watch_panel(_storage_screen.is_open, &"chest_open", &"chest_close")
	add_child(_ambience)
	_ambience.listen(_audio, _state, _wildlife, _weather_view)
	add_child(_sea_sounds)
	_sea_sounds.listen(_audio, _state)


## The game F8 has just loaded, else the newest save that can be loaded, or a new one if there is
## none or `--new-game` is given. A save that is refused is moved aside, the player is told, and
## the save before it is tried. A save that holds content the game no longer has is up to the
## player: null if they cancel (the game then quits, with the file as it was).
func _load_or_start_game() -> GameState:
	if _resumed_state != null:
		return _resumed_state
	if _options.new_game:
		return GameState.new_game(WORLD_SEED, true)
	var paths := SaveList.paths_newest_first(_options.save_path)
	for index in paths.size():
		var loaded := SaveFile.load_game(paths[index])
		match loaded.outcome:
			LoadResult.Outcome.READY:
				return loaded.state
			LoadResult.Outcome.REFUSED:
				push_error("Can't load %s: %s" % [paths[index], "; ".join(loaded.problems)])
				var moved_to := SaveFile.move_aside(paths[index])
				var has_older_save := index < paths.size() - 1
				await _save_questions.tell_refused(loaded.reason, moved_to, has_older_save)
			LoadResult.Outcome.ASK:
				if await _save_questions.is_missing_content_loaded(
					loaded.missing, loaded.backup_path, "Cancel and quit the game"
				):
					var dropped := loaded.load_dropping_missing()
					if dropped == null:
						await _save_questions.tell_copy_failed(loaded.copy_error)
					return dropped
				return null
	return GameState.new_game(WORLD_SEED, true)


## The settings, with the player's key bindings applied to the input map.
func _load_settings() -> GameSettings:
	# The settings take the project's key bindings as the defaults, so after F8 restarted the scene
	# they must not be the player's own.
	InputMap.load_from_project_settings()
	var settings := GameSettings.new(_options.settings_path)
	settings.load_file()
	return settings


## Scales the whole window's 2D canvas, the UI included. The world screen is a full-rect
## TextureRect drawn through UV, so it keeps filling the window and the world view is unchanged.
func _apply_ui_scale(ui_scale: float) -> void:
	get_tree().root.content_scale_factor = ui_scale


func _show_save_result(succeeded: bool) -> void:
	if succeeded:
		_notifications.post(SAVE_NOTE, "Saved")
	else:
		_notifications.post(SAVE_NOTE, "Could not save the game", NotificationHud.Tone.ERROR)


## F9 saves now, F8 loads; whether it was one of those keys. Both work with a window open too.
func _quick_save_or_load(event: InputEvent) -> bool:
	if event.is_action_pressed("quick_save"):
		_saves.save_in_background(_state, _options.save_path, SaveHeader.Kind.QUICK_SAVE)
	elif event.is_action_pressed("quick_load"):
		_quick_load()
	else:
		return false
	return true


## F8: puts the player into the newest save (see QuickLoadFlow).
func _quick_load() -> void:
	await _quick_load_flow().run_newest(_options.save_path)


## The save picked in the load dialog: after a question about the game now being played, the
## player goes into it. Cancel goes back to the list.
func _load_picked(entry: SaveEntry) -> void:
	if await _save_questions.is_load_confirmed(entry.header):
		await _quick_load_flow().run(entry.path)
	else:
		_load_dialog.open_saves(_options.save_path)


## The pause menu's New game: after a question, the game is saved and a new world starts, the whole
## scene again as for a load. A save that fails keeps the game as it is.
func _start_new_game() -> void:
	if not await _save_questions.is_new_game_confirmed():
		return
	while _blackout.is_making_up_time:
		await get_tree().process_frame
	if not _saves.save_and_wait(_state, _options.save_path, SaveHeader.Kind.QUICK_SAVE):
		var note := "Not saved, so no new game: %s" % _saves.last_error
		_notifications.post(QuickLoadFlow.LOAD_NOTE, note, NotificationHud.Tone.ERROR)
		return
	QuickLoad.start_new(GameState.new_game(WORLD_SEED, true))
	if get_tree().reload_current_scene() != OK:
		QuickLoad.take()
		var error := "Can't restart the game"
		_notifications.post(QuickLoadFlow.LOAD_NOTE, error, NotificationHud.Tone.ERROR)


func _quick_load_flow() -> QuickLoadFlow:
	return QuickLoadFlow.new(_saves, _save_questions, _notifications, get_tree())


## The message of build mode: in the build menu while it picks, as under its row the HUD's
## message would be hidden; taking down, the HUD's above the hotbar.
func _show_build_message(text: String) -> void:
	var in_menu := _build_menu.takes_messages()
	_build_menu.show_message(text if in_menu else "")
	_message.text = "" if in_menu else text


func _show_clock() -> void:
	# The weather only changes with the minute, the map or a console command, which all end here.
	_weather = _state.current_weather()
	if _state.is_inside():
		_tint.show_interior()
	else:
		_tint.show_time(_state.clock, _weather.cloud_cover)
	_view.set_light_strength(_tint.light_strength())
	_player_view.light_strength = _tint.light_strength()
	# The ground, the plants and the houses follow the weather by the minute, by shader; their
	# pictures only change with the day.
	_snow_cover = _state.current_snow_cover()
	_frost = _state.current_frost()
	var thaw := _state.current_thaw()
	_view.show_ground_cover(_state.clock.day, _snow_cover, thaw, _frost)
	_state.world.footprints.advance_to(
		_state.clock.total_minutes(), _weather.rain, _weather.snow, thaw
	)
	_view.refresh_looks(_state.clock.day)
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
