class_name HotbarCase
extends RefCounted
## A HUD hotbar the way Main has it when a screen borrows it: showing an inventory.


static func new_hotbar(inventory := Inventory.new()) -> HotbarHud:
	var hotbar := HotbarHud.new()
	hotbar.show_inventory(inventory)
	return hotbar
