class_name TalkFriendship
extends RefCounted
## What the player's talk does to a villager's opinion of them (design/villagers/relationships.md):
## the first chat of a day counts a few points, with no model needed. A chat is a line the player
## says to the villager (see NpcDialogue `say`), not the opening of the window. With a model the
## line is rated too (see WordRating): a villager is asked for a few ratings a day, and what they
## move the opinion by is capped for the day, both for the cost and for the game's own balance.


## Has a villager who has shunned the player (no `talk` benefit, see Benefits) say a line of
## `turn_away` when the player speaks to them, before the player writes, unless that was the last
## thing said in their chat.
static func greet(state: GameState, npc: Npc) -> void:
	if Benefits.allows(npc, &"talk"):
		return
	var lines: Array = NpcTalkRules.default_rules().value("scripted", "turn_away")
	var line: String = lines[(state.clock.day + npc.name.hash()) % lines.size()]
	var history := npc.chat_history
	if history.is_empty() or history.back()["text"] != line:
		npc.add_chat_line(state.clock.day, state.clock.minute_of_day, false, line)


## Counts the chat of today with `npc`: the first one of a day moves their opinion by
## FriendshipRules `first_chat_points`, later ones nothing.
static func count_chat(state: GameState, npc: Npc) -> void:
	var today := state.clock.day
	if npc.chat_counted_day == today:
		return
	npc.chat_counted_day = today
	var friendship := FriendshipRules.default_rules()
	npc.change_friendship(
		friendship.value("talk", "first_chat_points"),
		today,
		friendship,
		GossipRules.default_rules()
	)


## Takes one of the day's requests for a rating of the player's words, if the villager has been
## asked for fewer than `requests_per_day` today, and says whether it was taken. A request counts
## whether or not its answer comes.
static func take_rating_request(state: GameState, npc: Npc) -> bool:
	var friendship := FriendshipRules.default_rules()
	_start_rating_day(state, npc)
	if npc.ratings_today >= friendship.value("rating", "requests_per_day"):
		return false
	npc.ratings_today += 1
	return true


## What the rating (`warm`, `neutral` or `rude`) of the player's words does: the opinion moves by
## its points, as far as the day's cap of the ratings and of the actions allow.
static func apply_rating(state: GameState, npc: Npc, rating: StringName) -> void:
	var friendship := FriendshipRules.default_rules()
	_start_rating_day(state, npc)
	var cap_up := friendship.rating_daily_cap(&"warm")
	var cap_down := friendship.rating_daily_cap(&"rude")
	var moved := (
		clampi(npc.rating_moved_today + friendship.rating_points(rating), -cap_down, cap_up)
		- npc.rating_moved_today
	)
	npc.rating_moved_today += moved
	npc.change_friendship(moved, state.clock.day, friendship, GossipRules.default_rules())


static func _start_rating_day(state: GameState, npc: Npc) -> void:
	if npc.rating_day != state.clock.day:
		npc.rating_day = state.clock.day
		npc.ratings_today = 0
		npc.rating_moved_today = 0
