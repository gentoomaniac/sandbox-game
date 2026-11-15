class_name Quests
extends RefCounted
## The quests of the villagers that are posted now (design/villagers/quests.md): a quest is posted
## at the start of a day, stays a number of days and then goes away. What each quest is, and how
## many there may be, is QuestRules (data/quests/).
##
## Which quest is posted is random but seeded by the world and the day, not by chance at the moment,
## so a reload or a long skip gives the same quests. Only one is posted a day, and the quest of the
## first day is a starter. A giver has one quest at a time, and a quest is not posted again at once
## after it was done or went away.

## A quest was posted or went away: what the player is told of it, as a line of text.
signal noticed(text: String)

## What the player is told when a quest is posted, and when one goes away: the villager's name
## and, for the second, what they asked for.
const POSTED_TEXT := "%s has something for you."
const WENT_AWAY_TEXT := "%s no longer needs the %s."

var rules: QuestRules
var _clock: GameClock
var _npcs: Npcs
## Gives the player, who is a new one in a loaded game.
var _player: Callable
var _world: World
## The posted and the taken quests, the oldest first, each `{id, giver, posted_day, is_taken}`.
var _open: Array[Dictionary] = []
## {quest id: the day it was done}.
var _done := {}
## {quest id: the day it was last done or went away}, for `repeat_after_days`.
var _ended := {}


func _init(
	quest_rules: QuestRules, clock: GameClock, npcs: Npcs, player: Callable, world: World
) -> void:
	rules = quest_rules
	_clock = clock
	_npcs = npcs
	_player = player
	_world = world
	clock.new_day.connect(_on_new_day)


## The posted and the taken quests, the oldest first. Not to be changed.
func open_entries() -> Array[Dictionary]:
	return _open


func is_open(id: String) -> bool:
	return _open.any(func(entry: Dictionary) -> bool: return entry["id"] == id)


func is_done(id: String) -> bool:
	return _done.has(id)


## The entry of the open quest `id`, or an empty dictionary.
func entry_of(id: String) -> Dictionary:
	for entry in _open:
		if entry["id"] == id:
			return entry
	return {}


## The quest the villager gives, as its entry, or an empty dictionary when they give none.
func entry_of_giver(giver: String) -> Dictionary:
	for entry in _open:
		if entry["giver"] == giver:
			return entry
	return {}


func is_log_full() -> bool:
	return _taken_count() >= rules.quest_log_size()


## The player takes the posted quest of `entry`: it is in their list now.
func take(entry: Dictionary) -> void:
	entry["is_taken"] = true


## The last day the quest stays: the days of its file count from the day it was posted.
func last_day_of(entry: Dictionary) -> int:
	return entry["posted_day"] + rules.days_of(entry["id"]) - 1


## The player, for the objectives that look at what they carry.
func player() -> PlayerState:
	return _player.call()


## How many pieces of `object` the player put down on or after `since_day` still stand within
## `radius` tiles of the home of the villager `giver` (their anchor when they have no house). The
## day a piece was put down is in its state, put there for the objects that quests ask for (see
## QuestRules `placed_objects`).
func count_placed_near_home(giver: String, object: StringName, since_day: int, radius: int) -> int:
	var npc := _npcs.find(giver)
	if npc == null:
		return 0
	var home := npc.anchor if npc.house == null else Vector2(npc.house.door_tile())
	var count := 0
	for piece in _world.edited_objects():
		var is_recent: bool = piece.state.get("placed_day", 0) >= since_day
		if piece.type == object and is_recent and Vector2(piece.pos).distance_to(home) <= radius:
			count += 1
	return count


## What a condition asks of the world: the day, the season and the opinion and skill it needs.
func day() -> int:
	return _clock.day


func season_name() -> String:
	return SeasonCondition.NAMES[_clock.season()]


## A villager's opinion of the player in points, or 0 for one who is not in the world.
func opinion_of(villager: String) -> int:
	var npc := _npcs.find(villager)
	return 0 if npc == null else npc.opinion


func skill_points(skill: String) -> float:
	return player().skills.points(StringName(skill))


## Posts the quest of the first day of a new game: a starter, with a giver picked at random.
## Returns what was posted, or "" when none fits (a world with no village).
func post_first() -> String:
	return _post_picked(_clock.day, true)


## Posts the quests of the day, up to `per_day` of them, fewer when today's are posted already, the
## quests are at their most or none fits. Returns the id of the last one posted, or "".
func post_today() -> String:
	var today := _clock.day
	var posted := ""
	var posted_today := (
		_open.filter(func(entry: Dictionary) -> bool: return entry["posted_day"] == today).size()
	)
	while posted_today < rules.per_day():
		var id := _post_picked(today, false)
		if id == "":
			break
		posted = id
		posted_today += 1
	return posted


## Posts the quest `id` now with `giver` (a villager id) whatever its prerequisites and the limits
## say; "" picks a giver who may give it. Returns what is wrong, or "" when it is posted.
func post(id: String, giver := "") -> String:
	if not rules.has(id):
		return "No quest %s" % id
	if is_open(id):
		return "%s is open already" % id
	if giver == "":
		var givers := _givers_of(id)
		if givers.is_empty():
			return "Nobody can give %s now" % id
		giver = givers[0]
	elif _npcs.find(giver) == null:
		return "No villager %s in the world" % giver
	var entry := {"id": id, "giver": giver, "posted_day": _clock.day, "is_taken": false}
	_open.append(entry)
	noticed.emit(POSTED_TEXT % _name_of(giver))
	return ""


## Marks the quest as done, as if its reward was given: it is no longer open. Returns whether it
## was open.
func finish(id: String) -> bool:
	for entry in _open:
		if entry["id"] == id:
			_open.erase(entry)
			_done[id] = _clock.day
			_ended[id] = _clock.day
			return true
	return false


## Takes every quest off the list, done or not, and forgets what was done.
func clear() -> void:
	_open.clear()
	_done.clear()
	_ended.clear()


## How many quests the player has taken, whoever gave them.
func _taken_count() -> int:
	return _open.filter(func(entry: Dictionary) -> bool: return entry["is_taken"]).size()


## Lets the quests whose days are up go away.
func _expire(today: int) -> void:
	for entry in _open.duplicate():
		if last_day_of(entry) < today:
			_open.erase(entry)
			_ended[entry["id"]] = today
			noticed.emit(WENT_AWAY_TEXT % [_name_of(entry["giver"]), rules.thing_of(entry["id"])])


func _name_of(villager: String) -> String:
	var npc := _npcs.find(villager)
	return villager if npc == null else npc.name


func _on_new_day(today: int) -> void:
	_expire(today)
	post_today()


## One quest picked at random from those that may be posted now (only starters on the first day),
## with a giver at random. The dice are seeded by the world and the day.
func _post_picked(today: int, only_starters: bool) -> String:
	if _open.size() >= rules.max_open():
		return ""
	var dice := RandomNumberGenerator.new()
	dice.seed = hash([_world.world_seed, today])
	var givers_by_quest := {}
	for id in rules.ids():
		if (only_starters and not rules.is_starter(id)) or is_open(id) or _is_resting(id, today):
			continue
		var givers := _givers_of(id).filter(func(giver: String) -> bool: return _holds(id, giver))
		if not givers.is_empty():
			givers_by_quest[id] = givers
	if givers_by_quest.is_empty():
		return ""
	var id: String = givers_by_quest.keys()[dice.randi() % givers_by_quest.size()]
	var givers: Array = givers_by_quest[id]
	post(id, givers[dice.randi() % givers.size()])
	return id


## Whether the quest was done or went away not long ago.
func _is_resting(id: String, today: int) -> bool:
	return _ended.has(id) and today - _ended[id] < rules.repeat_after_days()


## The villagers who may give the quest now: the one its file names, or any who is in the world.
## Neither one who is cold to the player nor one who has a quest open gives one.
func _givers_of(id: String) -> Array[String]:
	var named := rules.giver_of(id)
	var candidates: Array[String] = []
	if named == QuestRules.ANY_GIVER:
		for npc in _npcs.all():
			if npc.id != "":
				candidates.append(npc.id)
	else:
		candidates.append(named)
	var cold_below := GossipRules.default_rules().opinion_cold_below()
	var found: Array[String] = []
	for giver in candidates:
		var npc := _npcs.find(giver)
		var has_quest := _open.any(func(entry: Dictionary) -> bool: return entry["giver"] == giver)
		if npc != null and npc.opinion >= cold_below and not has_quest:
			found.append(giver)
	return found


## Whether every prerequisite of the quest holds with this giver.
func _holds(id: String, giver: String) -> bool:
	for entry: Dictionary in rules.quest(id).get("requires", []):
		if not rules.condition_kind(entry["type"]).is_met(entry, giver, self):
			return false
	return true
