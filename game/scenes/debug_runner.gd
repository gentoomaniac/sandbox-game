class_name DebugRunner
extends RefCounted
## The debug flags that wait for the world to be drawn: Main calls `update` once per frame and
## each step runs the moment its condition holds, once. Also the screenshot: it is taken a few
## frames after every step is done, and after the `--screenshot-delay`.
##
## What a step needs from Main is set after `new()`; the flags are in StartupOptions.

## Frames to wait before a screenshot once everything is in place, for tile maps to catch up.
const SETTLE_FRAMES := 3
## Animals of each kind (but one flock) that `--wildlife` puts in view.
const WILDLIFE_COUNT := 4

var state: GameState
var view: WorldView
var wildlife: WildlifeView
var tiredness_view: TirednessView
var interior_view: InteriorView
var storage_screen: StorageScreen
## Main's doings, as `func()` unless noted.
var try_sleep: Callable
var pass_door: Callable
var open_menu: Callable  # func(page: PauseMenu.Page)
var save_screenshot_and_quit: Callable

var _options: StartupOptions
# What is still to do; a step clears its own.
var _is_entering_first_house: bool
var _is_sleeping: bool
var _chest_tile: Vector2i
var _chest_inside_tile: Vector2i
var _is_storage_to_open: bool
var _are_animals_to_spawn: bool
var _hit_tile: Vector2i
var _harvest_tile: Vector2i
var _menu_page: int
var _opened_chest: WorldObject
var _settled_frames := 0
var _screenshot_delay: float


func _init(options: StartupOptions) -> void:
	_options = options
	_is_entering_first_house = options.inside
	_is_sleeping = options.sleep
	_chest_tile = options.chest
	_chest_inside_tile = options.chest_inside
	_is_storage_to_open = options.storage
	_are_animals_to_spawn = not options.wildlife.is_empty()
	_hit_tile = options.hit
	_harvest_tile = options.harvest
	_menu_page = options.menu
	_screenshot_delay = options.screenshot_delay


## A screenshot with TIME=... must show exactly that time, unless it is told to wait.
func is_clock_stopped() -> bool:
	return _options.screenshot != "" and _screenshot_delay == 0.0


func update(delta: float) -> void:
	if _is_entering_first_house:
		_enter_first_house()
	if _is_sleeping and view.is_settled:
		_is_sleeping = false
		try_sleep.call()
	_place_chests()
	if _are_animals_to_spawn and _is_outside_and_drawn():
		for kind in _options.wildlife:
			var count := 1 if kind == "flock" else WILDLIFE_COUNT
			wildlife.spawn_in_view(StringName(kind), count)
		_are_animals_to_spawn = false
	if _hit_tile != StartupOptions.NO_TILE and _is_outside_and_drawn():
		var object := state.world.object_at(_hit_tile)
		if object != null:
			state.world.hit_object(object, 0)
		tiredness_view.acted(GameState.Use.HIT)
		_hit_tile = StartupOptions.NO_TILE
	if _harvest_tile != StartupOptions.NO_TILE and _is_outside_and_drawn():
		DebugHarvest.run(state, _harvest_tile)
		_harvest_tile = StartupOptions.NO_TILE
	if _options.screenshot == "":
		return
	_settled_frames = _settled_frames + 1 if _is_ready_to_shoot() else 0
	if _settled_frames <= SETTLE_FRAMES:
		return
	if _menu_page >= 0:
		# The game is paused by then, so a timer that ignores the pause does the waiting.
		open_menu.call(_menu_page as PauseMenu.Page)
		_menu_page = -1
		view.get_tree().create_timer(0.2, true).timeout.connect(save_screenshot_and_quit)
		return
	_screenshot_delay -= delta
	if _screenshot_delay <= 0.0:
		save_screenshot_and_quit.call()


## Not while the player is inside: the world is not streamed then.
func _is_outside_and_drawn() -> bool:
	return view.is_settled and not state.is_inside()


## Waits for the first house and the world around, then walks in without a fade.
func _enter_first_house() -> void:
	var houses := state.world.buildings()
	if houses.is_empty() or not view.is_settled:
		return
	_is_entering_first_house = false
	state.player.position = Vector2(houses[0].door_tile()) + Vector2(0.5, 0.5)
	pass_door.call()


## Puts the asked chests where they go once their map is drawn, and opens the storage screen of
## the last.
func _place_chests() -> void:
	if _chest_tile != StartupOptions.NO_TILE and view.is_settled and not state.is_inside():
		_opened_chest = DebugChest.create(state.world, _chest_tile)
		_chest_tile = StartupOptions.NO_TILE
	if (
		_chest_inside_tile != StartupOptions.NO_TILE
		and state.is_inside()
		and not _is_entering_first_house
	):
		_opened_chest = DebugChest.create(state.current_map, _chest_inside_tile)
		interior_view.show_interior(state.current_map)
		_chest_inside_tile = StartupOptions.NO_TILE
	if _is_storage_to_open and _opened_chest != null:
		_is_storage_to_open = false
		storage_screen.open(_opened_chest, state.player)


func _is_ready_to_shoot() -> bool:
	# The world is not streamed while the player is inside.
	return (
		(view.is_settled or state.is_inside())
		and not _is_entering_first_house
		and _harvest_tile == StartupOptions.NO_TILE
		and _chest_tile == StartupOptions.NO_TILE
		and _chest_inside_tile == StartupOptions.NO_TILE
		and not _is_storage_to_open
	)
