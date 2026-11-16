class_name CampfireScreen
extends Modal
## The window of a campfire (task 56; see Campfire): the fire's slot for wood in the middle with
## how it is doing under it (the wood left, burning or out), a button that lights it and one that
## cooks at it (which opens the crafting menu of the fire, see `cook_requested`); the player's
## backpack on the right. The hotbar is the HUD's, lit and clickable while it is open, as in the
## chest's window. Only wood goes into the slot, by dragging or Shift+click; it comes out the same
## way. Fire burns while the window is open, so the words follow the clock. E or Escape closes it
## (Main sees to E).

## The Cook button was pressed: the window is closed, and the crafting menu of the fire is wanted.
signal cook_requested(fire: WorldObject)

const PANEL_GAP := 12
const LIGHT_TEXT := "Light the fire"
const COOK_TEXT := "Cook at the fire"
const WOOD_HINT := "Put wood in the slot."

var _state: GameState
var _fire: WorldObject
var _title_label := Label.new()
var _slot_view := SlotView.new()
var _state_label := Label.new()
var _light_button := Button.new()
var _cook_button := Button.new()
var _backpack: BackpackGrid


func _init(hotbar: HotbarHud) -> void:
	super()
	close_actions = [&"interact"]

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", PANEL_GAP)
	var fire_column := VBoxContainer.new()
	fire_column.alignment = BoxContainer.ALIGNMENT_CENTER
	for label in [_title_label, _state_label]:
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.custom_minimum_size.x = 150
	fire_column.add_child(_title_label)
	_slot_view.tooltip_id = "fire_fuel"
	_slot_view.move_rule = _move
	_slot_view.quick_move_requested.connect(_take_out)
	var slot_holder := CenterContainer.new()
	slot_holder.add_child(_slot_view)
	fire_column.add_child(slot_holder)
	fire_column.add_child(_state_label)
	for button: Button in [_light_button, _cook_button]:
		# Space is the game's use key: a focused button would take it.
		button.focus_mode = Control.FOCUS_NONE
		button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		fire_column.add_child(button)
	_light_button.text = LIGHT_TEXT
	_light_button.pressed.connect(_light)
	_cook_button.text = COOK_TEXT
	_cook_button.pressed.connect(_cook)
	row.add_child(fire_column)

	_backpack = BackpackGrid.new(hotbar)
	_backpack.dims_item = _is_not_wood
	_backpack.quick_move_requested.connect(_put_in)
	row.add_child(_backpack)
	_panel.add_child(row)


## Opens the window of a campfire. Opening it again moves it to that fire.
func open_fire(fire: WorldObject, state: GameState) -> void:
	assert(Campfire.is_campfire(fire), "Not a campfire: %s" % fire.type)
	close()
	_fire = fire
	_state = state
	open()


func _on_open() -> void:
	_title_label.text = "Campfire"
	_slot_view.bind_to(_fire.storage, Campfire.FUEL_SLOT)
	_state.player.inventory.changed.connect(_refresh)
	_fire.storage.changed.connect(_refresh)
	_backpack.bind(_state.player.inventory)
	_refresh()


## The window listens only while it is open.
func _on_close() -> void:
	_state.player.inventory.changed.disconnect(_refresh)
	_fire.storage.changed.disconnect(_refresh)
	_backpack.unbind()


## The words follow the burning, also with nothing else changing.
func _process(_delta: float) -> void:
	if visible and _fire != null:
		_refresh()


func _refresh() -> void:
	var text := WOOD_HINT if _fire.storage.is_empty() else ""
	_state_label.text = (
		Campfire.state_text(_fire) if text == "" else "%s\n%s" % [Campfire.state_text(_fire), text]
	)
	_slot_view.show_stack(_fire.storage.slots[Campfire.FUEL_SLOT], false)
	_light_button.disabled = not Campfire.can_light(_fire)
	_light_button.visible = Campfire.is_out(_fire)
	_cook_button.disabled = Campfire.is_out(_fire)
	_backpack.refresh()


func _is_wood(item: StringName) -> bool:
	return Campfire.burn_minutes_of(item) > 0


func _is_not_wood(item: StringName) -> bool:
	return not _is_wood(item)


## The move rule of the fuel slot (see SlotView `move_rule`): only wood goes in, and onto an empty
## slot or wood of the same kind; out of it onto an empty slot or the same item, never a swap.
func _move(source: SlotView, target: SlotView, is_dropping: bool) -> bool:
	var fuel := _fire.storage
	var is_going_in := target.container == fuel and source.container != fuel
	var may_move := (
		target.item() in [ItemTypes.NONE, source.item()]
		and (_is_wood(source.item()) or not is_going_in)
	)
	if may_move and is_dropping:
		source.container.move_to(source.slot, target.container, target.slot)
	return may_move


## Shift+click on a backpack or hotbar slot: wood goes into the slot.
func _put_in(slot: int) -> void:
	var inventory := _state.player.inventory
	if _is_wood(inventory.item_in(slot)):
		inventory.send(slot, _fire.storage)


## Shift+click on the fuel slot: the wood goes back to the backpack.
func _take_out() -> void:
	var inventory := _state.player.inventory
	_fire.storage.send(Campfire.FUEL_SLOT, inventory, inventory.backpack_first_order())


func _light() -> void:
	_state.light_campfire(_fire)
	_refresh()


func _cook() -> void:
	close()
	cook_requested.emit(_fire)
