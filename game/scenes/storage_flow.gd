class_name StorageFlow
extends Node
## What the game scene shows of storage: the window of a chest, which E opens on the chest, and the
## click of its buttons. Main creates it with the game it shows; it registers the chest's words and
## opening itself.

var screen: StorageScreen


func _init(
	state: GameState, hotbar: HotbarHud, interactions: InteractionRegistry, sounds: GameSounds
) -> void:
	screen = StorageScreen.new(hotbar)
	add_child(screen)
	screen.drop_requested.connect(state.drop_from_inventory)
	sounds.click_on_press_in(screen)
	interactions.register(
		Interaction.Kind.OPEN_CHEST,
		func(chest: WorldObject) -> String: return "Open %s" % Interaction.name_of(chest),
		func(chest: WorldObject) -> void: screen.open_chest(chest, state)
	)
