extends Node2D
## The game scene, the composition root: owns the GameState and makes the views, the flows and the
## services around it, wires them to each other in an explicit order (the layers of the screens, the
## order the input reaches them, the steps of a frame) and feeds the player's input to the state.
## The world is drawn into WorldViewport (one art pixel per pixel) and shown on the window by
## CameraController; the UI is drawn on the window itself. The camera and chunk streaming follow the
## player.
##
## The game is loaded from the save at start and saved after sleeping, after passing out and on
## quit (see SaveFile). The debug flags after `--` on the Godot command line are documented in
## StartupOptions.

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
var _console_view := ConsoleView.new()
var _map_screen := MapScreen.new()
var _npc_name_tag := NpcNameTag.new()
var _action_hint := ActionHintView.new()
var _cheat_hud := CheatHud.new()
var _interior_view := InteriorView.new()
var _object_cover := ObjectCover.new()
var _weather_view := WeatherView.new()
var _wildlife := WildlifeView.new()
var _fade_screen := FadeScreen.new()
var _blackout: BlackoutFlow
var _screen_keys: ScreenKeys
var _hotbar_keys: HotbarKeys
var _session: SessionFlow
var _play_loop: PlayLoop
var _clock_views: ClockViews
var _map_switch: MapSwitch
var _aim_views: AimViews
var _walk_flow: WalkFlow
var _interact: InteractFlow
var _flows: FeatureFlows
var _interactions := InteractionRegistry.new()
var _debug: DebugRunner
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
	_clock_views.show_clock()
	if _resumed_state != null:
		_notifications.post(QuickLoadFlow.LOAD_NOTE, "New game" if is_new_game else "Loaded")
	if is_new_game:
		# Saved at once, so F8 or a crash comes back to the new world, not to the game before it.
		_saves.save_and_wait(_state, _options.save_path, SaveHeader.Kind.QUICK_SAVE)
	if _state.is_inside():
		_map_switch.show_current_map()


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
	_state = await GameLoader.new(_options, _save_questions).load_or_start(_resumed_state)
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
			_clock_views.show_clock()
	)
	# Quitting saves first (see _notification).
	get_tree().auto_accept_quit = false
	DebugGameOptions.apply(_options, _state)


## What the music is chosen by now (see MusicDirector); null until the game is loaded.
func _music_moment() -> MusicMoment:
	return null if _state == null else MusicMoment.of(_state, ArtSet.is_classic)


## Puts every view in the tree, in the order they are drawn and take input.
func _make_views() -> void:
	_interact = InteractFlow.new()
	_interact.state = _state
	# The flows are made before the views: QuestMarkView and FriendshipPopups, which two of them put
	# among the entities, now come before the player view and the object cover. Sprites at the same
	# depth sort the other way round, which no one can tell.
	_flows = FeatureFlows.new(
		_state,
		_settings,
		_hotbar,
		_sounds,
		_notifications,
		_view.entities,
		_interactions,
		_interact,
		_toggle_classic_art
	)
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
	add_child(_flows.crafting)
	add_child(_map_screen)
	add_child(_flows.storage)
	add_child(_flows.trade)
	add_child(_flows.process)
	# Where the fire's window was layered, before the HUD and the console over it.
	add_child(_flows.campfire)
	add_child(_cheat_hud)
	add_child(_console_view)
	add_child(_flows.chat)
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
	_flows.chat.dialogue.compact_all(_state)


## Shows the state in the views and wires what they report back.
func _connect_state_and_views() -> void:
	_clock_views = ClockViews.new(
		_state, _view, _tint, _hud, _player_view, _weather_view, _camera, _coordinates_hud
	)
	_map_switch = MapSwitch.new()
	_map_switch.state = _state
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
	_blackout.show_current_map = _map_switch.show_current_map
	_blackout.show_clock = _clock_views.show_clock
	add_child(_blackout)
	_session = SessionFlow.new()
	_session.state = _state
	_session.saves = _saves
	_session.save_path = _options.save_path
	_session.save_questions = _save_questions
	_session.choice_dialog = _choice_dialog
	_session.load_dialog = _load_dialog
	_session.notifications = _notifications
	_session.blackout = _blackout
	add_child(_session)
	_interact.use_highlight = _use_highlight
	_interact.harvest_hud = _harvest_hud
	_interact.blackout = _blackout
	_interact.console_view = _console_view
	var clock_ticker := GameClockTicker.new(_state, _weather_view, _clock_views.show_clock)
	clock_ticker.is_held = func() -> bool:
		return _debug.is_clock_stopped() or _fade_screen.is_black()
	_play_loop = PlayLoop.new(
		_state,
		clock_ticker,
		_blackout,
		_residency,
		_view,
		_player_view,
		_ground_item_view,
		_npc_views
	)
	_map_switch.audio = _audio
	_map_switch.view = _view
	_map_switch.weather_view = _weather_view
	_map_switch.play_loop = _play_loop
	_map_switch.interior_view = _interior_view
	_map_switch.interior_npc_views = _interior_npc_views
	_map_switch.wildlife = _wildlife
	_map_switch.player_view = _player_view
	_map_switch.use_highlight = _use_highlight
	_map_switch.clock_views = _clock_views
	_view.show_world(_residency)
	_ground_item_view.show_items(_state.world, _view.entities)
	_view.tree_felled.connect(_ground_item_view.hold_hops_from)
	_wildlife.show_wildlife(_state, _view, _camera)
	_state.simulation.skipped.connect(_on_time_skipped)
	_state.crop_warnings.warned.connect(_notifications.post_line)
	_action_hint.interactions = _interactions
	# One line per feature, in the order their screens are layered and take input.
	for feature: Node in [
		_flows.quest, _flows.friendship, _flows.surge, _flows.barter, _flows.stall
	]:
		add_child(feature)
	_npc_views.show_npcs(_state.npcs, _view.entities, _state.world)
	_interior_npc_views.show_npcs(_state.npcs, _interior_view.entities)
	# Chats longer than the setting (a saved game's, or one lowered in the menu, which is
	# applied once it is closed rather than at every step) are compacted.
	_apply_villager_memory_settings()
	_menu.closed.connect(_apply_villager_memory_settings)
	add_child(StoryJudging.new(_flows.chat.dialogue, _state))
	add_child(WordRating.new(_flows.chat.dialogue, _state))
	var day_planner := DayPlanner.new(_flows.chat.dialogue, _state)
	add_child(day_planner)
	var speech := NpcSpeech.new()
	add_child(speech)
	speech.is_nonstop = _options.bubbles
	speech.show_for(_state, _flows.chat.dialogue, _camera.view_rect, _camera.world_to_ui)
	_builder = Builder.new(_state)
	_hotbar_keys = HotbarKeys.new(_state.player.inventory, _builder)
	_aim_views = AimViews.new()
	_aim_views.state = _state
	_aim_views.settings = _settings
	_aim_views.options = _options
	_aim_views.camera = _camera
	_aim_views.builder = _builder
	_aim_views.blackout = _blackout
	_aim_views.use_highlight = _use_highlight
	_aim_views.build_mode = _build_mode
	_aim_views.build_menu = _build_menu
	_aim_views.action_hint = _action_hint
	_aim_views.tooltip_view = _tooltip_view
	_aim_views.npc_name_tag = _npc_name_tag
	_walk_flow = WalkFlow.new(
		_state,
		_blackout,
		_view,
		_build_mode,
		_builder,
		_player_view,
		_harvest_hud,
		_interior_view,
		_object_cover,
		_map_switch.pass_door
	)
	_screen_keys = ScreenKeys.new(
		_state, _bag_screen, _character_screen, _flows.crafting.screen, _harvest_hud
	)
	_hotbar.crafting_requested.connect(_screen_keys.on_crafting_requested)
	_build_mode.world = _state.world
	_build_mode.builder = _builder
	_build_mode.camera = _camera
	_build_mode.message_changed.connect(_show_build_message)
	_house_menu = HouseMenu.new(_house_dialog, _state.homes)
	_build_mode.building_menu_requested.connect(_house_menu.open)
	_bag_screen.drop_requested.connect(_state.drop_from_inventory)
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
	_character_screen.show_quests(_state)
	_character_screen.show_neighbours(_state)
	_cheat_hud.show_cheats(_state.cheats)
	_map_screen.show_state(_state)
	_map_screen.teleporter = func(tile: Vector2i) -> Array[String]:
		return _console_view.run_line("tp %d %d" % [tile.x, tile.y])
	_console_view.show_state(
		_state,
		_wildlife.spawn_in_view,
		_wildlife.remove_kind,
		_music,
		day_planner.replan,
		_map_screen.toggled,
		_interact.open_shop
	)
	# A teleport moves the player far: the camera jumps with them instead of gliding.
	_console_view.command_ran.connect(
		func() -> void:
			_camera.rig.follow(_camera_target)
			# `reset` and `tp` can take the player to another map.
			if _map_switch.has_map_changed():
				_map_switch.show_current_map()
			_clock_views.show_clock()
			# The map takes the keys the console would.
			if _map_screen.is_open():
				_console_view.close()
	)
	_menu.save_and_quit_requested.connect(_session.save_and_quit)
	_menu.load_requested.connect(_load_dialog.open_saves.bind(_options.save_path))
	_menu.new_game_requested.connect(_session.start_new_game)
	_load_dialog.load_requested.connect(_session.load_picked)
	_menu.volume_tested.connect(_audio.play_volume_test)
	_saves.started.connect(
		func() -> void:
			_notifications.hold(SessionFlow.SAVE_NOTE, "Saving...")
			_autosave_timer.restart()
	)
	_saves.finished.connect(_session.show_save_result)


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
	if _options.neighbours:
		_character_screen.open_tab(CharacterScreen.Tab.NEIGHBOURS)
	if _options.crafting:
		_flows.crafting.screen.open()
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
	_debug.storage_screen = _flows.storage.screen
	_debug.crafting_screen = _flows.crafting.screen
	_debug.process_screen = _flows.process.screen
	_debug.chat_screen = _flows.chat.screen
	_debug.open_chat = _interact.open_chat
	_debug.open_shop = _interact.open_shop
	_debug.try_sleep = _blackout.try_sleep
	_debug.pass_door = _map_switch.pass_door
	_debug.open_menu = _menu.open_page
	_debug.open_load_dialog = _load_dialog.open_saves.bind(_options.save_path)
	_debug.save_screenshot_and_quit = _save_screenshot_and_quit


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		# Closed while the question about the save is up: there is no game to save yet.
		if _state == null:
			get_tree().quit()
			return
		_session.save_and_quit()


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
	# The art switches with a screen open too, so the character screen shows the switch. An open
	# screen takes all the input: the player neither walks nor acts.
	if (
		_switch_art_set(event)
		or _session.quick_save_or_load(event)
		or _screen_keys.take(event)
		or _is_any_screen_open()
	):
		return
	# A SubViewport only gets the events that are pushed into it. That does not mark the
	# event as handled here, so Main still sees what BuildMode consumed.
	_world.push_input(event)
	if event.is_action_pressed("toggle_coordinates"):
		_coordinates_hud.toggle()
	elif event.is_action_pressed("toggle_paths"):
		_paths_hud.toggle()
	elif event.is_action_pressed("toggle_fast_forward"):
		_play_loop.toggle_fast_forward()
	elif _hotbar_keys.take(event):
		pass
	elif event.is_action_pressed("drop_item") and can_use:
		_state.drop_from_inventory(_state.player.inventory.selected_slot)
	# E also picks the next building (outdoors), so the hammer in hand doesn't open a chest or put
	# the player to bed.
	elif event.is_action_pressed("interact") and not _build_mode.is_active():
		_interact.interact(_interactions)
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
	_play_loop.begin_frame(delta)
	_clock_views.update(delta)
	_autosave_on_time(delta)
	_tiredness_view.is_awake = not _blackout.is_in_transition
	_aim_views.update(not _is_any_screen_open())
	_walk_flow.update(delta, _is_any_screen_open())
	_play_loop.move_world(delta)
	_debug.update(delta)


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


## Holding the use key or the mouse button swings again as soon as the swing is over. A click on a
## bell frame rang it once when it was pressed: it does not ring again, nor swing.
func _repeat_held_use() -> void:
	if not _can_use() or _is_any_screen_open():
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
	var note := UseNotes.of(use, _state.player.inventory)
	if note != "":
		_harvest_hud.show_note(note)


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


## Switches between the classic and the new art (see ArtSet) on its key; whether it was that key.
func _switch_art_set(event: InputEvent) -> bool:
	if not event.is_action_pressed("toggle_art_set"):
		return false
	_toggle_classic_art()
	return true


func _toggle_classic_art() -> void:
	_settings.set_classic_art(not ArtSet.is_classic)


## Starts the sounds of the game once everything that makes one exists: the footsteps, work and
## pickups, the buttons and the opening and closing of the menu, the console, the bag and the
## character window, and the weather's and the animals' ambience. The flows' screens are heard
## from `listen` on, as they registered themselves.
func _start_sounds() -> void:
	add_child(_sounds)
	_sounds.listen(_audio, _state, _view, _player_view, _build_mode)
	_sounds.click_on_press_in(_hotbar)
	for panel: Node in [_menu, _console_view, _bag_screen, _character_screen]:
		_sounds.click_on_press_in(panel)
		_sounds.watch_panel(panel.is_open)
	add_child(_ambience)
	_ambience.listen(_audio, _state, _wildlife, _weather_view)
	add_child(_sea_sounds)
	_sea_sounds.listen(_audio, _state)


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


## The message of build mode: in the build menu while it picks, as under its row the HUD's
## message would be hidden; taking down, the HUD's above the hotbar.
func _show_build_message(text: String) -> void:
	var in_menu := _build_menu.takes_messages()
	_build_menu.show_message(text if in_menu else "")
	_message.text = "" if in_menu else text


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
