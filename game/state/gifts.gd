class_name Gifts
extends RefCounted
## The player giving a villager the item in their hand (design/villagers/relationships.md): the
## villager likes it, has no feelings about it or dislikes it, and thinks the more or the less of
## the player by the points of FriendshipRules `gift_points`, counted within the cap of the
## actions. A villager takes one gift a day, whatever it is. The giving is seen as the deed
## `gave_gift` (see DeedLog `record_gift`), and the villager answers with a line of [gift] of
## data/npc_talk.cfg.

## What came of giving: the villager's taste, or that they took no more today, or that the hand
## was empty.
const LIKED := &"liked"
const NEUTRAL := &"neutral"
const DISLIKED := &"disliked"
const REFUSED_TODAY := &"refused_today"
const NOTHING_HELD := &"nothing_held"


## Whether `npc` likes, dislikes or has no feelings about the item: a villager of data/villagers.cfg
## by their sheet, one made up by the set of activities of their trade (data/npcs.cfg).
static func taste_of(state: GameState, npc: Npc, item: StringName) -> StringName:
	var liked: Array
	var disliked: Array
	if state.npcs.villagers.has(npc.id):
		var sheet := state.npcs.villagers.villager(npc.id)
		liked = sheet["gifts_liked"]
		disliked = sheet["gifts_disliked"]
	else:
		var rules := state.npcs.rules
		var tastes := rules.gift_tastes_of_set(rules.work_set_of_trade(npc.trade))
		liked = tastes["liked"]
		disliked = tastes["disliked"]
	if liked.has(str(item)):
		return LIKED
	return DISLIKED if disliked.has(str(item)) else NEUTRAL


## The player gives `npc` the item in their hand, and the villager answers in their chat. Returns
## what came of it. Nothing is taken from the player, and no friendship moves, unless it is taken.
static func give(state: GameState, npc: Npc) -> StringName:
	var inventory := state.player.inventory
	var item := inventory.held_item()
	if item == ItemTypes.NONE:
		return NOTHING_HELD
	var today := state.clock.day
	var outcome := REFUSED_TODAY
	if npc.last_gift_day != today:
		outcome = taste_of(state, npc, item)
		inventory.consume_held()
		npc.last_gift_day = today
		var friendship := FriendshipRules.default_rules()
		var points := friendship.gift_points(outcome)
		npc.change_friendship(points, today, friendship, GossipRules.default_rules())
		var spot := Vector2.INF if state.is_inside() else state.player.position
		state.deeds.record_gift(npc, spot)
	var line_key := "already_today" if outcome == REFUSED_TODAY else str(outcome)
	var line: String = NpcTalkRules.default_rules().value("gift", line_key)
	var item_name: String = ItemTypes.TYPES[item]["name"].to_lower()
	npc.add_chat_line(today, state.clock.minute_of_day, false, line.format({"item": item_name}))
	return outcome
