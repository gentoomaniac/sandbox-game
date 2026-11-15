class_name DefaultDay
extends RefCounted
## The day a villager has when the language model has planned none: the default starts of their
## activities that fit the day, each moved a few minutes by a number from their name and the day,
## so that they do not all start in the same minute. A pure function of the villager, the day, the
## world's seed and where the villager's places are: it is made again when asked for, and never
## saved. Rain and the dark are not
## in it: they act when the day is executed (see ActivityUpkeep), so a day made a week ahead is as
## good as one made now.


## The entries of `day` for a villager with these `activities`, in time order. A villager with no
## house has none (they keep to their anchor). `has_place` is a Callable that takes an activity and
## says whether the villager has a place for it (see ActivityPlaces); an activity without one is
## not offered, so it does not take the place of another. Without it every activity has one.
static func of(
	npc: Npc,
	activities: VillagerActivities,
	day: int,
	world_seed: int,
	rules: ActivityRules,
	has_place := Callable()
) -> Array[DayEntry]:
	if npc.house == null:
		return []
	var offset := offset_minutes(npc.name, day, world_seed, rules)
	var entries: Array[DayEntry] = []
	for id in activities.ids:
		var is_offered := activities.can_be_on(id, day, rules) and rules.has_default_on(id, day)
		if is_offered and (not has_place.is_valid() or has_place.call(id)):
			for start in rules.default_starts(id):
				entries.append(DayEntry.new(id, start["minute"] + offset, start["minutes"]))
	entries.sort_custom(_is_earlier)
	var kept := _without_crowding(entries, rules)
	if not kept.any(func(entry: DayEntry) -> bool: return entry.activity == ActivityRules.SLEEP):
		var start: Dictionary = rules.default_starts(ActivityRules.SLEEP)[0]
		kept.append(DayEntry.new(ActivityRules.SLEEP, start["minute"] + offset, start["minutes"]))
		kept.sort_custom(_is_earlier)
	return kept


## How many minutes later than its default time a villager starts on a day, 0 to `spread_minutes`:
## the same for the same name, day and world.
static func offset_minutes(
	villager_name: String, day: int, world_seed: int, rules: ActivityRules
) -> int:
	return posmod(hash([villager_name, day, world_seed]), int(rules.number("spread_minutes")) + 1)


## Of two entries that start less than `min_gap_minutes` apart the one with the higher priority
## stays, then the earlier; and an entry that starts while an earlier one of the same or a higher
## priority is still on (its length) is left out. `entries` are in time order.
static func _without_crowding(entries: Array[DayEntry], rules: ActivityRules) -> Array[DayEntry]:
	var min_gap := int(rules.number("min_gap_minutes"))
	var kept: Array[DayEntry] = []
	for entry in entries:
		if not kept.is_empty() and _is_on_at(kept.back(), entry.minute):
			if _priority(kept.back(), rules) >= _priority(entry, rules):
				continue
		while (
			not kept.is_empty()
			and entry.minute - kept.back().minute < min_gap
			and _priority(entry, rules) > _priority(kept.back(), rules)
		):
			kept.pop_back()
		if kept.is_empty() or entry.minute - kept.back().minute >= min_gap:
			kept.append(entry)
	return kept


static func _is_on_at(entry: DayEntry, minute: int) -> bool:
	return minute < entry.minute + entry.minutes


static func _is_earlier(first: DayEntry, second: DayEntry) -> bool:
	return first.minute < second.minute


static func _priority(entry: DayEntry, rules: ActivityRules) -> int:
	return rules.activity(entry.activity).get("priority", 0)
