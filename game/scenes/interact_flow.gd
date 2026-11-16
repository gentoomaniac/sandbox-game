class_name InteractFlow
extends RefCounted
## What the interact key (E) does in the game scene, and the opening of a chat or a trade, which
## the console and the debug flags use too.

## What it needs from Main is set after `new()`.
var state: GameState
var use_highlight: UseHighlight
var harvest_hud: HarvestHud
var blackout: BlackoutFlow
var console_view: ConsoleView
var chat_screen: ChatScreen
var trade_screen: TradeScreen
var process_screen: ProcessScreen
var storage_screen: StorageScreen
var crafting_screen: CraftingScreen
var quest_voice: QuestVoice


## Registers what E does for the kinds the flow itself serves, and the words of their hint. The
## features that bring a screen of their own register their kinds themselves. The flow does not keep
## the registry: the registry holds callables of the flow, and keeping it would make a cycle.
func register_kinds(interactions: InteractionRegistry) -> void:
	interactions.register(Interaction.Kind.DISMOUNT, "Get off the horse", _dismount)
	interactions.register(
		Interaction.Kind.CHAT, func(npc: Npc) -> String: return "Talk to %s" % npc.name, open_chat
	)
	interactions.register(
		Interaction.Kind.TRADE,
		func(npc: Npc) -> String: return "Trade with %s" % npc.name,
		open_shop
	)
	interactions.register(Interaction.Kind.MOUNT, "Get on the horse", state.mount)
	interactions.register(
		Interaction.Kind.OPEN_STATION_GRID,
		func(station: WorldObject) -> String: return "Use %s" % _name_of(station),
		func(station: WorldObject) -> void:
			process_screen.open_station(ProcessStation.new(state, Crafting.new(state), station))
	)
	interactions.register(
		Interaction.Kind.OPEN_CHEST,
		func(chest: WorldObject) -> String: return "Open %s" % _name_of(chest),
		func(chest: WorldObject) -> void: storage_screen.open_chest(chest, state)
	)
	interactions.register(
		Interaction.Kind.OPEN_CRAFTING,
		func(station: WorldObject) -> String: return "Craft at %s" % _name_of(station),
		func(station: WorldObject) -> void: crafting_screen.open_station(station)
	)
	interactions.register(
		Interaction.Kind.RING_BELL,
		"Ring the bell",
		func(_frame: Building) -> void: state.ring_bell_in_reach()
	)
	interactions.register(
		Interaction.Kind.SLEEP, "Sleep", func(_bed: WorldObject) -> void: blackout.try_sleep()
	)


## E: on horseback, gets off. Else speaks to the villager in front, gets on the saddled horse in
## front, opens the chest or station in reach, reads the notice board in reach, rings the bell frame
## in reach or sleeps in the bed.
func interact(interactions: InteractionRegistry) -> void:
	interactions.open(Interaction.choice_at(state, use_highlight.targeting().tile))


func _dismount(_no_subject: Variant) -> void:
	if not state.dismount():
		harvest_hud.show_note("No room to get off here.")


func _name_of(object: WorldObject) -> String:
	return String(object.type).replace("_", " ")


## Opens the trade with a shopkeeper, who turns to the player (the trade pauses the game).
func open_shop(keeper: Npc) -> void:
	console_view.close()
	state.npcs.talk_to(keeper, state.player.position)
	trade_screen.open_shop(keeper, state)


## Opens the chat with a villager, who turns to the player (the chat pauses the game). A shopkeeper
## at a shut stall says so first, one who has shunned the player turns away, and one with a quest
## gives it (see QuestVoice).
func open_chat(npc: Npc) -> void:
	state.npcs.talk_to(npc, state.player.position)
	ShopHours.greet(state, npc)
	TalkFriendship.greet(state, npc)
	var saying := QuestTalk.greet(state, npc)
	chat_screen.open_chat(npc, state)
	if saying.refusal != "":
		chat_screen.show_notice(saying.refusal)
	quest_voice.speak(state, npc, saying)
