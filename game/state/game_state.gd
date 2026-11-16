# gdlint: disable=max-public-methods
# (The aggregate: the weather the player sees, tool uses and the pieces the systems are built
# from, with the owners of the rest, such as PlayerTravel, in their own classes.)
class_name GameState
extends RefCounted
## Everything that makes up one game: the world, the clock and the player. Plain state with
## no rendering or input; scenes read it and send it actions such as `use_at`.
##
## The player is on one map at a time: the world, or the interior of a building. The world
## stays as it is while they are inside.

## The player finished an action that worked (see ActionOutcome). Told once, after it is done;
## nothing is told for a refusal or for loading a game.
signal action_done(outcome: ActionOutcome)

var world: World
var clock: GameClock
## Moves the clock and what follows it (see Simulation); time only passes through it.
var simulation: Simulation
## Where the sun is over the year; the weather follows it.
var sun := Sun.new()
## Built from the world seed (see GameFactory).
var weather: Weather
## Session-only (see Console): the weather condition that is forced, or &"" for the weather
## as the simulation has it. Not saved.
var weather_override := &""
## The snow on the ground, from the weather (see SnowCover); built with `weather`.
var snow_cover: SnowCover
var player := PlayerState.new()
## The land the player has seen (see the world map).
var explored := Exploration.new()
## Session-only cheats (see Console): not saved.
var cheats := CheatFlags.new()
## The dice of the harvests: how much a crop gives and whether it gives a seed. Tests seed it.
var harvest_rng := RandomNumberGenerator.new()
## The farm animals of the world. Main moves them while the player is out in the world.
var livestock := Livestock.new(sun, cheats)
## The crows' raids on the crops: the view tells it where its crow flocks stand. Built with the
## simulation; nothing of it is saved.
var crop_raids: CropRaids
var crop_warnings: CropWarnings
## What the scarecrows the player put down guard from the crows (see CropRaids `is_guarded`). Built
## with the simulation; the scarecrows themselves are objects of the world.
var scarecrows: Scarecrows
## The villagers of the world, moved like the farm animals.
var npcs := Npcs.new(sun)
## Who lives in which house.
var homes := Households.new(npcs)
## Sends the villagers where their day has them be. Built with the simulation; nothing of it is
## saved.
var activities: ActivityUpkeep
## What the shops have left to sell and take today (saved: a reload does not give back a sold-out
## shop).
var shops: Shops
## The quests the villagers have posted, and the player's list (see design/villagers/quests.md).
var quests: Quests
## The villagers buying at the player's sales carts as each day ends (see design/economy).
var stall_sales: StallSales
## What the player did within sight of villagers.
var deeds: DeedLog
## What the player takes, breaks and pushes that is a villager's (see Harm).
var harm: Harm
## What the villagers make of the stories they know (StoryJudging asks the language model).
var judge: StoryJudge
var energy_rules := EnergyRules.default_rules()
## What every use costs is multiplied by this (the Game setting: 0.5, 1 or 1.5).
var energy_drain := 1.0
## The player was awake when the clock reached PlayerRest.LATE_NIGHT_MINUTE (see `pass_awake_time`)
## and has not slept since: they pass out. Not saved.
var is_up_too_late := false
## Where the player is: the world, or the interior of the building they are inside.
var current_map: GameMap:
	get:
		return world if building_inside == null else building_inside.interior

## The building the player is inside, or null when they are out in the world. Set only by
## PlayerRest (doors, teleports, waking) and GameCodec (a loaded game); setting it also tells the
## households where the player is.
var building_inside: Building:
	set(building):
		building_inside = building
		homes.building_with_player = building


## `game_clock` is the clock to follow: a loaded game brings the one it saved. Whoever builds
## the world from it passes the same clock on (see GameFactory).
func _init(game_clock := GameClock.new()) -> void:
	clock = game_clock
	simulation = Simulation.new(clock)
	shops = Shops.new(ShopRules.default_rules(), clock)
	quests = Quests.new(QuestRules.default_rules(), clock, npcs, the_player, _the_world)
	stall_sales = StallSales.new(clock, _the_game)
	deeds = DeedLog.new(npcs, clock)
	judge = StoryJudge.new(npcs, clock)
	harm = Harm.new(npcs, homes, clock, deeds, _the_world)
	action_done.connect(deeds.record)
	action_done.connect(harm.record)
	npcs.villager_spawned.connect(homes.settle)


## The work of a frame of play (see Simulation `frame_work`), called once a frame by Main. The
## console's freeze holds it; indoors and under a black screen the world goes on.
func frame_work(delta: float) -> void:
	if cheats.is_time_stopped:
		return
	simulation.frame_work(delta)


func is_inside() -> bool:
	return building_inside != null


## The weather the player sees: at their tile, or outside the door of the house they are in
## (they would see it through its windows). A forced condition (see Console) replaces the
## simulated one, and a storm surge brings a storm of its own from its warning on.
func current_weather() -> WeatherSample:
	var sample := weather.at(outdoor_tile(), clock.day, clock.minute_of_day)
	if weather_override != &"":
		return weather.forced(sample, weather_override)
	return (
		weather.forced(sample, &"storm")
		if world.surge.is_stormy_at(clock.total_minutes())
		else sample
	)


## Lights a campfire that is out with a log of its slot (see Campfire `ignite`).
func light_campfire(fire: WorldObject) -> void:
	Campfire.ignite(fire)
	world.change_object(fire)


## The snow on the ground where the player is (or outside the house they are in), 0 to 1, now:
## it builds and melts a little every minute.
func current_snow_cover() -> float:
	return snow_cover.at(outdoor_tile(), clock.day, clock.minute_of_day)


## The frost on the ground where the player is, 0 to 1, now: it builds on a cold morning and
## goes as the day warms.
func current_frost() -> float:
	return snow_cover.frost_at(
		weather.at(outdoor_tile(), clock.day, clock.minute_of_day).temperature
	)


## The thaw where the player is, 0 to 1, now: the warmth and the sun that melt the snow.
func current_thaw() -> float:
	var sample := weather.at(outdoor_tile(), clock.day, clock.minute_of_day)
	return snow_cover.thaw_at(sample.temperature, sample.sunlight)


## How much it rained in the hour that has just ended, where the player sees the weather (see
## `current_weather`): the rain the soil there was wet by in that hour (see FarmingUpkeep). A
## forced condition gives its own rain.
func last_hour_rain() -> float:
	if weather_override != &"":
		return current_weather().rain
	# The first hour of the game has none before it, so it counts its own.
	var hour := maxi(clock.total_minutes() / GameClock.MINUTES_PER_HOUR - 1, 0)
	return weather.rain_in_hour(
		outdoor_tile(), hour / CropLife.HOURS_PER_DAY + 1, hour % CropLife.HOURS_PER_DAY
	)


## Makes the worn ground of the world mud or dry again by the rain of the last hours where the
## player sees the weather (see `last_hour_rain` and data/paths.cfg [mud]). Called every hour, and
## when a game is loaded.
func refresh_mud() -> void:
	var rules := PathRules.default_rules()
	var rain := 0.0
	if weather_override != &"":
		# A forced condition rains steadily.
		rain = current_weather().rain * rules.window_hours()
	else:
		var this_hour := clock.total_minutes() / GameClock.MINUTES_PER_HOUR
		var first_hour := maxi(this_hour - rules.window_hours(), 0)
		for hour in range(first_hour, this_hour):
			rain += weather.rain_in_hour(
				outdoor_tile(), hour / CropLife.HOURS_PER_DAY + 1, hour % CropLife.HOURS_PER_DAY
			)
	world.set_muddy(rain >= rules.soaked_by())


## The tile whose weather the player sees: theirs, or outside the door of the house they are in.
func outdoor_tile() -> Vector2i:
	return building_inside.door_tile() if is_inside() else player.tile()


## The most energy the player can have now.
func energy_cap() -> float:
	var max_energy := player.attributes.max_energy()
	return minf(energy_rules.debuff_energy_max(), max_energy) if player.is_debuffed else max_energy


## Rings the bell frame in reach, the one with the clicked tile (see Interaction). Returns whether
## there was one. Only heard and seen so far: it changes nothing in the game.
func ring_bell_in_reach(clicked: Variant = null) -> bool:
	var frame := Interaction.bell_frame_to_ring(self, clicked)
	if frame != null:
		world.bell_rung.emit(frame)
	return frame != null


## Tells that an action of the player worked: what it did on the player's map at `tile`, to the
## `object` type (if any), and with `items` (item id to count).
func report(kind: StringName, tile: Vector2i, object := &"", items := {}) -> void:
	action_done.emit(ActionOutcome.new(kind, current_map, tile, object, items))


func is_out_of_energy() -> bool:
	return player.energy <= 0.0


## What `use_tile` would do on a tile (see ToolUse). The use rules get a ToolUse made for the
## call: one kept in a field would hold the state while the state holds it, and neither would
## ever be freed.
func use_at(pos: Vector2i) -> ToolUse.Use:
	return ToolUse.new(self).use_at(pos)


func can_use_held_item() -> bool:
	return ToolUse.new(self).can_use_held_item()


## Uses a tile and returns what was done (see ToolUse).
func use_tile(target: Vector2i) -> ToolUse.Use:
	return ToolUse.new(self).use_tile(target)


func use_facing_tile() -> ToolUse.Use:
	return ToolUse.new(self).use_facing_tile()


## The tiles where a sapling does not grow into a tree, for it would be under the player's feet.
## A named method: a lambda would keep the whole game alive from the simulation it belongs to.
func tiles_kept_clear() -> Array:
	return [] if is_inside() else [player.tile()]


## The world, for what is made before there is one (see `quests`).
func _the_world() -> World:
	return world


## This game, for what the game owns and so must not hold (see `stall_sales`).
func _the_game() -> GameState:
	return self


## The player: a loaded game has a new one, which systems must not hold on to.
func the_player() -> PlayerState:
	return player


## Where the player is for the animals and villagers of the world, which an indoor player is
## not part of: infinitely far.
func player_feet() -> Vector2:
	return Vector2.INF if is_inside() else player.position


## The building whose interior this is, or null for the world.
func building_with_interior(map: GameMap) -> Building:
	for building in world.buildings():
		if building.interior == map:
			return building
	return null
