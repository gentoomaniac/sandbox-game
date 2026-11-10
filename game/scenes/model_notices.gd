class_name ModelNotices
extends Node
## Tells the player in the notifications when the villagers' language model fails ("Villagers'
## language model is busy (HTTP 503): ...") and, quietly, when it answers again. Wired to the
## `failed` and `worked` signals of the chats of an NpcDialogue, so the chats stay free of HUD
## code. The model's lines share one notification, so a burst of failed lines shows once, and the
## same trouble is not shown again for a few minutes (data/npc_talk.cfg `notice_repeat_seconds`).
## The default endpoint, the test LLM that is often not running, is never reported: only an
## endpoint the player set themselves is.

## The key of the notification (see NotificationHud `post`).
const NOTE := &"language_model"
const TROUBLE_TEXT := "Villagers' language model %s"
const ANSWERS_AGAIN_TEXT := "Villagers' language model answers again"

var repeat_seconds: float
var _detail_length: int
var _notifications: NotificationHud
## When each trouble was last shown, in ticks (msec) of the clock.
var _shown_at: Dictionary[String, int] = {}
## Whether a trouble is on show that the player has not been told is over.
var _is_troubled := false


func _init(
	dialogue: NpcDialogue, notifications: NotificationHud, rules := NpcTalkRules.default_rules()
) -> void:
	_notifications = notifications
	repeat_seconds = rules.value("request", "notice_repeat_seconds")
	_detail_length = rules.value("request", "notice_detail_length")
	for chat: ModelChat in dialogue.chats.values():
		chat.failed.connect(_on_failed)
		chat.worked.connect(_on_worked)


func _on_failed(endpoint: String, trouble: String, detail: String) -> void:
	if GameSettings.is_default_language_model_endpoint(endpoint):
		return
	var now := Time.get_ticks_msec()
	if _shown_at.has(trouble) and now - _shown_at[trouble] < repeat_seconds * 1000.0:
		return
	_shown_at[trouble] = now
	_is_troubled = true
	var text := TROUBLE_TEXT % trouble
	if detail != "":
		text += ": " + _shortened(detail)
	_notifications.post(NOTE, text, NotificationHud.Tone.ERROR)


func _on_worked(endpoint: String) -> void:
	if _is_troubled and not GameSettings.is_default_language_model_endpoint(endpoint):
		_is_troubled = false
		_notifications.post(NOTE, ANSWERS_AGAIN_TEXT)


func _shortened(detail: String) -> String:
	if detail.length() <= _detail_length:
		return detail
	return detail.left(_detail_length).strip_edges() + "..."
