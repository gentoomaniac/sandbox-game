class_name TalkFriendship
extends RefCounted
## What the player's talk does to a villager's opinion of them (design/villagers/relationships.md):
## the first chat of a day counts a few points, with no model needed. A chat is a line the player
## says to the villager (see NpcDialogue `say`), not the opening of the window.


## Counts the chat of today with `npc`: the first one of a day moves their opinion by
## FriendshipRules `first_chat_points`, later ones nothing.
static func count_chat(state: GameState, npc: Npc) -> void:
	var today := state.clock.day
	if npc.chat_counted_day == today:
		return
	npc.chat_counted_day = today
	var friendship := FriendshipRules.default_rules()
	npc.change_friendship(
		friendship.first_chat_points(), today, friendship, GossipRules.default_rules()
	)
