class_name GossipSpread
extends SimulationSystem
## How stories travel (design/villagers/gossip.md, How stories spread): villagers who stand close
## meet, and each may pass the other one story it lacks. It looks at every villager of the world,
## in view or not, each time the clock moves on, and a pair that has met waits before it meets
## again. The numbers are SpreadRules (data/gossip.cfg).
##
## A story is passed on only once the teller has known it for a while, and only while it is fresh
## and has not come far. The hearer takes it as heard: told by the teller, one hop further, and
## light, for it does not touch them. With a small chance one thing of the deed shifts on the way
## (a whisper): the count grows, the place moves to a neighbour's house, or the kind turns into a
## similar one.

## Not seeded in play. Tests seed it to fix who tells what.
var rng := RandomNumberGenerator.new()
var rules := SpreadRules.default_rules()
var _npcs: Npcs
var _deeds: DeedLog
## When each pair last met, in game minutes (GameClock `total_minutes`), by `_pair_key`. Not
## saved: a loaded game lets pairs meet at once, and they only pass what the other still lacks.
var _last_met := {}


## `deeds` brings how many stories and memories a villager keeps.
func _init(npcs: Npcs, deeds: DeedLog) -> void:
	_npcs = npcs
	_deeds = deeds
	rng.randomize()


func advance(_minutes: int, clock: GameClock) -> void:
	var now := clock.total_minutes()
	for pair: Variant in _last_met.keys():
		if now - _last_met[pair] >= rules.pair_wait_minutes():
			_last_met.erase(pair)
	var villagers := _npcs.all()
	for first in villagers.size():
		for second in range(first + 1, villagers.size()):
			_meet(villagers[first], villagers[second], villagers, now)


## The two meet if they stand close and have not met lately: each may tell the other a story.
func _meet(one: Npc, other: Npc, villagers: Array[Npc], now: int) -> void:
	var is_close := one.position.distance_to(other.position) <= rules.meeting_radius()
	if not is_close:
		return
	var pair := _pair_key(one, other)
	if _last_met.has(pair):
		return
	_last_met[pair] = now
	_tell(one, other, villagers, now)
	_tell(other, one, villagers, now)


## The teller passes on the weightiest, newest story that the hearer lacks and that is ready to
## be told, if the dice allow it given how they are tied.
func _tell(teller: Npc, hearer: Npc, villagers: Array[Npc], now: int) -> void:
	var story := _story_to_tell(teller, hearer, now)
	if story.is_empty():
		return
	var neighbours := _neighbours(teller, villagers)
	if rng.randf() >= rules.tell_chance(_tie(teller, hearer, neighbours)):
		return
	var heard := story.duplicate(true)
	var as_heard := {
		"how": GossipRules.HEARD,
		"told_by": teller.name,
		"hops": story["hops"] + 1,
		"learned_at": now,
		"line": "",
		"weight": MemoryWeight.LOW,
		"personal": false,
	}
	heard.merge(as_heard, true)
	_whisper(heard, neighbours)
	hearer.learn_story(heard, _deeds.stories_kept, _deeds.memories_kept)


## The story of the teller that the hearer lacks, is old enough to tell and has not gone too far or
## too long: the weightiest, among those the newest. Empty if there is none.
func _story_to_tell(teller: Npc, hearer: Npc, now: int) -> Dictionary:
	var known := hearer.stories.map(func(story: Dictionary) -> String: return story["origin"])
	var today := now / GameClock.MINUTES_PER_DAY + 1
	var best := {}
	for story in teller.stories:
		var is_tellable: bool = (
			story["hops"] < rules.max_hops()
			and today - story["day"] < rules.max_story_days()
			and now - story["learned_at"] >= rules.story_wait_minutes()
			and not known.has(story["origin"])
		)
		if is_tellable and (best.is_empty() or _is_better(story, best)):
			best = story
	return best


## Whether a story weighs more than another, or as much and is newer.
static func _is_better(story: Dictionary, other: Dictionary) -> bool:
	if story["weight"] != other["weight"]:
		return story["weight"] > other["weight"]
	return (
		story["day"] * GameClock.MINUTES_PER_DAY + story["minute"]
		> other["day"] * GameClock.MINUTES_PER_DAY + other["minute"]
	)


## With the chance of a whisper, shifts one thing of the deed of `story` (as the hearer is about
## to have it): the count, the place (to the house of one of the teller's `neighbours`) or the kind.
func _whisper(story: Dictionary, neighbours: Array[Npc]) -> void:
	if rng.randf() >= rules.whisper_chance():
		return
	var places: Array[String] = []
	for neighbour in neighbours:
		var place := _deeds.rules.house_place(neighbour.name.get_slice(" ", 0))
		if place != story["place"]:
			places.append(place)
	var shifts: Array[StringName] = [&"kind"]
	if rules.next_count(story["count"]) != story["count"]:
		shifts.append(&"count")
	if not places.is_empty():
		shifts.append(&"place")
	match shifts[rng.randi_range(0, shifts.size() - 1)]:
		&"count":
			story["count"] = rules.next_count(story["count"])
		&"place":
			story["place"] = places[rng.randi_range(0, places.size() - 1)]
		&"kind":
			story["kind"] = rules.similar_kind(story["kind"])


## How the teller is tied to the hearer: family or friends on the sheet of either, one of the
## teller's `neighbours`, or anyone.
func _tie(teller: Npc, hearer: Npc, neighbours: Array[Npc]) -> StringName:
	if (
		(hearer.id != "" and teller.people.has(hearer.id))
		or (teller.id != "" and hearer.people.has(teller.id))
	):
		return SpreadRules.FAMILY
	return SpreadRules.NEIGHBOUR if neighbours.has(hearer) else SpreadRules.ANYONE


## The villagers whose anchors are nearest to the teller's, the nearest first.
func _neighbours(teller: Npc, villagers: Array[Npc]) -> Array[Npc]:
	var others := villagers.filter(func(npc: Npc) -> bool: return npc != teller)
	others.sort_custom(
		func(first: Npc, second: Npc) -> bool:
			return (
				teller.anchor.distance_squared_to(first.anchor)
				< teller.anchor.distance_squared_to(second.anchor)
			)
	)
	var nearest: Array[Npc] = []
	nearest.assign(others.slice(0, rules.neighbour_count()))
	return nearest


## The same for the two in either order.
static func _pair_key(one: Npc, other: Npc) -> String:
	var ids := [one.get_instance_id(), other.get_instance_id()]
	ids.sort()
	return "%d_%d" % ids
