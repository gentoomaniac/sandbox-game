class_name CraftingFlow
extends Node
## What the game scene shows of crafting: the crafting window, which E opens on a crafting station
## (the campfire's [Cook] button opens it too, see CampfireFlow), and the click of its buttons. Main
## creates it with the game it shows; it registers the stations' words and opening itself.

var screen := CraftingScreen.new()


func _init(state: GameState, interactions: InteractionRegistry, sounds: GameSounds) -> void:
	add_child(screen)
	screen.show_crafting(Crafting.new(state), state.player.inventory)
	sounds.click_on_press_in(screen)
	interactions.register(
		Interaction.Kind.OPEN_CRAFTING,
		func(station: WorldObject) -> String: return "Craft at %s" % Interaction.name_of(station),
		func(station: WorldObject) -> void: screen.open_station(station)
	)
