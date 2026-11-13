class_name StoryJudge
extends RefCounted
## What a villager makes of a story they have come to know (design/villagers/gossip.md, The
## judge): a verdict `{line, change, personal}` that is settled on the story and moves the opinion
## of the player. The queue is the stories not judged yet (`is_judged` false, saved with them), the
## oldest learned first; who asks the language model for the verdicts, one at a time, is
## StoryJudging, and a verdict that does not come is `fixed_verdict`: the template line, the
## deed's fixed change and not personal.

var rules := GossipRules.default_rules()
var _npcs: Npcs
var _clock: GameClock


func _init(npcs: Npcs, clock: GameClock) -> void:
	_npcs = npcs
	_clock = clock


## The story that waits longest to be judged, as `{npc, story}`; empty if the queue is.
func next_in_queue() -> Dictionary:
	var next := {}
	for npc in _npcs.all():
		for story in npc.stories:
			var is_older: bool = (
				next.is_empty() or story["learned_at"] < next["story"]["learned_at"]
			)
			if not story["is_judged"] and is_older:
				next = {"npc": npc, "story": story}
	return next


## The verdict when there is no model's: no line (the template is told), the fixed change of the
## deed and not personal.
func fixed_verdict(story: Dictionary) -> Dictionary:
	return {"line": "", "change": rules.opinion_change(story["kind"]), "personal": false}


## The verdict in a model's `reply`, which is JSON (maybe with words around it, or in a code
## fence): `{line, change, personal}`, or empty if it is none that the game can take: not JSON, a
## key missing or of another kind, no line, or a change that is not a whole number from -2 to 2.
## The line is cut to `sentences` sentences.
static func parse_verdict(reply: String, npc: Npc, sentences: int) -> Dictionary:
	var start := reply.find("{")
	var end := reply.rfind("}")
	if start < 0 or end < start:
		return {}
	# Not JSON.parse_string: a reply that is not JSON is the model's fault, not an engine error.
	var json := JSON.new()
	if json.parse(reply.substr(start, end - start + 1)) != OK or not json.data is Dictionary:
		return {}
	var answer: Dictionary = json.data
	var change: Variant = answer.get("change")
	var is_change: bool = (
		(change is float or change is int)
		and change == roundf(change)
		and absf(change) <= GossipRules.MAX_CHANGE
	)
	var line: Variant = answer.get("line")
	if not (line is String and is_change and answer.get("personal") is bool):
		return {}
	var told := NpcPrompt.trimmed_reply(line, npc, sentences)
	if told == "":
		return {}
	return {"line": told, "change": int(change), "personal": answer["personal"]}


## Settles `verdict` on the story of the villager: it is judged now, its line is the verdict's,
## a personal one weighs high, and the villager's opinion moves by the change, in full for what
## they saw and by half for what they heard (the points and the share are `[opinion]`). The story
## may have left the villager's gossip buffer while the model was asked: the opinion moves all the
## same.
func settle(npc: Npc, story: Dictionary, verdict: Dictionary) -> void:
	npc.change_opinion(rules.opinion_points(verdict["change"], story["how"]), _clock.day, rules)
	story["is_judged"] = true
	story["line"] = verdict["line"]
	if verdict["personal"]:
		story["personal"] = true
		story["weight"] = MemoryWeight.HIGH
