class_name ScreenKeys
extends RefCounted
## The keys that open and close the bag, character, skills, quests and crafting windows in the game
## scene (and the crafting button beside the bag button). A window's key does nothing while another
## window is open (see Modal.can_open_on_key).

var _state: GameState
var _bag_screen: BagScreen
var _character_screen: CharacterScreen
var _crafting_screen: CraftingScreen
var _harvest_hud: HarvestHud


func _init(
	state: GameState,
	bag_screen: BagScreen,
	character_screen: CharacterScreen,
	crafting_screen: CraftingScreen,
	harvest_hud: HarvestHud
) -> void:
	_state = state
	_bag_screen = bag_screen
	_character_screen = character_screen
	_crafting_screen = crafting_screen
	_harvest_hud = harvest_hud


## Opens or closes the window whose key `event` presses; whether one did.
func take(event: InputEvent) -> bool:
	if event.is_action_pressed("crafting") and _crafting_screen.can_open_on_key():
		toggle_crafting()
		return true
	if event.is_action_pressed("inventory") and _bag_screen.can_open_on_key():
		_bag_screen.toggle()
		return true
	if event.is_action_pressed("character", false, true) and _character_screen.can_open_on_key():
		_character_screen.toggle_tab(CharacterScreen.Tab.CHARACTER)
		return true
	if event.is_action_pressed("skills") and _character_screen.can_open_on_key():
		_character_screen.toggle_tab(CharacterScreen.Tab.SKILLS)
		return true
	if event.is_action_pressed("quests") and _character_screen.can_open_on_key():
		_character_screen.toggle_tab(CharacterScreen.Tab.QUESTS)
		return true
	return false


## The crafting button beside the bag button does what the crafting key does.
func on_crafting_requested() -> void:
	if _crafting_screen.can_open_on_key():
		toggle_crafting()


func toggle_crafting() -> void:
	# On horseback only the inventory and eating are possible; an open screen still closes.
	if _crafting_screen.is_open() or _state.player.horse == null:
		_crafting_screen.toggle()
	else:
		_harvest_hud.show_note(UseNotes.GET_OFF_FIRST)
