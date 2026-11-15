class_name DayPlannerCase
extends ActivityCase
## What the tests of the planner of the villagers' days share: a house in the yard, a planner with
## a language model that is a fake (FakeChat), and helpers to put villagers at a distance and to
## see who was asked.

const SETTINGS_PATH := "user://test_day_planner/settings.cfg"
const EVENING_ANSWER := (
	'{"day": [{"activity": "breakfast", "at": "06:00", "why": "a late start"},'
	+ ' {"activity": "dinner", "at": "12:00"}, {"activity": "rest", "at": "19:00"},'
	+ ' {"activity": "sleep", "at": "21:00"}]}'
)
const REST_OF_DAY_ANSWER := '{"day": [{"activity": "rest", "at": "13:30", "why": "feet up"}]}'

var _settings: GameSettings
var _chat: FakeChat
var _dialogue: NpcDialogue
var _planner: DayPlanner


func before_each() -> void:
	super()
	_settings = GameSettings.new(SETTINGS_PATH)
	_settings.profiles.active["endpoint"] = "http://fake/v1"
	_chat = FakeChat.new()
	_chat.answers = [EVENING_ANSWER]
	_dialogue = NpcDialogue.new(_settings, _chat)
	add_child_autoqfree(_dialogue)
	_planner = DayPlanner.new(_dialogue, _state)
	add_child_autoqfree(_planner)
	_state.player.position = _house.yard()


## The planner with `value` for `key` of [plan] in place of the data file's.
func _with_plan_value(key: String, value: Variant) -> void:
	var values := DataFile.read_sections(NpcTalkRules.DEFAULT_PATH)
	values["plan"][key] = value
	_planner.rules = NpcTalkRules.new(values)


## The villager of the sheets with that id, `tiles` east of the player.
func _resident_at(villager_id: String, tiles: float) -> Npc:
	var npc := _resident(villager_id)
	npc.position += Vector2(tiles, 0.0)
	return npc


## The names of the villagers the model was asked about, in order.
func _asked_names() -> Array[String]:
	var names: Array[String] = []
	for request in _chat.requests:
		var user_text: String = request["messages"][1]["content"]
		for npc in _npcs.all():
			if user_text.contains("sheet:\n" + npc.name):
				names.append(npc.name)
				break
	return names


func _plan_evening() -> void:
	_set_time(DAY, 18)
	_planner.queue_evening()
	await _planner.ask_queue()
