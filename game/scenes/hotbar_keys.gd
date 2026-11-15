class_name HotbarKeys
extends RefCounted
## The keys and the mouse wheel that pick the held slot of the hotbar in the game scene. Picking a
## slot lets build mode act again if it was dismissed (see Builder `resume`).

var _inventory: Inventory
var _builder: Builder
## The mouse wheel's turns not yet a whole hotbar slot (see HotbarWheel).
var _wheel_progress := 0.0


func _init(inventory: Inventory, builder: Builder) -> void:
	_inventory = inventory
	_builder = builder


## Picks the slot that `event` asks for, if it does; whether it did.
func take(event: InputEvent) -> bool:
	var slot := _slot_of(event)
	if slot != -1:
		_inventory.select(slot)
	elif HotbarWheel.is_hotbar_wheel(event):
		_wheel_progress = HotbarWheel.turned(_wheel_progress, HotbarWheel.turn_of(event))
		var steps := HotbarWheel.whole_slots(_wheel_progress)  # the rest waits for more turning
		_wheel_progress -= steps
		if steps == 0:
			return true
		_inventory.select_next(steps)
	else:
		return false
	_builder.resume()
	return true


## The hotbar slot (0 to 7) whose key `event` presses, or -1.
func _slot_of(event: InputEvent) -> int:
	for slot in Inventory.HOTBAR_SIZE:
		if event.is_action_pressed("hotbar_%d" % (slot + 1)):
			return slot
	return -1
