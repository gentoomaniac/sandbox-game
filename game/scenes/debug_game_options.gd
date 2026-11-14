class_name DebugGameOptions
extends RefCounted
## The debug flags that change the game itself (see StartupOptions), applied before any view reads
## it.


## Applies the flags that change the game itself, before any view reads it.
static func apply(options: StartupOptions, state: GameState) -> void:
	if options.at != StartupOptions.NO_TILE:
		state.player.position = Vector2(options.at) + Vector2(0.5, 0.5)
	if options.day > 0:
		state.clock.day = options.day
	if options.time_hour >= 0:
		state.clock.set_time(options.time_hour, options.time_minute)
	if options.field != StartupOptions.NO_TILE:
		DebugField.create(state.world, options.field)
	if options.forage != StartupOptions.NO_TILE:
		DebugForage.create(state, options.forage)
	if options.felled != StartupOptions.NO_TILE:
		DebugFelled.create(state.world, options.felled)
	if options.mow != StartupOptions.NO_TILE:
		DebugMow.create(state, options.mow)
	if options.path != StartupOptions.NO_TILE:
		DebugPath.create(state.world, options.path, options.path_days.x, options.path_days.y)
	if options.drops != StartupOptions.NO_TILE:
		DebugDrops.create(state.world, options.drops)
	if options.items != StartupOptions.NO_TILE:
		DebugItems.create(state, options.items)
	if options.landing != StartupOptions.NO_TILE:
		DebugLanding.create(state.world, options.landing)
	if options.yard != StartupOptions.NO_TILE:
		DebugYard.create(state, options.yard)
	if options.worn_ground != StartupOptions.NO_TILE:
		DebugWornGround.create(state.world, options.worn_ground)
	if options.energy >= 0.0:
		state.player.energy = options.energy
	if options.health >= 0.0:
		state.player.health = options.health
	if options.wear != &"":
		state.player.equipment.equip(Equipment.slot_of(options.wear), options.wear)
	if options.hold != &"":
		_hold(state, options.hold)
	if options.is_build_free:
		state.cheats.is_cost_off = true
	if options.riding != &"":
		_ride(state, options.riding)
	if Weather.FORCEABLE.has(options.weather):
		state.weather_override = options.weather
	elif options.weather != &"":
		push_error("--weather expects one of %s, got '%s'" % [Weather.FORCEABLE, options.weather])
	state.snow_cover.forced = options.snow
	state.snow_cover.forced_frost = options.frost
	state.snow_cover.forced_thaw = options.melt


## Debug (`--hold`): puts 5 of an item in the inventory and holds it, if it is on the hotbar.
static func _hold(state: GameState, item: StringName) -> void:
	if not ItemTypes.TYPES.has(item):
		push_error("--hold expects an item, got '%s'" % item)
		return
	var inventory := state.player.inventory
	inventory.add(item, 5)
	inventory.hold(item)


## Debug (`--riding`): puts a saddled horse of a look under the player and gets on it.
static func _ride(state: GameState, look: StringName) -> void:
	if not state.livestock.rules.looks(LivestockRules.HORSE).has(look):
		push_error("--riding expects a look of the horse, got '%s'" % look)
		return
	var horse := FarmAnimal.new(LivestockRules.HORSE, look, state.player.position)
	horse.is_saddled = true
	state.livestock.add(horse)
	state.mount(horse)
