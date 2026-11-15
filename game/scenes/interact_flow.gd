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
var fire_screen: CampfireScreen
var crafting_screen: CraftingScreen
var board_screen: NoticeBoardScreen


## E: on horseback, gets off. Else speaks to the villager in front, gets on the saddled horse in
## front, opens the chest or station in reach, reads the notice board in reach, rings the bell frame
## in reach or sleeps in the bed.
func interact() -> void:
	var choice := Interaction.choice_at(state, use_highlight.targeting().tile)
	match choice.kind:
		Interaction.Kind.DISMOUNT:
			if not state.dismount():
				harvest_hud.show_note("No room to get off here.")
		Interaction.Kind.CHAT:
			open_chat(choice.subject)
		Interaction.Kind.TRADE:
			open_shop(choice.subject)
		Interaction.Kind.MOUNT:
			state.mount(choice.subject)
		Interaction.Kind.OPEN_STATION_GRID:
			process_screen.open_station(
				ProcessStation.new(state, Crafting.new(state), choice.subject)
			)
		Interaction.Kind.OPEN_CHEST:
			storage_screen.open_chest(choice.subject, state.player)
		Interaction.Kind.READ_BOARD:
			board_screen.open_board(state)
		Interaction.Kind.OPEN_FIRE:
			fire_screen.open_fire(choice.subject, state)
		Interaction.Kind.OPEN_CRAFTING:
			crafting_screen.open_station(choice.subject)
		Interaction.Kind.RING_BELL:
			state.ring_bell_in_reach()
		Interaction.Kind.SLEEP:
			blackout.try_sleep()


## Opens the trade with a shopkeeper, who turns to the player (the trade pauses the game).
func open_shop(keeper: Npc) -> void:
	console_view.close()
	state.npcs.talk_to(keeper, state.player.position)
	trade_screen.open_shop(keeper, state)


## Opens the chat with a villager, who turns to the player (the chat pauses the game). A shopkeeper
## at a shut stall says so first, and one with a quest gives it.
func open_chat(npc: Npc) -> void:
	state.npcs.talk_to(npc, state.player.position)
	ShopHours.greet(state, npc)
	var refusal := QuestTalk.greet(state, npc)
	chat_screen.open_chat(npc, state)
	if refusal != "":
		chat_screen.show_notice(refusal)
