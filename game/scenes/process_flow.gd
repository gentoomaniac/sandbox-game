class_name ProcessFlow
extends Node
## What the game scene shows of the process stations (the kiln, the smelter): their window, which E
## opens on a station, and the sounds of its buttons and opening. Main creates it with the game it
## shows; it registers the stations' words and opening itself.

var screen: ProcessScreen


func _init(
	state: GameState, hotbar: HotbarHud, interactions: InteractionRegistry, sounds: GameSounds
) -> void:
	screen = ProcessScreen.new(hotbar)
	add_child(screen)
	sounds.click_on_press_in(screen)
	sounds.watch_panel(screen.is_open)
	interactions.register(
		Interaction.Kind.OPEN_STATION_GRID,
		func(station: WorldObject) -> String: return "Use %s" % Interaction.name_of(station),
		func(station: WorldObject) -> void:
			screen.open_station(ProcessStation.new(state, Crafting.new(state), station))
	)
