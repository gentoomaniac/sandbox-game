class_name ShopHours
extends RefCounted
## When a shop is open (design/economy/shop.md): there is one source for the hours, the routine
## of the keeper. The shop is open while the entry of their day that is on is `keep_shop`, they
## have arrived at the stall (not still on the way) and are not asleep or in a skip, which
## another entry of the day says. What the keeper says when it is shut, and what a model is told
## of the shop, are made from the same default starts of `keep_shop` (data/activities.cfg), whose
## words are in [shop] of data/npc_talk.cfg.

## The activity of the shop hours.
const ACTIVITY := "keep_shop"
## How near their stall, in tiles, the keeper counts as being at it.
const AT_STALL_TILES := 4.0
## How many days ahead the next opening is looked for.
const LOOK_AHEAD_DAYS := 7


## Whether the keeper has the shop open now.
static func is_open(state: GameState, keeper: Npc) -> bool:
	var step := keeper.current_step
	if step == null or step.activity != ACTIVITY or not step.is_arrived:
		return false
	var entry := state.activities.entry_on(keeper)
	return entry != null and entry.activity == ACTIVITY


## Whether the keeper stands at their stall (the spot of their workplace).
static func is_at_stall(keeper: Npc) -> bool:
	if keeper.workplace == null:
		return false
	return keeper.position.distance_to(keeper.workplace.spot()) <= AT_STALL_TILES


## The next time the shop opens from `now` (a minute of `day`), by the default starts of the
## activity: {minute, days_ahead, has_opened_today}, or empty if it opens on no day soon.
static func next_opening(day: int, now: int, rules: ActivityRules) -> Dictionary:
	var has_opened_today := false
	for days_ahead in range(LOOK_AHEAD_DAYS + 1):
		if not rules.has_default_on(ACTIVITY, day + days_ahead):
			continue
		for start in rules.default_starts(ACTIVITY):
			if days_ahead == 0 and start["minute"] <= now:
				has_opened_today = true
			else:
				return {
					"minute": start["minute"],
					"days_ahead": days_ahead,
					"has_opened_today": has_opened_today,
				}
	return {}


## A time of day as people say it: "7", "1", "7:30" (an hour of twelve).
static func time_text(minute: int) -> String:
	var hour := (minute / GameClock.MINUTES_PER_HOUR) % 12
	if hour == 0:
		hour = 12
	var past := minute % GameClock.MINUTES_PER_HOUR
	return str(hour) if past == 0 else "%d:%02d" % [hour, past]


## What a keeper at their stall says when the player speaks to them while the shop is shut: that
## it is shut today, when it opens or when they are back. "" when it is open or they are not at
## the stall.
static func closed_line(state: GameState, keeper: Npc) -> String:
	if not is_at_stall(keeper) or is_open(state, keeper):
		return ""
	var talk := NpcTalkRules.default_rules()
	var rules := ActivityRules.default_rules()
	var day := state.clock.day
	if not rules.has_default_on(ACTIVITY, day):
		return talk.value("shop", "closed_day")
	var next := next_opening(day, state.clock.minute_of_day, rules)
	if next.is_empty():
		return ""
	var key := "opens"
	if next["days_ahead"] == 0 and next["has_opened_today"]:
		key = "back"
	elif next["days_ahead"] == 1:
		key = "shut_today"
	elif next["days_ahead"] > 1:
		key = "shut_until"
	var weekday := GameClock.weekday_of(day + next["days_ahead"])
	var words := {"time": time_text(next["minute"]), "weekday": GameClock.WEEKDAY_NAMES[weekday]}
	return talk.value("shop", key).format(words)


## Has a keeper at their stall say, before the player writes, why the shop is shut (see
## `closed_line`), unless that was the last thing said in their chat.
static func greet(state: GameState, keeper: Npc) -> void:
	var line := closed_line(state, keeper)
	var history := keeper.chat_history
	if line != "" and (history.is_empty() or history.back()["text"] != line):
		keeper.add_chat_line(state.clock.day, state.clock.minute_of_day, false, line)


## What a model is told of the shop of a keeper, for the prompt (see NpcMoment): `is_open`, when it
## `opens` next ("" if it does not soon), and the names of what it `sells` (with stock) and `takes`
## (with room) today. Empty for a villager who keeps no shop.
static func fact(state: GameState, keeper: Npc) -> Dictionary:
	var rules := ShopRules.default_rules()
	var shop := rules.shop_of_keeper(keeper.id)
	if shop == "":
		return {}
	var next := next_opening(
		state.clock.day, state.clock.minute_of_day, ActivityRules.default_rules()
	)
	var sells: Array[String] = []
	for item in rules.sold(shop):
		if state.shops.stock_of(shop, item) > 0:
			sells.append(ItemTypes.TYPES[item]["name"].to_lower())
	var takes: Array[String] = []
	for item in rules.taken(shop):
		if state.shops.room_of(shop, item) > 0:
			takes.append(ItemTypes.TYPES[item]["name"].to_lower())
	return {
		"is_open": is_open(state, keeper),
		"opens": "" if next.is_empty() else time_text(next["minute"]),
		"sells": sells,
		"takes": takes,
	}
