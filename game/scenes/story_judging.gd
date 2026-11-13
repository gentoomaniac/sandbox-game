class_name StoryJudging
extends Node
## Has the stories of the villagers judged (StoryJudge) in the background: while there is a story
## in the queue it asks the language model, one story and one request at a time like the memory
## summaries of NpcDialogue, and settles what comes back. Without a model, or with an answer the
## game can't take, the verdict is the fixed one, at once. Nothing waits for it: a story told
## before its verdict is there is told by its template line.

## How often (in real seconds) the queue is looked at.
const LOOK_SECONDS := 0.5

var rules := NpcTalkRules.default_rules()
var _judge: StoryJudge
var _dialogue: NpcDialogue
var _state: GameState
var _is_judging := false
var _seconds_since_look := 0.0


func _init(dialogue: NpcDialogue, state: GameState) -> void:
	_dialogue = dialogue
	_state = state
	_judge = state.judge
	# Like the model's answers, it goes on while the game is paused, as it is during a chat.
	process_mode = Node.PROCESS_MODE_ALWAYS


func _process(delta: float) -> void:
	_seconds_since_look += delta
	if _seconds_since_look >= LOOK_SECONDS:
		_seconds_since_look = 0.0
		judge_queue()


## Judges every story of the queue, one after the other; a call while the queue is being judged
## leaves it to the one at work.
func judge_queue() -> void:
	if _is_judging:
		return
	_is_judging = true
	var next := _judge.next_in_queue()
	while not next.is_empty():
		await _judge_story(next["npc"], next["story"])
		next = _judge.next_in_queue()
	_is_judging = false


func _judge_story(npc: Npc, story: Dictionary) -> void:
	var verdict := _judge.fixed_verdict(story)
	if _dialogue.has_model():
		var request := NpcPrompt.judge_request(
			npc, story, _state.clock.day - story["day"], rules, _dialogue.has_full_sheets()
		)
		var reply := await _dialogue.ask(request, true)
		var parsed := StoryJudge.parse_verdict(
			reply, npc, rules.value("request", "reply_sentences")
		)
		if not parsed.is_empty():
			verdict = parsed
	_judge.settle(npc, story, verdict)
