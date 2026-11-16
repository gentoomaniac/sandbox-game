# gdlint: disable=max-public-methods
# (GameState is the one entry point the scenes and the console act through: tool uses, the held
# item, pickup and demolition go via it.)
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

## What using the held lantern does (see `held_lantern_use`).
enum LanternUse { NONE, PUT_OUT, LIGHT, FIT_CANDLE }

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
## How the player walks and rides (see PlayerTravel); it is given this game on each call.
var travel := PlayerTravel.new()
## Where the player is: the world, or the interior of the building they are inside.
var current_map: GameMap:
	get:
		return world if building_inside == null else building_inside.interior

## The building the player is inside, or null when they are out in the world.
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


## What the lantern in hand does when used (see `switch_held_lantern`): lit, it is put out; with a
## candle in it, it is lit; with none, the freshest candle of the inventory is fitted (and it stays
## dark); with none to fit, or with no lantern in hand, nothing.
func held_lantern_use() -> LanternUse:
	var inventory := player.inventory
	if inventory.held_item() != ItemTypes.LANTERN:
		return LanternUse.NONE
	if LanternCandle.holds_candle(inventory.slots[inventory.selected_slot]):
		return LanternUse.PUT_OUT if player.is_lantern_lit else LanternUse.LIGHT
	return LanternUse.FIT_CANDLE if inventory.freshest_candle_slot() != -1 else LanternUse.NONE


## Uses the held lantern, on any map, also on horseback (see `held_lantern_use`). Does nothing, and
## returns false, when that is NONE.
func switch_held_lantern() -> bool:
	var use := held_lantern_use()
	match use:
		LanternUse.NONE:
			return false
		LanternUse.FIT_CANDLE:
			player.inventory.fit_candle(player.inventory.selected_slot)
			player.is_lantern_lit = false
		_:
			player.is_lantern_lit = use == LanternUse.LIGHT
	report(ActionOutcome.SWITCH_LANTERN, player.tile(), &"", {ItemTypes.LANTERN: 1})
	return true


## Whether the held item is food and the energy is below the cap, so that `eat_held` eats it.
func can_eat_held() -> bool:
	return energy_rules.is_food(player.inventory.held_item()) and player.energy < energy_cap()


## Eats one of the held food, on any map: it restores energy up to the cap. Does nothing, and
## returns false, unless `can_eat_held`.
func eat_held() -> bool:
	if not can_eat_held():
		return false
	var food := player.inventory.held_item()
	player.inventory.consume_held()
	player.energy = minf(player.energy + energy_rules.food_restore(food), energy_cap())
	report(ActionOutcome.EAT, player.tile(), &"", {food: 1})
	return true


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


## Maps are saved as references, never as copies: `{"kind": "world"}`, or
## `{"kind": "interior", "building": [x, y]}` for the interior of the building with that
## origin. So the current map and the home map stay the very objects they point at.
func to_dict() -> Dictionary:
	return GameState.dict_of(snapshot())


## A copy of what `to_dict` writes that is quick to take and shares nothing with the game, and
## that `dict_of` makes save data of: the part of saving that has to stop the game, a moment.
func snapshot() -> Dictionary:
	livestock.account_clock(clock)
	var player_data := player.to_dict()
	# A game saved on horseback loads with the player standing beside the horse (or, with no room
	# there, on its spot).
	var spot := Vector2.INF if player.horse == null else travel.dismount_spot(self)
	if spot != Vector2.INF:
		player_data["position"] = SaveCodec.float_vector_to_json(spot)
	return {
		"world": world.snapshot(),
		"explored": explored.snapshot(),
		"clock": clock.to_dict(),
		"player": player_data,
		"livestock": livestock.to_array(),
		"npcs": npcs.to_array(),
		"shops": shops.to_dict(),
		"quests": quests.to_dict(),
		"deeds": deeds.to_array(),
		"current_map": _map_to_ref(current_map),
		"home_map": _map_to_ref(player.home_map),
	}


## The save data of a `snapshot`. Safe to call from a thread.
static func dict_of(snapshot_data: Dictionary) -> Dictionary:
	var data := snapshot_data.duplicate()
	data["world"] = WorldSave.dict_of(snapshot_data["world"])
	data["explored"] = Exploration.array_of(snapshot_data["explored"])
	return data


## The chunks of the restored world are not loaded yet: whoever shows it streams them in.
static func from_dict(data: Dictionary) -> GameState:
	var state := GameState.new(GameClock.from_dict(data["clock"]))
	GameFactory.attach_world(state, World.from_dict(data["world"], state.clock))
	state.player = PlayerState.from_dict(data["player"], state._map_from_ref(data["home_map"]))
	state.explored.load_array(data["explored"])
	state.livestock.load_array(data["livestock"])
	state.npcs.load_array(data["npcs"], state.world)
	for npc in state.npcs.all():
		state.activities.resume(npc)
	state.shops.load_dict(data["shops"])
	state.quests.load_dict(data["quests"])
	state.deeds.load_array(data["deeds"])
	state.building_inside = state._building_of_ref(data["current_map"])
	# The land about the player is seen from where they stand (a save from before the record has
	# none).
	if not state.is_inside():
		state.explored.see(state.player.tile())
	# No sleep wakes between 01:00 and 06:30, so a game saved then was quit by a player who
	# stayed up: they still pass out (`is_up_too_late` itself is not saved).
	var minute := state.clock.minute_of_day
	state.is_up_too_late = (
		minute >= PlayerRest.LATE_NIGHT_MINUTE and minute < PlayerRest.WAKE_UP_MINUTE
	)
	# The rain of the hours before the save still lies on the ground.
	state.refresh_mud()
	return state


func _map_to_ref(map: GameMap) -> Dictionary:
	if map == world:
		return {"kind": "world"}
	var building := building_with_interior(map)
	assert(building != null, "A map that belongs to no building")
	return {"kind": "interior", "building": SaveCodec.vector_to_json(building.origin)}


func _map_from_ref(ref: Dictionary) -> GameMap:
	var building := _building_of_ref(ref)
	return world if building == null else building.interior


## The building whose interior the reference names, or null for the world.
func _building_of_ref(ref: Dictionary) -> Building:
	if ref["kind"] == "world":
		return null
	var origin := SaveCodec.vector_from_json(ref["building"])
	for building in world.buildings():
		if building.origin == origin:
			return building
	assert(false, "No building at %s" % origin)
	return null


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
