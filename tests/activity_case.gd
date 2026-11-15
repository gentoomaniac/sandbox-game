class_name ActivityCase
extends NpcRoadCase
## What the tests of villagers who follow their day share: a house in the yard, a villager of the
## sheets who lives in it, and a way to let game minutes pass with the villagers walking.

## A game minute is this many steps of the villagers' update.
const STEPS_PER_MINUTE := 14

var _house: Building
var _upkeep: ActivityUpkeep


func before_each() -> void:
	super()
	_upkeep = _state.activities
	_house = _world.place_building(BuildingTypes.KATE, _middle + Vector2i(-6, -6))
	assert_not_null(_house, "a house in the yard")


## The villager of the sheets with that id, standing in the yard of the house, living in it
## without the house having been given (so nothing has sent them yet).
func _resident(villager_id: String) -> Npc:
	var npc := Npc.create_villager(villager_id, _house.yard(), _npcs.villagers)
	npc.anchor = _house.yard()
	npc.house = _house
	_npcs.add(npc)
	return npc


## The road of the road tests, with the masks of all of it made, so that no walk waits for them.
func _build_warm_road() -> void:
	_build_road()
	_warm_road_masks()


func _set_time(day: int, hour: int, minute := 0) -> void:
	_state.clock.day = day
	_state.clock.minute_of_day = hour * 60 + minute


## Lets `minutes` game minutes pass one by one, with the simulation's systems and the villagers
## walking in between. Stops early, and returns true, when `is_done` says so after a minute.
func _pass_minutes(minutes: int, is_done := Callable()) -> bool:
	for _i in minutes:
		_state.simulation.advance(1)
		for _step_of_minute in STEPS_PER_MINUTE:
			_wait_for_searches()
			_npcs.update(STEP_SECONDS, _world, _state.player.position, _state.clock)
		if is_done.is_valid() and is_done.call():
			return true
	return false


func _minute_of_day() -> int:
	return _state.clock.minute_of_day


## The entry of the day with that activity, the first one.
func _entry_of(npc: Npc, day: int, activity: String) -> DayEntry:
	for entry in _upkeep.entries_of(npc, day):
		if entry.activity == activity:
			return entry
	fail_test("no %s in the day" % activity)
	return null
