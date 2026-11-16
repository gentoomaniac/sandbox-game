class_name GameFactory
extends RefCounted
## Builds a GameState: the new game, and the putting of a world under a game, with the systems that
## change with time (see Simulation), which a loaded game goes through as well (see GameCodec).
## Keeps nothing; the game it builds does not hold it.


## A new game: the player starts at a camp site near the world centre, with home set to its
## sleeping bag. The chunks around the camp are generated into the world here. With `with_village`
## the village Wehlsbüll is built too, with its eight villagers in it (a seed with no site for it
## has none): the game asks for it, the many tests that want a bare world do not pay its third of a
## second.
static func new_game(world_seed: int, with_village := false) -> GameState:
	var state := GameState.new()
	attach_world(state, World.new(world_seed, state.clock))
	var camp := CampSite.create(state.world, WorldGenerator.new(world_seed))
	var site := VillageSite.find(world_seed) if with_village else null
	if site != null:
		var plan := VillagePlan.default_plan()
		var problem := VillageBuilder.build(state.world, site, plan)
		if problem != "":
			push_error("The village was not built: %s" % problem)
		else:
			VillageBuilder.lay_track(state.world, site)
			problem = VillagePeople.move_in(state, site, plan)
			if problem != "":
				push_error("The villagers did not all move in: %s" % problem)
	state.quests.post_first()
	state.player.position = Vector2(camp.spawn_pos) + Vector2(0.5, 0.5)
	state.explored.see(state.player.tile())
	state.player.home_map = state.world
	state.player.home_bed = camp.sleeping_bag_pos
	state.player.inventory = Inventory.with_starting_items()
	state.player.purse = Purse.new(Prices.default_prices().start_purse())
	state.player.equipment = Equipment.with_starting_outfit()
	return state


## Puts the world under the game, with the weather that follows the world's seed and the systems
## that change with time. A game gets its world once, before anything else is built on it: a
## second world would leave the systems of the first running beside a new set.
static func attach_world(state: GameState, world: World) -> void:
	assert(state.world == null, "The game already has a world")
	state.world = world
	state.weather = Weather.new(world.world_seed, state.sun)
	state.snow_cover = SnowCover.new(state.weather)
	_install_systems(state)


## Puts what changes with time under the simulation, once the world and the weather exist. The
## order is the order they run in.
static func _install_systems(state: GameState) -> void:
	var world := state.world
	var simulation := state.simulation
	# The needs and the friendship of the animals count from the clock as it is now (as loaded, for a
	# loaded game).
	state.livestock.account_clock(state.clock)
	simulation.add_system(FarmingUpkeep.new(world, state.weather))
	state.scarecrows = Scarecrows.new(world)
	state.crop_raids = CropRaids.new(world, state.player_feet)
	state.crop_raids.is_guarded = state.scarecrows.is_guarding
	simulation.add_system(state.crop_raids)
	state.crop_warnings = CropWarnings.new(world, state.player_feet)
	simulation.add_system(state.crop_warnings)
	simulation.add_system(NightUpkeep.new(world, state.weather, state.tiles_kept_clear))
	state.activities = ActivityUpkeep.new(
		world, state.npcs, state.homes, state.sun, state.weather, state.clock
	)
	simulation.add_system(state.activities)
	simulation.add_system(
		ActorsUpkeep.new(
			world, state.livestock, state.npcs, state.player_feet, state.activities.catch_up
		)
	)
	simulation.add_system(GossipSpread.new(state.npcs, state.deeds))
	simulation.add_system(LanternUpkeep.new(state.the_player))
	simulation.add_system(CampfireUpkeep.new(world))
	simulation.add_system(SurgeUpkeep.new(world, state.weather))
	simulation.add_system(SurgeRefuge.new(world, state.npcs, state.livestock, state.activities))
