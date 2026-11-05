class_name Builder
extends RefCounted
## What the hammer does. Holding it is build mode: `choice` is the building it would place,
## Q and E move it along BuildingTypes, and `place` builds it where the player points,
## taking the materials from the inventory. Plain logic; BuildMode draws the ghost and the
## panel. Dismissing build mode (Escape, right click) lasts until the player holds
## something else, or selects the hammer again.

var choice: StringName = BuildingTypes.ids()[0]

var _state: GameState
var _is_dismissed := false


func _init(state: GameState) -> void:
	_state = state
	_state.player.inventory.changed.connect(_on_inventory_changed)


## Whether the player is placing buildings: they hold the hammer and have not dismissed it.
func is_building() -> bool:
	return _is_hammer_held() and not _is_dismissed


func dismiss() -> void:
	_is_dismissed = true


## Holds the hammer, if there is one on the hotbar. Returns whether the player does.
func select_hammer() -> bool:
	var inventory := _state.player.inventory
	for slot in Inventory.HOTBAR_SIZE:
		if inventory.item_in(slot) == ItemTypes.HAMMER:
			_is_dismissed = false
			inventory.select(slot)
			return true
	return false


## Moves `choice` by `step` buildings along the file's order, wrapping round.
func pick(step: int) -> void:
	var ids := BuildingTypes.ids()
	choice = ids[posmod(ids.find(choice) + step, ids.size())]


## What the chosen building takes, item id to count.
func costs() -> Dictionary:
	return BuildingTypes.TYPES[choice]["costs"]


## What the player lacks for the chosen building, item id to the count short; empty when they
## have it all (or the cost cheat is on).
func shortfalls() -> Dictionary:
	var short := {}
	if _state.cheats.is_cost_off:
		return short
	for item: StringName in costs():
		var missing: int = costs()[item] - _state.player.inventory.count_of(item)
		if missing > 0:
			short[item] = missing
	return short


## Places the chosen building with its top left tile at `origin` and takes its materials.
## Returns it, or null if the land is blocked or something is missing.
func place(origin: Vector2i) -> Building:
	if (
		not shortfalls().is_empty()
		or not _state.world.placement_blockers(choice, origin).is_empty()
	):
		return null
	if not _state.cheats.is_cost_off:
		for item: StringName in costs():
			_state.player.inventory.remove(item, costs()[item])
	return _state.world.place_building(choice, origin)


func _is_hammer_held() -> bool:
	var held := _state.player.inventory.held_item()
	return held != ItemTypes.NONE and ItemTypes.TYPES[held].get("tool") == ItemTypes.HAMMER


func _on_inventory_changed() -> void:
	if not _is_hammer_held():
		_is_dismissed = false
