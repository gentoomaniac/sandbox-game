class_name SpreadRules
extends RefCounted
## The numbers of how stories spread between villagers, read from data/gossip.cfg (see there for
## what each key means): when two villagers meet, what a teller may pass on and how likely they
## are to by how they are tied.

## How a teller is tied to the one they meet.
const FAMILY := &"family"
const NEIGHBOUR := &"neighbour"
const ANYONE := &"anyone"
const TIES: Array[StringName] = [FAMILY, NEIGHBOUR, ANYONE]

const REQUIRED_KEYS := {
	"meetings":
	[
		"radius_tiles",
		"pair_wait_minutes",
		"story_wait_minutes",
		"max_hops",
		"max_story_days",
		"neighbours",
		"chance_family",
		"chance_neighbour",
		"chance_anyone",
	],
	"whispers": ["chance", "count_steps"],
}

static var _default: SpreadRules

## {section: {key: value}}, as in the file.
var _values: Dictionary


func _init(values: Dictionary) -> void:
	_values = values


## The rules of the data file, loaded the first time they are asked for.
static func default_rules() -> SpreadRules:
	if _default == null:
		_default = from_file(GossipRules.DEFAULT_PATH)
	return _default


static func from_file(path: String) -> SpreadRules:
	var rules := SpreadRules.new(DataFile.read_sections(path))
	for problem in rules.problems():
		push_error("%s: %s" % [path, problem])
	return rules


## What is missing or wrong, as "[section] what". The values are only checked once every key is
## there.
func problems() -> Array[String]:
	var bad: Array[String] = []
	for section: String in REQUIRED_KEYS:
		for key: String in REQUIRED_KEYS[section]:
			if not _values.get(section, {}).has(key):
				bad.append("[%s] no %s" % [section, key])
	for kind in GossipRules.KINDS:
		if not _values.get("whisper_kinds", {}).has(str(kind)):
			bad.append("[whisper_kinds] no %s" % kind)
	if not bad.is_empty():
		return bad
	for key in ["radius_tiles", "pair_wait_minutes", "story_wait_minutes", "max_story_days"]:
		if float(_values["meetings"][key]) <= 0.0:
			bad.append("[meetings] %s must be above 0" % key)
	if max_hops() < 1:
		bad.append("[meetings] max_hops must be at least 1")
	for tie in TIES:
		var chance := tell_chance(tie)
		if chance < 0.0 or chance > 1.0:
			bad.append("[meetings] chance_%s must be from 0 to 1" % tie)
	if whisper_chance() < 0.0 or whisper_chance() > 1.0:
		bad.append("[whispers] chance must be from 0 to 1")
	var steps: Array = _values["whispers"]["count_steps"]
	var sorted_steps := steps.duplicate()
	sorted_steps.sort()
	if steps != sorted_steps:
		bad.append("[whispers] count_steps must rise")
	for kind in GossipRules.KINDS:
		var similar := similar_kind(kind)
		if similar == kind or not GossipRules.KINDS.has(similar):
			bad.append("[whisper_kinds] %s must turn into another kind of deed" % kind)
	return bad


func is_valid() -> bool:
	return problems().is_empty()


## How close, in tiles, two villagers must stand to meet.
func meeting_radius() -> float:
	return float(_values["meetings"]["radius_tiles"])


## How many game minutes must pass before the same two villagers meet again.
func pair_wait_minutes() -> int:
	return int(_values["meetings"]["pair_wait_minutes"])


## How many game minutes a villager must have known a story before they pass it on.
func story_wait_minutes() -> int:
	return int(_values["meetings"]["story_wait_minutes"])


## A story is passed on by those who are fewer hops than this from the one who saw it.
func max_hops() -> int:
	return int(_values["meetings"]["max_hops"])


## A story is passed on while its deed is fewer days old than this.
func max_story_days() -> int:
	return int(_values["meetings"]["max_story_days"])


## How many villagers, the nearest by anchor, are a villager's neighbours.
func neighbour_count() -> int:
	return int(_values["meetings"]["neighbours"])


## How likely a teller passes a story on to someone they are tied to like this (one of TIES).
func tell_chance(tie: StringName) -> float:
	return float(_values["meetings"]["chance_" + str(tie)])


## How likely a story changes on its way, at each hop.
func whisper_chance() -> float:
	return float(_values["whispers"]["chance"])


## The count a story grows to: the first step above `count`, or `count` if it is past them all.
func next_count(count: int) -> int:
	for step: int in _values["whispers"]["count_steps"]:
		if step > count:
			return step
	return count


## The kind of deed that a story of `kind` is told as when it turns into a similar one.
func similar_kind(kind: StringName) -> StringName:
	return StringName(_values["whisper_kinds"][str(kind)])
