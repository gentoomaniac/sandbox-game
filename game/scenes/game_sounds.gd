class_name GameSounds
extends Node
## Makes the sound of what happens in the game, by listening to it: the footsteps (on the
## walk animation's steps), the hits and breaks of tools (the world's `object_hit`), items
## collected and buildings placed (the world's signals), the hotbar slot changing, and menus
## opening and closing. Main tells it the result of each use of a tile (see `used`). Which event
## a happening makes is SoundEvents'; playing it is AudioService's. The state knows nothing of
## sound.

var _audio: AudioService
var _state: GameState
var _view: WorldView
var _selected_slot := 0
## The panels to give an open and close sound: how to ask each if it is open, and whether it was.
var _panel_checks: Array[Callable] = []
var _panel_was_open: Array[bool] = []


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
		func(tree: WorldObject) -> void: _audio.play(&"tree_fall", _centre_of(tree.pos))
	)
	state.world.ground_item_removed.connect(
		func(item: GroundItem) -> void:
			_audio.play(&"item_pickup", item.position * TerrainTileset.TILE_SIZE)
	)
	state.world.building_placed.connect(
		func(building: Building) -> void: _audio.play(&"build_place", _centre_of(building.origin))
	)
	build_mode.placement_refused.connect(func() -> void: _audio.play(&"denied"))
	state.player.inventory.changed.connect(_on_inventory_changed)


## Plays ui_open and ui_close as a panel (the menu, a screen) opens and closes. `is_open` says
## whether it is open now.
func watch_panel(is_open: Callable) -> void:
	_panel_checks.append(is_open)
	_panel_was_open.append(is_open.call())


## Plays ui_click when a button, or an inventory slot, under `root` is pressed.
func click_on_press_in(root: Node) -> void:
	for button in root.find_children("*", "BaseButton", true, false):
		button.pressed.connect(func() -> void: _audio.play(&"ui_click"))
	for slot in root.find_children("*", "SlotView", true, false):
		slot.pressed.connect(func() -> void: _audio.play(&"ui_click"))


## Plays the sound of using `tile` with the held item, which had this `result` (see
## GameState `use_tile`).
func used(result: GameState.Use, tile: Vector2i) -> void:
	var held := _state.player.inventory.held_item()
	var held_tool: StringName = ItemTypes.TYPES.get(held, {}).get("tool", &"")
	var event := SoundEvents.use(result, held_tool)
	if event != &"":
		_audio.play(event, _centre_of(tile))


func _process(_delta: float) -> void:
	for index in _panel_checks.size():
		var is_open: bool = _panel_checks[index].call()
		if is_open != _panel_was_open[index]:
			_panel_was_open[index] = is_open
			_audio.play(&"ui_open" if is_open else &"ui_close")


func _on_step() -> void:
	var player := _state.player
	var tile := _state.current_map.tile_at(player.tile())
	if tile == null:
		return
	var is_indoors := _state.is_inside()
	var is_snowed := not is_indoors and _view.is_snowed_over(player.tile())
	_audio.play(
		SoundEvents.footstep(tile.terrain, tile.frozen, is_snowed, is_indoors),
		player.position * TerrainTileset.TILE_SIZE
	)


func _on_object_hit(object: WorldObject) -> void:
	# The hit that finished the object left nothing, or something else, on its tile.
	var is_finished := _state.world.object_at(object.pos) != object
	var event := SoundEvents.hit(object.type_data(), is_finished)
	if event != &"":
		_audio.play(event, _centre_of(object.pos))


func _on_inventory_changed() -> void:
	var slot := _state.player.inventory.selected_slot
	if slot != _selected_slot:
		_selected_slot = slot
		_audio.play(&"hotbar_select")


func _centre_of(tile: Vector2i) -> Vector2:
	return (Vector2(tile) + Vector2(0.5, 0.5)) * TerrainTileset.TILE_SIZE
