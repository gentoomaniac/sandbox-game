extends GutTest
## Every slot of the character screen answers a click, wherever on the slot it lands, the
## hotbar slots of the HUD among them.

var _player: PlayerState
var _screen: CharacterScreen
var _hotbar: HotbarHud
var _window: SubViewport


func before_each() -> void:
	_player = PlayerState.new()
	# A viewport of the game's size of its own, so the clicks need no window.
	_window = SubViewport.new()
	_window.size = Vector2i(640, 360)
	add_child_autofree(_window)
	_hotbar = HotbarHud.new()
	_window.add_child(_hotbar)
	_hotbar.show_inventory(_player.inventory)
	_window.add_child(FadeScreen.new())
	_screen = CharacterScreen.new(_hotbar)
	_window.add_child(_screen)
	_screen.show_player(_player)
	_screen.open()
	await wait_process_frames(2)


func _click(position: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = position
	_window.push_input(motion)
	for is_pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = is_pressed
		event.position = position
		_window.push_input(event)


func _click_slot(slot: int) -> void:
	_click(_screen._inventory_views[slot].get_global_rect().get_center())


## The spots of a slot to click: the centre and just inside each corner.
func _spots(view: SlotView) -> Array[Vector2]:
	var rect := view.get_global_rect()
	var spots: Array[Vector2] = [rect.get_center()]
	var corners := [rect.position, rect.end]
	corners.append(Vector2(rect.end.x, rect.position.y))
	corners.append(Vector2(rect.position.x, rect.end.y))
	for corner: Vector2 in corners:
		spots.append(corner.move_toward(rect.get_center(), 1.0))
	return spots


func test_every_slot_can_be_picked_up_wherever_it_is_clicked() -> void:
	for slot in Inventory.SLOT_COUNT:
		_player.inventory.slots[slot] = {"item": ItemTypes.TURNIP_SEEDS, "count": 1}
	_player.inventory.changed.emit()
	for slot in Inventory.SLOT_COUNT:
		var view: SlotView = _screen._inventory_views[slot]
		for spot in _spots(view):
			_click(spot)
			assert_almost_eq(
				view.modulate.a, CharacterScreen.PICKED_ALPHA, 0.01, "slot %d at %s" % [slot, spot]
			)
			_click(spot)


func test_the_hud_hotbar_is_clickable_only_while_the_character_page_is_open() -> void:
	var slot := _hotbar.slot_view(0)
	assert_true(slot.is_clickable)
	_screen.close()
	assert_false(slot.is_clickable)
	_screen.open(CharacterScreen.Tab.SKILLS)
	assert_false(slot.is_clickable, "the skills page moves no items")


func test_the_hotbar_is_drawn_above_the_dimmed_backdrop_of_the_screen() -> void:
	assert_gt(_hotbar.layer, _screen.layer)


func test_an_item_goes_from_the_backpack_onto_the_hotbar_by_clicks() -> void:
	_player.inventory.slots[Inventory.HOTBAR_SIZE + 3] = {"item": ItemTypes.LOGS, "count": 4}
	_player.inventory.slots[2] = {}
	_player.inventory.changed.emit()
	_click_slot(Inventory.HOTBAR_SIZE + 3)
	_click_slot(2)
	assert_eq(_player.inventory.slots[2], {"item": ItemTypes.LOGS, "count": 4})
