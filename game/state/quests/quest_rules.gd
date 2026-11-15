class_name QuestRules
extends RefCounted
## The quests of the villagers and how many there may be, read from data/quests/ (see the header
## of data/quests/_limits.cfg): one file per quest, found by scanning the folder, so a new quest is
## a new file. `from_directory` reports everything wrong, by file, and `is_valid` says whether
## anything was. What a kind of objective or prerequisite needs is its script's to say (see
## QuestKinds).

const DEFAULT_DIR := "res://data/quests"
const LIMITS_FILE := "_limits.cfg"
const QUEST_FILE_SUFFIX := ".cfg"
const QUEST_SECTION := "quest"
const ANY_GIVER := "any"
const QUEST_KEYS: Array[String] = ["notice", "dialogue", "turn_in", "objective", "reward"]
const LIMIT_KEYS := {
	"villagers": ["max_open", "per_day", "repeat_after_days", "default_days"],
	"log": ["quest_log_size"],
}
const MAX_DAYS := 60
const MAX_NOTICE_LENGTH := 100
const MAX_LINES := 6
## How many steps of opinion a reward gives at most.
const MAX_OPINION_STEPS := 3
## The prerequisites a starter, the quest of the first day, may have: it must fit the start.
const STARTER_CONDITIONS: Array[String] = ["day", "season"]
## What the lines may name in braces, as the game fills it in.
const NOTICE_WORDS: Array[String] = ["giver"]
const SHORT_WORDS: Array[String] = ["have", "count"]

static var _default: QuestRules
static var _objective_kinds := {}
static var _condition_kinds := {}
static var _kind_problems: Array[String] = []

## {quest id: {key: value}}, as in the files, in the order of the names of the files.
var _quests: Dictionary
## {section: {key: value}} of _limits.cfg.
var _limits: Dictionary
## What was wrong with the files themselves (see `from_directory`).
var _file_problems: Array[String]


func _init(quests: Dictionary, limits: Dictionary, file_problems: Array[String] = []) -> void:
	_quests = quests
	_limits = limits
	_file_problems = file_problems
	if _objective_kinds.is_empty():
		_objective_kinds = QuestKinds.in_folder(
			QuestKinds.OBJECTIVES_DIR, QuestObjective, _kind_problems
		)
		_condition_kinds = QuestKinds.in_folder(
			QuestKinds.CONDITIONS_DIR, QuestCondition, _kind_problems
		)


## The rules of the data folder, loaded the first time they are asked for.
static func default_rules() -> QuestRules:
	if _default == null:
		_default = from_directory(DEFAULT_DIR)
	return _default


static func from_directory(directory: String) -> QuestRules:
	var quests := {}
	var file_problems: Array[String] = []
	var files := Array(DirAccess.get_files_at(directory))
	files.sort()
	for file: String in files:
		if not file.ends_with(QUEST_FILE_SUFFIX) or file == LIMITS_FILE:
			continue
		var sections := DataFile.read_sections(directory.path_join(file))
		if sections.keys() != [QUEST_SECTION]:
			file_problems.append("%s: has not just a [%s] section" % [file, QUEST_SECTION])
			continue
		quests[file.trim_suffix(QUEST_FILE_SUFFIX)] = sections[QUEST_SECTION]
	var limits := DataFile.read_sections(directory.path_join(LIMITS_FILE))
	var rules := QuestRules.new(quests, limits, file_problems)
	for problem in rules.problems():
		push_error("%s: %s" % [directory, problem])
	return rules


## What is wrong, as "file: what" (the file of a quest is its id and `.cfg`).
func problems() -> Array[String]:
	var found: Array[String] = _kind_problems.duplicate()
	found.append_array(_file_problems)
	for section: String in LIMIT_KEYS:
		for key: String in LIMIT_KEYS[section]:
			var value: Variant = _limits.get(section, {}).get(key)
			if not (value is int and value >= 1):
				found.append(
					"%s: [%s] %s is not a whole number from 1" % [LIMITS_FILE, section, key]
				)
	for id in ids():
		for problem in _quest_problems(id):
			found.append("%s%s: %s" % [id, QUEST_FILE_SUFFIX, problem])
	return found


func is_valid() -> bool:
	return problems().is_empty()


## The ids of the quests, in the order of the names of their files.
func ids() -> Array[String]:
	var found: Array[String] = []
	found.assign(_quests.keys())
	return found


func has(id: String) -> bool:
	return _quests.has(id)


## The `[quest]` section of the file of `id`, as it is written.
func quest(id: String) -> Dictionary:
	return _quests[id]


## The villager who gives it, or `ANY_GIVER`.
func giver_of(id: String) -> String:
	return _quests[id].get("giver", ANY_GIVER)


## How many days it stays from the day it is posted.
func days_of(id: String) -> int:
	return _quests[id].get("days", _limits["villagers"]["default_days"])


## Whether it may be the quest of the first day.
func is_starter(id: String) -> bool:
	return _quests[id].get("starter", false)


## The most quests of the villagers there are at once, posted and taken together.
func max_open() -> int:
	return _limits["villagers"]["max_open"]


## The most that are posted in one day.
func per_day() -> int:
	return _limits["villagers"]["per_day"]


## How many days after one is done or has gone before it may be posted again.
func repeat_after_days() -> int:
	return _limits["villagers"]["repeat_after_days"]


## The most quests the player has taken, from all sources together.
func quest_log_size() -> int:
	return _limits["log"]["quest_log_size"]


func _quest_problems(id: String) -> Array[String]:
	var values: Dictionary = _quests[id]
	var found: Array[String] = []
	for key in QUEST_KEYS:
		if not values.has(key):
			found.append("no %s" % key)
	if found.is_empty():
		found.append_array(_giver_and_time_problems(values))
		found.append_array(_line_problems(values))
		found.append_array(_objective_problems(values))
		found.append_array(_condition_problems(values))
		found.append_array(_reward_problems(values))
	return found


func _giver_and_time_problems(values: Dictionary) -> Array[String]:
	var found: Array[String] = []
	var giver: Variant = values.get("giver", ANY_GIVER)
	if not (giver is String and (giver == ANY_GIVER or VillagerRules.default_rules().has(giver))):
		found.append("giver is neither a villager nor %s" % ANY_GIVER)
	var days: Variant = values.get("days", 1)
	if not (days is int and days >= 1 and days <= MAX_DAYS):
		found.append("days is not a whole number from 1 to %d" % MAX_DAYS)
	if not values.get("starter", false) is bool:
		found.append("starter is not true or false")
	return found


func _line_problems(values: Dictionary) -> Array[String]:
	var found: Array[String] = []
	var notice: Variant = values["notice"]
	if not (notice is String and not notice.is_empty() and notice.length() <= MAX_NOTICE_LENGTH):
		found.append("notice is not a text of 1 to %d characters" % MAX_NOTICE_LENGTH)
	else:
		found.append_array(_brace_problems("notice", notice, NOTICE_WORDS))
	for key in ["dialogue", "turn_in"]:
		var lines: Variant = values[key]
		if not (lines is Array and not lines.is_empty() and lines.size() <= MAX_LINES):
			found.append("%s is not a list of 1 to %d lines" % [key, MAX_LINES])
		elif not lines.all(func(line: Variant) -> bool: return line is String and line != ""):
			found.append("%s has a line that is not a text" % key)
		else:
			for line: String in lines:
				found.append_array(_brace_problems(key, line, []))
	if values.has("short"):
		if values["short"] is String:
			found.append_array(_brace_problems("short", values["short"], SHORT_WORDS))
		else:
			found.append("short is not a text")
	return found


## The words in braces of `text` that are not in `allowed`.
func _brace_problems(key: String, text: String, allowed: Array[String]) -> Array[String]:
	var found: Array[String] = []
	var braces := RegEx.create_from_string("\\{([^}]*)\\}")
	for brace in braces.search_all(text):
		var word := brace.get_string(1)
		if not allowed.has(word):
			found.append("%s names {%s}, which the game does not fill in" % [key, word])
	return found


func _objective_problems(values: Dictionary) -> Array[String]:
	var objective: Variant = values["objective"]
	if not objective is Dictionary:
		return ["objective is not a dictionary"]
	var kind: QuestObjective = _objective_kinds.get(objective.get("type"))
	if kind == null:
		return ["objective type is none of %s" % [_objective_kinds.keys()]]
	var found: Array[String] = []
	for problem in kind.problems(objective):
		found.append("objective %s: %s" % [kind.kind(), problem])
	return found


func _condition_problems(values: Dictionary) -> Array[String]:
	var requires: Variant = values.get("requires", [])
	if not requires is Array:
		return ["requires is not a list"]
	var found: Array[String] = []
	for entry: Variant in requires:
		var kind: QuestCondition = null
		if entry is Dictionary:
			kind = _condition_kinds.get(entry.get("type"))
		if kind == null:
			found.append(
				"requires has an entry whose type is none of %s" % [_condition_kinds.keys()]
			)
			continue
		for problem in kind.problems(entry, ids()):
			found.append("requires %s: %s" % [kind.kind(), problem])
		if values.get("starter", false) and not STARTER_CONDITIONS.has(kind.kind()):
			found.append(
				"a starter may only require %s, not %s" % [STARTER_CONDITIONS, kind.kind()]
			)
	return found


func _reward_problems(values: Dictionary) -> Array[String]:
	var reward: Variant = values["reward"]
	if not reward is Dictionary:
		return ["reward is not a dictionary"]
	var found: Array[String] = []
	var items: Variant = reward.get("items", {})
	if not items is Dictionary:
		return ["reward items is not a dictionary of item to count"]
	for item: Variant in items:
		var is_item := ItemTypes.TYPES.has(StringName(str(item)))
		if not (is_item and items[item] is int and items[item] >= 1):
			found.append("reward item %s is no item or its count no whole number from 1" % item)
	var steps: Variant = reward.get("opinion_steps", 0)
	if not (steps is int and steps >= 0 and steps <= MAX_OPINION_STEPS):
		found.append("reward opinion_steps is not a whole number up to %d" % MAX_OPINION_STEPS)
	elif items.is_empty() and steps == 0:
		found.append("reward has nothing in it")
	return found
