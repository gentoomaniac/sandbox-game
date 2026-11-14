class_name LanternCandle
extends RefCounted
## The candle of a lantern (task 231), as the state of item stacks (see ItemSlots).
##
## A candle that has burnt is the state `{"burnt_minutes": int}` of one candle item, from 1 minute
## to just below its life (a fresh candle has no state and stacks). A lantern holding a candle has
## the state `{"candle": <the candle's state>}` (`{"candle": {}}` for a fresh one); a lantern
## without a candle has none. The life of a candle is LightingRules `candle_minutes`.

const BURNT_MINUTES := "burnt_minutes"
const CANDLE := "candle"
## The pictures of a lantern with less candle, and with none (see `icon_item`).
const USED_ICON := &"lantern_used"
const STUB_ICON := &"lantern_stub"
const EMPTY_ICON := &"lantern_empty"


## Whether the stack is a lantern with a candle in it.
static func holds_candle(stack: Dictionary) -> bool:
	return stack.get("item") == ItemTypes.LANTERN and stack.get("state", {}).has(CANDLE)


## The state of the lantern that holds a candle of this state.
static func lantern_state_with(candle_state: Dictionary) -> Dictionary:
	return {CANDLE: candle_state}


## How many minutes the candle of this state has burnt.
static func burnt_minutes(candle_state: Dictionary) -> int:
	# A loaded save brings whole numbers as floats.
	return int(candle_state.get(BURNT_MINUTES, 0))


## The state of the candle after `minutes` more of burning; empty for a fresh one.
static func burnt_for(candle_state: Dictionary, minutes: int) -> Dictionary:
	var burnt := burnt_minutes(candle_state) + minutes
	return {BURNT_MINUTES: burnt} if burnt > 0 else {}


## How much of the candle of this state is left, from 0 to 1.
static func share_left(candle_state: Dictionary) -> float:
	var life := LightingRules.default_rules().candle_minutes()
	return 1.0 - float(burnt_minutes(candle_state)) / life


## Whether a candle of this state has burnt all the way.
static func is_burnt_out(candle_state: Dictionary) -> bool:
	return burnt_minutes(candle_state) >= LightingRules.default_rules().candle_minutes()


## What is wrong with the state of a stack of `item` in a save, or "" if nothing is.
static func problem_with_state(item: StringName, state: Dictionary) -> String:
	if item == ItemTypes.CANDLE:
		return _problem_with_candle_state(state)
	if item == ItemTypes.LANTERN:
		if state.keys() != [CANDLE] or not state[CANDLE] is Dictionary:
			return "a lantern's state is its candle"
		return _problem_with_candle_state(state[CANDLE], true)
	return "%s has no state" % item


## The item whose icon shows the stack: a lantern shows how much candle it holds.
static func icon_item(stack: Dictionary) -> StringName:
	var item: StringName = stack["item"]
	if item != ItemTypes.LANTERN:
		return item
	if not holds_candle(stack):
		return EMPTY_ICON
	var share := share_left(stack["state"][CANDLE])
	if share > 2.0 / 3.0:
		return ItemTypes.LANTERN
	return USED_ICON if share > 1.0 / 3.0 else STUB_ICON


static func _problem_with_candle_state(state: Dictionary, may_be_fresh := false) -> String:
	if state.is_empty() and may_be_fresh:
		return ""
	if state.keys() != [BURNT_MINUTES] or not _is_whole(state[BURNT_MINUTES]):
		return "a candle's state is its burnt_minutes"
	var burnt := burnt_minutes(state)
	if burnt < 1 or is_burnt_out(state):
		return "burnt_minutes %d is not between 1 and the candle's life" % burnt
	return ""


static func _is_whole(value: Variant) -> bool:
	return (value is int) or (value is float and value == floorf(value))
