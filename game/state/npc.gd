class_name Npc
extends RefCounted
## One villager: who they are (name, sex, looks), where they stand, the anchor they keep near
## and what they and the player have said to each other. Npcs moves them; NpcView draws them and
## ChatScreen shows the chat.

enum Activity { IDLE, WALK }

## The chat keeps this many of its last lines, the player's and the villager's.
const HISTORY_LIMIT := 200

## Their full name, such as "Antje Boysen".
var name: String
var sex: StringName
var appearance: Appearance
## Where their feet are, in tiles of the world.
var position: Vector2
## The point they keep near (see Npcs and data/npcs.cfg).
var anchor: Vector2
## The chat, oldest line first, each `{day, minute, from_player, text}`: the game day and the
## minute of the day it was said, and whether the player said it.
var chat_history: Array[Dictionary] = []

# What they are doing is not saved: a loaded villager stands and looks about for what to do.
## The axis direction they look in (UP, DOWN, LEFT or RIGHT).
var facing := Vector2i.DOWN
var activity := Activity.IDLE
var seconds_left := 0.0
## The way they stroll, a unit vector.
var heading := Vector2.ZERO
## The tiles their body last stood on, all walkable: a step that stays on them needs no asking
## the map again (see Npcs).
var free_body_tiles := Rect2i()


func _init(npc_name: String, npc_sex: StringName, look: Appearance, feet: Vector2) -> void:
	name = npc_name
	sex = npc_sex
	appearance = look
	position = feet
	anchor = feet


## A new villager whose sex, name and look follow from `seed_value` alone: the same seed always
## gives the same villager.
static func create(seed_value: int, feet: Vector2, rules: NpcRules) -> Npc:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var npc_sex: StringName = NpcRules.SEXES[rng.randi_range(0, NpcRules.SEXES.size() - 1)]
	var npc_name := rules.pick_name(npc_sex, rng)
	return Npc.new(npc_name, npc_sex, rules.pick_look(npc_sex, rng), feet)


## The axis direction nearest to `direction`; a tie looks up or down, as the player does.
static func facing_of(direction: Vector2) -> Vector2i:
	if absf(direction.x) > absf(direction.y):
		return Vector2i.RIGHT if direction.x > 0 else Vector2i.LEFT
	return Vector2i.DOWN if direction.y > 0 else Vector2i.UP


func tile() -> Vector2i:
	return Vector2i(position.floor())


## Looks towards a point of the world, such as the player's feet.
func turn_to(point: Vector2) -> void:
	if not point.is_equal_approx(position):
		facing = facing_of(point - position)


## Adds a line to the chat; the oldest lines beyond HISTORY_LIMIT are forgotten.
func add_chat_line(day: int, minute: int, from_player: bool, text: String) -> void:
	chat_history.append({"day": day, "minute": minute, "from_player": from_player, "text": text})
	if chat_history.size() > HISTORY_LIMIT:
		chat_history.pop_front()


func to_dict() -> Dictionary:
	return {
		"name": name,
		"sex": str(sex),
		"appearance": appearance.to_dict(),
		"position": SaveCodec.float_vector_to_json(position),
		"anchor": SaveCodec.float_vector_to_json(anchor),
		"chat_history": chat_history,
	}


static func from_dict(data: Dictionary) -> Npc:
	var npc_sex := StringName(data["sex"])
	assert(NpcRules.SEXES.has(npc_sex), "Unknown sex in save: %s" % npc_sex)
	var npc := Npc.new(
		data["name"],
		npc_sex,
		Appearance.from_dict(data["appearance"]),
		SaveCodec.float_vector_from_json(data["position"])
	)
	npc.anchor = SaveCodec.float_vector_from_json(data["anchor"])
	for line: Dictionary in data["chat_history"]:
		npc.add_chat_line(int(line["day"]), int(line["minute"]), line["from_player"], line["text"])
	return npc
