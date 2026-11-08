class_name DebugRunner
extends RefCounted
## The debug flags that wait for the world to be drawn: Main calls `update` once per frame and
## each step runs the moment its condition holds, once. Also the screenshot: it is taken a few
## frames after every step is done, and after the `--screenshot-delay`.
##
## What a step needs from Main is set after `new()`; the flags are in StartupOptions.

## Frames to wait before a screenshot once everything is in place, for tile maps to catch up.
const SETTLE_FRAMES := 3
## Animals of each kind that `--wildlife` puts in view; of the kinds that are a group of birds,
## one group.
const WILDLIFE_COUNT := 4
const WILDLIFE_GROUPS: Array[StringName] = [
	WildlifeRules.FLOCK,
	WildlifeRules.GEESE,
	WildlifeRules.FLYING_GEESE,
	WildlifeRules.OYSTERCATCHER,
	WildlifeRules.DUNLIN,
]
## Farm animals of each species that `--livestock` puts near the player.
const LIVESTOCK_COUNT := 4
## The cats of `--hunt` stand this many tiles right of the player, one below the other, and their
## mice further right: out of the player's way, so that they take no notice of them.
const HUNTING_CATS_AT := Vector2(1.0, -1.5)
const HUNTING_CATS_APART := 1.5
const HUNTED_MOUSE_AHEAD := 2.5
## The villagers of `--npcs` are drawn from this seed, so a screenshot shows the same ones.
const NPCS_SEED := 84

var state: GameState
var view: WorldView
var wildlife: WildlifeView
var tiredness_view: TirednessView
var interior_view: InteriorView
var storage_screen: StorageScreen
var crafting_screen: CraftingScreen
var chat_screen: ChatScreen
## Main's doings, as `func()` unless noted.
var try_sleep: Callable
var pass_door: Callable
var open_menu: Callable  # func(page: PauseMenu.Page)
var open_chat: Callable  # func(npc: Npc)
var save_screenshot_and_quit: Callable

var _options: StartupOptions
# What is still to do; a step clears its own.
var _is_entering_first_house: bool
var _is_sleeping: bool
var _chest_tile: Vector2i
var _chest_inside_tile: Vector2i
var _churchyard_tile: Vector2i
var _is_storage_to_open: bool
var _is_station_to_open: bool
var _are_animals_to_spawn: bool
var _is_livestock_to_spawn: bool
var _is_hunt_to_stage: bool
var _npcs_to_spawn: int
var _villager_to_spawn: String
var _chat_lines: PackedStringArray
var _chat_script: PackedStringArray
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
	_churchyard_tile = options.churchyard
	_is_storage_to_open = options.storage
	_is_station_to_open = options.station
	_are_animals_to_spawn = not options.wildlife.is_empty()
	_is_livestock_to_spawn = not options.livestock.is_empty()
	_is_hunt_to_stage = options.hunt
	_npcs_to_spawn = options.npcs
	_villager_to_spawn = options.villager
	_chat_lines = options.chat
	_chat_script = options.chat_script
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
	if _churchyard_tile != StartupOptions.NO_TILE and view.is_settled and not state.is_inside():
		DebugChurchyard.create(state, _churchyard_tile)
		_churchyard_tile = StartupOptions.NO_TILE
	if _is_station_to_open and _is_map_drawn():
		_is_station_to_open = false
		var station := Interaction.nearest_in_reach(
			state,
			func(object: WorldObject) -> bool:
				return StationRules.default_rules().station_of(object.type) != &""
		)
		if station != null:
			crafting_screen.open(station)
	if _are_animals_to_spawn and _is_outside_and_drawn():
		for kind in _options.wildlife:
			var count := 1 if StringName(kind) in WILDLIFE_GROUPS else WILDLIFE_COUNT
			wildlife.spawn_in_view(StringName(kind), count)
		_are_animals_to_spawn = false
	if _is_livestock_to_spawn and _is_outside_and_drawn():
		_spawn_livestock()
		_is_livestock_to_spawn = false
	if _is_hunt_to_stage and _is_outside_and_drawn():
		_stage_hunt()
		_is_hunt_to_stage = false
	if _npcs_to_spawn > 0 and _is_outside_and_drawn():
		state.npcs.rng.seed = NPCS_SEED
		state.npcs.spawn(_npcs_to_spawn, state.player.position, state.world)
		_npcs_to_spawn = 0
	if _villager_to_spawn != "" and _is_outside_and_drawn():
		if not state.npcs.villagers.has(_villager_to_spawn):
			push_error("--villager expects one of %s" % [state.npcs.villagers.ids()])
		else:
			state.npcs.spawn_villager(_villager_to_spawn, state.player.position, state.world)
		_villager_to_spawn = ""
	if (not _chat_lines.is_empty() or not _chat_script.is_empty()) and _is_outside_and_drawn():
		_chat()
	if _hit_tile != StartupOptions.NO_TILE and _is_outside_and_drawn():
		var object := state.world.object_at(_hit_tile)
		if object != null:
			state.world.hit_object(object, 0)
		tiredness_view.acted(ToolUse.Use.HIT)
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


## Speaks to the nearest villager and says the `--chat` lines, each after the last is answered.
## The chat pauses the game, and so this runner: a screenshot is taken here, once it is done.
func _chat() -> void:
	var lines := _chat_lines
	_chat_lines = PackedStringArray()
	var script := _chat_script
	_chat_script = PackedStringArray()
	var villagers := state.npcs.all()
	if villagers.is_empty():
		push_error("--chat needs a villager near the player (see --npcs and --villager)")
		return
	var feet := state.player.position
	villagers.sort_custom(
		func(a: Npc, b: Npc) -> bool:
			return a.position.distance_to(feet) < b.position.distance_to(feet)
	)
	var villager := villagers[0]
	_put_script_in_chat(villager, script)
	open_chat.call(villager)
	for line in lines:
		chat_screen.say(line)
		await chat_screen.answered
	if _options.screenshot != "":
		# One frame for the last answer to be drawn.
		await chat_screen.get_tree().process_frame
		save_screenshot_and_quit.call()


## Puts the lines of `--chat-script` into the chat of a villager, as said a minute apart ending
## now; a last `...` is the villager's answer still awaited.
func _put_script_in_chat(villager: Npc, script: PackedStringArray) -> void:
	var clock := state.clock
	for index in script.size():
		var minute := clock.minute_of_day - (script.size() - 1 - index)
		if index == script.size() - 1 and script[index] == "...":
			villager.is_answering = true
		else:
			villager.add_chat_line(clock.day, minute, index % 2 == 0, script[index])


func _spawn_livestock() -> void:
	for species in _options.livestock:
		if not LivestockRules.SPECIES.has(StringName(species)):
			push_error("--livestock expects %s, got '%s'" % [LivestockRules.SPECIES, species])
			continue
		state.livestock.spawn(
			StringName(species), LIVESTOCK_COUNT, state.player.position, state.world
		)


## A cat of each look and a mouse ahead of each (see `--hunt`). A new cat picks what to do next at
## once, and then it sees its mouse.
func _stage_hunt() -> void:
	var rules := state.livestock.rules
	var looks := rules.looks(LivestockRules.CAT)
	for index in looks.size():
		var feet := state.player.position + HUNTING_CATS_AT + Vector2(0, index * HUNTING_CATS_APART)
		var mouse := feet + Vector2(HUNTED_MOUSE_AHEAD, 0)
		wildlife.place(WildlifeRules.MOUSE, mouse * WildlifeRules.TILE_SIZE)
		state.livestock.add(FarmAnimal.new(LivestockRules.CAT, StringName(looks[index]), feet))


## The map the player is on is drawn: the world is streamed, or they are inside (where it is not).
func _is_map_drawn() -> bool:
	return (view.is_settled or state.is_inside()) and not _is_entering_first_house


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
	return (
		_is_map_drawn()
		and _harvest_tile == StartupOptions.NO_TILE
		and _chest_tile == StartupOptions.NO_TILE
		and _chest_inside_tile == StartupOptions.NO_TILE
		and _churchyard_tile == StartupOptions.NO_TILE
		and not _is_storage_to_open
		and not _is_station_to_open
	)
