class_name FeatureFlows
extends RefCounted
## The feature flows of the game scene, made together so that Main and the tests make the same ones.
## Each flow registers its kind of E in `interactions` and the sounds of its screens; it is not yet
## in the tree: Main adds each where its screens are layered and take input, in an order that is
## explicit there, not discovered here. This also gives InteractFlow the screens and the voice it
## needs.

var crafting: CraftingFlow
var storage: StorageFlow
var trade: TradeFlow
var process: ProcessFlow
var campfire: CampfireFlow
var chat: ChatFlow
var quest: QuestFlow
var friendship: FriendshipFlow
var surge: SurgeFlow
var barter: BarterFlow
var stall: StallFlow


## `entities` is where the world's things are drawn; `toggle_art_set` is what the chat's art switch
## does. `interact` has its other needs set by Main.
func _init(
	state: GameState,
	settings: GameSettings,
	hotbar: HotbarHud,
	sounds: GameSounds,
	notifications: NotificationHud,
	entities: Node2D,
	interactions: InteractionRegistry,
	interact: InteractFlow,
	toggle_art_set: Callable
) -> void:
	crafting = CraftingFlow.new(state, interactions, sounds)
	storage = StorageFlow.new(state, hotbar, interactions, sounds)
	trade = TradeFlow.new(sounds)
	process = ProcessFlow.new(state, hotbar, interactions, sounds)
	campfire = CampfireFlow.new(state, hotbar, crafting.screen, interactions, sounds)
	chat = ChatFlow.new(settings, notifications, toggle_art_set, sounds)
	quest = QuestFlow.new(state, chat.dialogue, notifications, entities, interactions)
	friendship = FriendshipFlow.new(state, notifications, entities)
	surge = SurgeFlow.new(state, notifications)
	barter = BarterFlow.new(state, chat.screen, interact.open_chat)
	stall = StallFlow.new(state, interactions)
	interact.chat_screen = chat.screen
	interact.trade_screen = trade.screen
	interact.quest_voice = quest.voice
	interact.register_kinds(interactions)
	trade.screen.talk_requested.connect(interact.open_chat)


## Every flow, for the tests that put them in a tree; Main adds them one by one, where each belongs.
func all() -> Array[Node]:
	return [
		crafting, storage, trade, process, campfire, chat, quest, friendship, surge, barter, stall
	]
