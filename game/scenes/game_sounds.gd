class_name GameSounds
extends Node
## Makes the sound of what happens in the game, by listening to it: the footsteps (on the
## walk animation's steps), the hits and breaks of tools (the world's `object_hit`), the
## hotbar slot changing, the bell frame ringing, and menus opening and closing. What the player
## does is heard from the outcome of the action (GameState `action_done`: tills, picks, places,
## takes down, picks up, ...); Main tells it the uses that did not work (see `failed_use`). Which
## event a happening makes is SoundEvents'; playing it is AudioService's. The state knows nothing
## of sound.

var _audio: AudioService
var _state: GameState
var _view: WorldView
var _selected_slot := 0
## The panels to give an open and close sound: how to ask each if it is open, and whether it was.
var _panel_checks: Array[Callable] = []
var _panel_was_open: Array[bool] = []
## The open and close event of each.
var _panel_events: Array[Array] = []


## Starts listening to `state`'s world, `player_view`'s steps and `build_mode`'s refusals.
func listen(
	audio: AudioService,
	state: GameState,
	view: WorldView,
	player_view: PlayerView,
	build_mode: BuildMode
) -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_audio = audio
	_state = state
	_view = view
	_selected_slot = state.player.inventory.selected_slot
	player_view.stepped.connect(_on_step)
	state.world.object_hit.connect(_on_object_hit)
	view.tree_landed.connect(
		func(tree: WorldObject) -> void:
			_audio.play(&"tree_fall", TerrainTileset.tile_centre(tree.pos))
	)
	state.action_done.connect(_on_action_done)
	state.world.bell_rung.connect(_on_bell_rung)
	build_mode.placement_refused.connect(func() -> void: _audio.play(&"denied"))
	state.player.inventory.changed.connect(_on_inventory_changed)


## Plays ui_open and ui_close (or the events given) as a panel (the menu, a screen) opens and
## closes. `is_open` says whether it is open now.
func watch_panel(is_open: Callable, open_event := &"ui_open", close_event := &"ui_close") -> void:
	_panel_checks.append(is_open)
	_panel_was_open.append(is_open.call())
	_panel_events.append([open_event, close_event])


## Plays ui_click when a button under `root` is pressed, or a stack is dragged onto or
## Shift+clicked on an inventory slot.
func click_on_press_in(root: Node) -> void:
	for button in root.find_children("*", "BaseButton", true, false):
		button.pressed.connect(func() -> void: _audio.play(&"ui_click"))
	for slot in root.find_children("*", "SlotView", true, false):
		slot.stack_dropped_here.connect(func() -> void: _audio.play(&"ui_click"))
		slot.quick_move_requested.connect(func() -> void: _audio.play(&"ui_click"))


## Plays the sound of a use of `tile` with the held item that did not work, which had this
## `result` (see GameState `use_tile`); the ones that did are heard as outcomes.
func failed_use(result: ToolUse.Use, tile: Vector2i) -> void:
	var held := _state.player.inventory.held_item()
	var held_tool: StringName = ItemTypes.TYPES.get(held, {}).get("tool", &"")
	var event := SoundEvents.failed_use(result, held_tool)
	if event != &"":
		_audio.play(event, TerrainTileset.tile_centre(tile))


func _process(_delta: float) -> void:
	for index in _panel_checks.size():
		var is_open: bool = _panel_checks[index].call()
		if is_open != _panel_was_open[index]:
			_panel_was_open[index] = is_open
			_audio.play(_panel_events[index][0 if is_open else 1])


func _on_action_done(outcome: ActionOutcome) -> void:
	var event := SoundEvents.action(outcome.kind, outcome.object)
	if event != &"":
		_audio.play(event, TerrainTileset.tile_centre(outcome.tile))


## Every ring is a new strike on top of what still sounds, heard from where the bell hangs
## (its reach is `reach_tiles` in data/sounds.cfg).
func _on_bell_rung(building: Building) -> void:
	_audio.play(&"bell_ring", building.centre() * TerrainTileset.TILE_SIZE, true)


func _on_step() -> void:
	var player := _state.player
	var tile := _state.current_map.tile_at(player.tile())
	if tile == null:
		return
	var is_indoors := _state.is_inside()
	var is_snowed := not is_indoors and _view.is_snow_drawn_at(player.position)
	_audio.play(
		SoundEvents.footstep(tile.terrain, tile.frozen, is_snowed, is_indoors),
		player.position * TerrainTileset.TILE_SIZE
	)


func _on_object_hit(object: WorldObject) -> void:
	var event := SoundEvents.hit(object.type_data(), _state.world.is_gone(object))
	if event != &"":
		_audio.play(event, TerrainTileset.tile_centre(object.pos))


func _on_inventory_changed() -> void:
	var slot := _state.player.inventory.selected_slot
	if slot != _selected_slot:
		_selected_slot = slot
		_audio.play(&"hotbar_select")
