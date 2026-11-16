class_name CampfireFlow
extends Node
## What the game scene shows of a campfire: its window, which E opens on the fire, and the crafting
## menu of the fire that its [Cook] button asks for. Main creates it with the game it shows; it
## registers the fire's words and opening and the click of its buttons itself.


func _init(
	state: GameState,
	hotbar: HotbarHud,
	crafting_screen: CraftingScreen,
	interactions: InteractionRegistry,
	sounds: GameSounds
) -> void:
	var fire_screen := CampfireScreen.new(hotbar)
	add_child(fire_screen)
	fire_screen.cook_requested.connect(crafting_screen.open_station)
	sounds.click_on_press_in(fire_screen)
	interactions.register(
		Interaction.Kind.OPEN_FIRE,
		"Tend the fire",
		func(fire: WorldObject) -> void: fire_screen.open_fire(fire, state)
	)
