class_name Campfire
extends RefCounted
## An outdoor fire (the `fireplace` object: the camp's fire and the ones the player lays), as a
## state of the object (task 56). It has one slot of `storage` for wood, and in its `state` whether
## it is lit and how much of the log that burns is left (minutes, above 0 while it is lit). Lighting
## it takes a log out of the slot; CampfireUpkeep burns the log, takes the next out of the slot when
## it is gone and puts the fire out when there is none. Only items with a burn time in
## data/lighting.cfg [campfire_fuel] go in the slot.
## The hearth of a house is no campfire: it burns for ever.

const LIT := "lit"
const LOG_LEFT := "log_left"
const FUEL_SLOT := 0


static func is_campfire(object: WorldObject) -> bool:
	return object != null and object.type == WorldObjectTypes.FIREPLACE


## Whether the object is a campfire that is not burning: no light, no cooking.
static func is_out(object: WorldObject) -> bool:
	return is_campfire(object) and not object.state.get(LIT, false)


## How long one of the item burns, or 0 for an item that does not burn.
static func burn_minutes_of(item: StringName) -> int:
	return LightingRules.default_rules().fuel_minutes(item)


## The minutes of burning the fire has left: the log that burns and the wood in the slot.
static func minutes_left(campfire: WorldObject) -> int:
	var minutes := int(campfire.state.get(LOG_LEFT, 0))
	var wood := campfire.storage.slots[FUEL_SLOT]
	if not wood.is_empty():
		minutes += wood["count"] * burn_minutes_of(wood["item"])
	return minutes


## Whether the fire is out and has wood to light.
static func can_light(campfire: WorldObject) -> bool:
	return is_out(campfire) and not campfire.storage.slots[FUEL_SLOT].is_empty()


## Lights the fire with a log of the slot. Does nothing for a fire that can't be lit.
static func ignite(campfire: WorldObject) -> void:
	if not can_light(campfire):
		return
	campfire.state[LIT] = true
	_take_next_log(campfire)


## Burns `minutes` of a lit fire, as the log burns: the next one is taken from the slot the minute
## the log is gone. Returns whether the fire went out (no log left to take).
static func burn(campfire: WorldObject, minutes: int) -> bool:
	var left := minutes
	while left > 0:
		var burnt := mini(left, int(campfire.state[LOG_LEFT]))
		campfire.state[LOG_LEFT] = int(campfire.state[LOG_LEFT]) - burnt
		left -= burnt
		if campfire.state[LOG_LEFT] == 0 and not _take_next_log(campfire):
			campfire.state[LIT] = false
			return true
	return false


## Gives the fire of a new game its wood and lights it.
static func fill_to_start(campfire: WorldObject) -> void:
	var logs := LightingRules.default_rules().start_logs()
	campfire.storage.add(ItemTypes.LOGS, logs)
	ignite(campfire)


## How the fire is doing, in words: "Campfire, burning: wood for about 7 hours".
static func state_text(campfire: WorldObject) -> String:
	var minutes := minutes_left(campfire)
	if is_out(campfire):
		if minutes == 0:
			return "Campfire, out: no wood"
		return "Campfire, out: wood for about %s" % _hours_text(minutes)
	var is_low := minutes <= LightingRules.default_rules().low_minutes()
	return (
		"Campfire, %s: wood for about %s"
		% ["burning low" if is_low else "burning", _hours_text(minutes)]
	)


## Takes the next log out of the slot into the burning one. Returns false when there is none.
static func _take_next_log(campfire: WorldObject) -> bool:
	var wood := campfire.storage.slots[FUEL_SLOT]
	if wood.is_empty():
		return false
	campfire.state[LOG_LEFT] = burn_minutes_of(wood["item"])
	campfire.storage.take_from(FUEL_SLOT, 1)
	return true


static func _hours_text(minutes: int) -> String:
	var hours := ceili(float(minutes) / GameClock.MINUTES_PER_HOUR)
	return "%d %s" % [hours, "hour" if hours == 1 else "hours"]
