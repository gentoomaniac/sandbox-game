class_name HotbarWindow
extends Modal
## A window that moves items and borrows the HUD's hotbar as its quick bar while it is open (see
## HotbarHud `acquire`): shift+click on a hotbar slot sends its stack to the backpack, right click
## wears it. The hotbar slots take part in drags as the window's own slots do.

var _player: PlayerState
var _hotbar: HotbarHud
var _is_using_hotbar := false


func _init(hotbar: HotbarHud) -> void:
	super()
	_hotbar = hotbar
	_keeps_clicks_at = hotbar.covers


## Makes the HUD's hotbar this window's quick bar, or gives it back: the window listens to its
## clicks only while it is the one using it.
func _use_hotbar(is_used: bool) -> void:
	# The hotbar may have been freed first, when the whole scene goes.
	if is_used == _is_using_hotbar or not is_instance_valid(_hotbar):
		return
	_is_using_hotbar = is_used
	if is_used:
		_hotbar.acquire(self)
		_hotbar.slot_quick_move_requested.connect(_on_hotbar_slot_quick_move_requested)
		_hotbar.slot_secondary_pressed.connect(_on_hotbar_slot_secondary_pressed)
	else:
		_hotbar.release(self)
		_hotbar.slot_quick_move_requested.disconnect(_on_hotbar_slot_quick_move_requested)
		_hotbar.slot_secondary_pressed.disconnect(_on_hotbar_slot_secondary_pressed)


## Windows open together both hear the hotbar; only the one that took it last answers.
func _on_hotbar_slot_quick_move_requested(slot: int) -> void:
	if _hotbar.is_borrowed_by(self):
		_on_inventory_slot_quick_move_requested(slot)


func _on_hotbar_slot_secondary_pressed(slot: int) -> void:
	if _hotbar.is_borrowed_by(self):
		_on_inventory_slot_secondary_pressed(slot)


func _on_inventory_slot_quick_move_requested(slot: int) -> void:
	_player.inventory.move_to_other_part(slot)


func _on_inventory_slot_secondary_pressed(slot: int) -> void:
	_player.equipment.quick_equip(_player.inventory, slot)
