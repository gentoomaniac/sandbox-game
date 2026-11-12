class_name ProcessStationCase
extends ResourceCase
## What the tests of the process stations' shared code and window share: a smelter of 2x2 slots
## defined only in test config, which the workbench object is here, its recipes (bricks of stone
## and a log, flour of clay and a log for a mason of 30), and the player in reach with stone, logs,
## clay and berries.

const STATIONS := {
	"smelter":
	{
		"name": "Smelter",
		"objects": ["workbench"],
		"process": true,
		"grid": Vector2i(2, 2),
		"button_icon": "fire",
	},
}
## Bricks of stone and a log, two from a load, half again at masonry 50; flour of clay and a log,
## for a mason of 30.
const RECIPES := {
	"bricks":
	{
		"result": "brick",
		"count": 2,
		"materials": {"stone": 2, "logs": 1},
		"station": "smelter",
		"skill": "masonry",
		"hours": 3,
		"bonus": [[50, 0.5]],
	},
	"flour":
	{
		"result": "flour",
		"count": 1,
		"materials": {"clay": 1, "logs": 1},
		"station": "smelter",
		"skill": "masonry",
		"level": 30,
		"hours": 1,
	},
}
const RUN_MINUTES := 3 * GameClock.MINUTES_PER_HOUR

var _smelter: WorldObject
var _station: ProcessStation


func before_each() -> void:
	super.before_each()
	var stations := StationRules.new(STATIONS)
	var recipes := RecipeRules.new(RECIPES, stations)
	_smelter = _place(WorldObjectTypes.WORKBENCH)
	# The game's stations.cfg gives a workbench no grid; this smelter is in test config only.
	_smelter.storage = ItemSlots.new(stations.slot_count(&"smelter"))
	_station = ProcessStation.new(_state, Crafting.new(_state, recipes), _smelter, stations)
	var inventory := _state.player.inventory
	inventory.add(ItemTypes.STONE, 20)
	inventory.add(ItemTypes.LOGS, 10)
	inventory.add(ItemTypes.CLAY, 5)
	inventory.add(ItemTypes.BERRIES, 5)


func _grid() -> Dictionary:
	return _smelter.storage.totals()


func _slot_of(item: StringName) -> int:
	var inventory := _state.player.inventory
	for slot in inventory.slots.size():
		if inventory.item_in(slot) == item:
			return slot
	return -1


func _put_in(item: StringName) -> int:
	return _station.put_in(_state.player.inventory, _slot_of(item))
