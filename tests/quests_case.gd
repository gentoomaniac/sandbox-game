class_name QuestsCase
extends GutTest
## What the tests of the quests share: a world with two villagers, and the quests of a test as
## rules.

const FIBRE := "fibre_for_beans"
const ANTJE := "antje"
const GESCHE := "gesche"

var _state: GameState
var _quests: Quests


func before_each() -> void:
	_state = GameState.new_game(7)
	_add_villagers([ANTJE, GESCHE])
	_quests = _state.quests


func _add_villagers(ids: Array[String]) -> void:
	for id in ids:
		_state.npcs.add(Npc.create_villager(id, Vector2.ZERO, _state.npcs.villagers))


## The quests as rules: each given quest is the fibre quest of the data folder with `changes`. The
## limits are those of the data folder, with `limits` over them and `quest_log_size`.
func _use_rules(changes_by_id: Dictionary, limits := {}, quest_log_size := 10) -> void:
	var real := QuestRules.default_rules()
	var quests := {}
	for id: String in changes_by_id:
		quests[id] = real.quest(FIBRE).duplicate(true)
		quests[id].merge(changes_by_id[id], true)
	var villagers := {
		"max_open": real.max_open(),
		"per_day": real.per_day(),
		"repeat_after_days": real.repeat_after_days(),
		"default_days": 8,
	}
	villagers.merge(limits, true)
	_quests.rules = QuestRules.new(
		quests, {"villagers": villagers, "log": {"quest_log_size": quest_log_size}}
	)


func _pass_days(days: int) -> void:
	for _day in days:
		_state.clock.advance(GameClock.MINUTES_PER_DAY)


func _ids_open() -> Array[String]:
	var found: Array[String] = []
	for entry in _quests.open_entries():
		found.append(entry["id"])
	return found
