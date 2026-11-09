# gdlint: disable=max-public-methods
# (GameState is the one entry point the scenes and the console act through: tool uses, sleeping,
# passing out and the doors all go via it.)
class_name GameState
extends RefCounted
## Everything that makes up one game: the world, the clock and the player. Plain state with
## no rendering or input; scenes read it and send it actions such as `sleep_in`.
##
## The player is on one map at a time: the world, or the interior of a building. The world
## stays as it is while they are inside.

## Sleeping and passing out wake the player the next time the clock shows this.
const WAKE_UP_MINUTE := 6 * GameClock.MINUTES_PER_HOUR + 30
## Passing out sleeps at least this long, even when the morning comes sooner.
const PASS_OUT_MINUTES := 10 * GameClock.MINUTES_PER_HOUR
## A player who is still awake when the clock shows this has stayed up too late and passes out.
const LATE_NIGHT_MINUTE := 1 * GameClock.MINUTES_PER_HOUR
## Items on the ground within this many tiles of the player (their feet) are pulled to them.
const PULL_RADIUS := 1.25
## How fast a pulled item moves, in tiles per second: faster than the player walks, so it
## catches up.
const PULL_SPEED := 8.0
## A pulled item that is this close is picked up.
const PICKUP_RADIUS := 0.15
## Getting off a horse puts the player on free ground at most this many tiles from it.
const DISMOUNT_REACH := 2

var world: World
var clock: GameClock
## Where the sun is over the year; the weather follows it.
var sun := Sun.new()
## Built from the world seed (see `new_game` and `from_dict`).
var weather: Weather
## Session-only (see Console): the weather condition that is forced, or &"" for the weather
## as the simulation has it. Not saved.
var weather_override := &""
## The snow on the ground, from the weather (see SnowCover); built with `weather`.
var snow_cover: SnowCover
var player := PlayerState.new()
## The farm animals of the world. Main moves them while the player is out in the world.
var livestock := Livestock.new(sun)
## The villagers of the world, moved like the farm animals.
var npcs := Npcs.new(sun)
var energy_rules := EnergyRules.default_rules()
## What every use costs is multiplied by this (the Game setting: 0.5, 1 or 1.5).
var energy_drain := 1.0
## Session-only cheats (see Console): not saved.
var cheats := CheatFlags.new()
## The player was awake when the clock reached LATE_NIGHT_MINUTE (see `pass_awake_time`) and has
## not slept since: they pass out. Not saved.
var is_up_too_late := false
## Where the player is: the world, or the interior of the building they are inside.
var current_map: GameMap:
	get:
		return world if _building_inside == null else _building_inside.interior

## The building the player is inside, or null when they are out in the world.
var _building_inside: Building
## Seconds the player has kept moving: a horse trots after a while (see `is_trotting`). Not
## saved.
var _moving_seconds := 0.0


## `game_clock` is the clock to follow: a loaded game brings the one it saved. Whoever builds
## the world from it passes the same clock on (see `new_game` and `from_dict`).
func _init(game_clock := GameClock.new()) -> void:
	clock = game_clock
	clock.new_day.connect(_on_new_day)


## A new game: the player starts at a camp site near the world centre, with home set to its
## sleeping bag. The chunks around the camp are generated into the world here.
static func new_game(world_seed: int) -> GameState:
	var state := GameState.new()
	state.world = World.new(world_seed, state.clock)
	state.weather = Weather.new(world_seed, state.sun)
	state.snow_cover = SnowCover.new(state.weather)
	var camp := CampSite.create(state.world, WorldGenerator.new(world_seed))
	state.player.position = Vector2(camp.spawn_pos) + Vector2(0.5, 0.5)
	state.player.home_map = state.world
	state.player.home_bed = camp.sleeping_bag_pos
	state.player.inventory = Inventory.with_starting_items()
	state.player.equipment = Equipment.with_starting_outfit()
	return state


func is_inside() -> bool:
	return _building_inside != null


## Whether the player stands on a tile that leads to another map: the door of a building in
## the world, or the exit of the interior they are in. Never on horseback: a horse that stood in a
## doorway when they got on it is ridden out of it, not into the house.
func door_underfoot() -> bool:
	if player.horse != null:
		return false
	var tile := player.tile()
	if is_inside():
		return tile == _building_inside.interior.exit_tile
	var building := world.building_at(tile)
	return building != null and building.door_tile() == tile and building.has_inside()


## Takes the player through the door under their feet: into the building (making its interior
## the first time), or out to the tile in front of its door.
func pass_door() -> void:
	assert(door_underfoot(), "No door under the player")
	if is_inside():
		player.position = _tile_centre(_building_inside.door_tile() + Vector2i.DOWN)
		_building_inside = null
		return
	_building_inside = world.building_at(player.tile())
	if _building_inside.interior == null:
		var map_path: String = BuildingTypes.TYPES[_building_inside.type]["interior_map"]
		_building_inside.interior = InteriorLoader.load_interior(map_path)
	player.position = _tile_centre(_building_inside.interior.entry_tile())


## The nearest bed the player can reach, or null. Their own tile counts.
func bed_in_reach() -> WorldObject:
	return Interaction.nearest_in_reach(
		self, func(object: WorldObject) -> bool: return object.is_bed()
	)


## Sleeps until the next morning (WAKE_UP_MINUTE), makes the bed home and fills energy and
## health as far as the bed does (and a debuff still allows).
func sleep_in(bed: WorldObject) -> void:
	assert(bed.is_bed(), "Not a bed: %s" % bed.type)
	clock.advance(clock.minutes_until(WAKE_UP_MINUTE))
	is_up_too_late = false
	_lie_in(bed)
	player.home_map = current_map
	player.home_bed = bed.pos
	var fill := energy_rules.sleep_fill(bed.type)
	player.energy = minf(maxf(player.energy, fill), energy_cap())
	player.health = maxf(player.health, fill)


## A bed set up while the home has no bed (the bedroll that was home was taken down) becomes the
## home: the bed follows the bedroll to where it is set up again.
func make_home_if_bedless(bed: WorldObject) -> void:
	if bed.is_bed() and _home_bed() == null:
		player.home_map = current_map
		player.home_bed = bed.pos


## The weather the player sees: at their tile, or outside the door of the house they are in
## (they would see it through its windows). A forced condition (see Console) replaces the
## simulated one.
func current_weather() -> WeatherSample:
	var sample := weather.at(_outdoor_tile(), clock.day, clock.minute_of_day)
	return sample if weather_override == &"" else weather.forced(sample, weather_override)


## The snow on the ground where the player is (or outside the house they are in), 0 to 1, as
## of the start of the hour: the look of the world only follows it hour by hour.
func current_snow_cover() -> float:
	return snow_cover.at(_outdoor_tile(), clock.day, _hour_start())


## The frost on the ground where the player is, 0 to 1, as of the start of the hour.
func current_frost() -> float:
	return snow_cover.frost_at(weather.at(_outdoor_tile(), clock.day, _hour_start()).temperature)


## The tile whose weather the player sees: theirs, or outside the door of the house they are in.
func _outdoor_tile() -> Vector2i:
	return _building_inside.door_tile() if is_inside() else player.tile()


func _hour_start() -> int:
	return clock.minute_of_day / GameClock.MINUTES_PER_HOUR * GameClock.MINUTES_PER_HOUR


## The most energy the player can have now.
func energy_cap() -> float:
	return energy_rules.debuff_energy_max() if player.is_debuffed else PlayerState.MAX_ENERGY


## Whether the tile the player faces is the door of a building (which they can't ride through);
## the bell frame has none to go through.
func is_door_ahead() -> bool:
	var building := world.building_at(player.facing_tile())
	return (
		not is_inside()
		and building != null
		and building.door_tile() == player.facing_tile()
		and building.has_inside()
	)


## How fast the player walks, as a fraction of full speed: the slowest of what low energy and
## a debuff allow. On horseback it is the horse's pace, which nothing slows.
func walk_speed_factor() -> float:
	if player.horse != null:
		var pace := "ride_trot_factor" if is_trotting() else "ride_walk_factor"
		return livestock.rules.general(pace)
	var factor := energy_rules.walk_factor(player.energy)
	if player.is_debuffed:
		factor = minf(factor, energy_rules.debuff_walk_factor())
	return factor


## Walks the player on the map they are on (see PlayerState.move), or rides the horse they are on.
## Outdoors, each tile they step onto wears a little towards a desire path.
func walk(direction: Vector2, delta: float, speed_factor := 1.0) -> void:
	var tile_before := player.tile()
	player.move(current_map, direction, delta, speed_factor, cheats.is_noclip)
	_moving_seconds = _moving_seconds + delta if direction != Vector2.ZERO else 0.0
	# A noclip walk (through trees, rocks and walls) leaves no path.
	if not is_inside() and not cheats.is_noclip and player.tile() != tile_before:
		world.wear_tile(player.tile())


## Puts a player who stands where they don't fit (noclip just turned off in a lake, a rock or a
## house's walls) on the middle of the nearest tile, within `reach` tiles, where they fit and no
## part of them is on a building (its door would take them inside), with the horse they ride. One
## lying in a bed stays: they get out of it as they move. Returns whether they now fit.
func put_player_on_free_ground(reach := 12) -> bool:
	if player.bed_lying_in != null or PlayerState.can_stand_at(current_map, player.position):
		return true
	var here := player.tile()
	var nearest := Vector2.INF
	for y in range(-reach, reach + 1):
		for x in range(-reach, reach + 1):
			var centre := Vector2(here + Vector2i(x, y)) + Vector2(0.5, 0.5)
			var is_nearer := (
				centre.distance_to(player.position) < nearest.distance_to(player.position)
			)
			if is_nearer and _is_free_ground_for_player(centre):
				nearest = centre
	if nearest == Vector2.INF:
		return false
	player.position = nearest
	if player.horse != null:
		player.horse.position = nearest
	return true


func _is_free_ground_for_player(feet: Vector2) -> bool:
	return (
		PlayerState.can_stand_at(current_map, feet)
		and not PlayerState.touches_building(current_map, feet)
	)


## Whether the player rides fast enough for the horse to trot (see data/livestock.cfg).
func is_trotting() -> bool:
	return player.horse != null and _moving_seconds >= livestock.rules.general("trot_after_seconds")


## Gets on a saddled horse: the player sits on it where it stands, facing its way, and it goes where
## they ride until they get off (see `dismount`).
func mount(horse: FarmAnimal) -> void:
	assert(horse.is_saddled and player.horse == null, "Not a horse to get on")
	player.horse = horse
	horse.is_ridden = true
	player.bed_lying_in = null
	player.position = horse.position
	player.facing = Vector2i.RIGHT if horse.facing > 0.0 else Vector2i.LEFT
	_moving_seconds = 0.0


## Gets off the horse onto free ground beside it (see `_dismount_spot`); the horse stays where it is
## and goes about its day again. Returns false, and the player stays on, if there is no room.
func dismount() -> bool:
	var spot := _dismount_spot()
	if spot == Vector2.INF:
		return false
	player.position = spot
	_leave_horse()
	return true


## The horse stays where it is, and the player is no longer on it (wherever they are put next).
func _leave_horse() -> void:
	if player.horse == null:
		return
	player.horse.is_ridden = false
	livestock.stand_still(player.horse)
	player.horse = null


## Where getting off the horse puts the player: the middle of a tile near it, within
## DISMOUNT_REACH, where they stand free (never in the water, a wall or a building). Not on the
## horse's own tile, and best at its side: a tile along its length (to the left or right, as it
## is drawn standing) counts a tile further off. Vector2.INF if there is none.
func _dismount_spot() -> Vector2:
	var here := player.tile()
	var nearest := Vector2.INF
	var nearest_cost := INF
	for y in range(DISMOUNT_REACH, -DISMOUNT_REACH - 1, -1):
		for x in range(-DISMOUNT_REACH, DISMOUNT_REACH + 1):
			var centre := Vector2(here + Vector2i(x, y)) + Vector2(0.5, 0.5)
			var cost := centre.distance_to(player.position) + absi(x)
			var is_cheaper := cost < nearest_cost and Vector2i(x, y) != Vector2i.ZERO
			if is_cheaper and _is_free_ground_for_player(centre):
				nearest = centre
				nearest_cost = cost
	return nearest


## Eats one of the held food, on any map: it restores energy up to the cap. Does nothing, and
## returns false, unless the held item is food and the energy is below the cap.
func eat_held() -> bool:
	var food := player.inventory.held_item()
	if not energy_rules.is_food(food) or player.energy >= energy_cap():
		return false
	player.inventory.remove(food, 1)
	player.energy = minf(player.energy + energy_rules.food_restore(food), energy_cap())
	return true


func is_out_of_energy() -> bool:
	return player.energy <= 0.0


## Lets time pass while the player is awake. Reaching LATE_NIGHT_MINUTE means they have stayed
## up too late (`is_up_too_late`).
func pass_awake_time(minutes: int) -> void:
	if minutes >= clock.minutes_until(LATE_NIGHT_MINUTE):
		is_up_too_late = true
	clock.advance(minutes)


## The player passes out: they sleep until the next morning (WAKE_UP_MINUTE) but at least
## PASS_OUT_MINUTES, and wake in the home bed with the debuff of that day (it ends at the next
## new day) and no items lost. Returns how many minutes they slept.
func pass_out() -> int:
	var minutes := maxi(clock.minutes_until(WAKE_UP_MINUTE), PASS_OUT_MINUTES)
	clock.advance(minutes)
	is_up_too_late = false
	go_to_home_bed()
	player.is_debuffed = true
	player.energy = energy_rules.debuff_energy_max()
	if not cheats.is_god:
		player.health = energy_rules.debuff_health()
	return minutes


## Puts the player in their home bed, on its map (the world or the inside of a house): lying in
## its middle until they move. With no bed at the home (taken down, or something else on its
## tile) they stand at the world's start point, where a new game begins, and that is home until a
## bed is set up or they sleep in one (decided by the user, 2026-11-09). If something now
## stands on that spot they are put on the nearest free ground.
func go_to_home_bed() -> void:
	_leave_horse()
	_building_inside = _building_with_interior(player.home_map)
	var bed := _home_bed()
	if bed != null:
		_lie_in(bed)
		return
	_building_inside = null
	player.home_map = world
	player.home_bed = CampSite.spawn_of_seed(world.world_seed)
	player.position = _tile_centre(player.home_bed)
	player.bed_lying_in = null
	put_player_on_free_ground()


## What taking a building down gives, item id to count: half of what it cost, rounded down
## (nothing with the cost cheat on, which built it for nothing).
func refund_of_building(building: Building) -> Dictionary:
	var refund := {}
	if cheats.is_cost_off:
		return refund
	var costs: Dictionary = building.type_data()["costs"]
	for item: StringName in costs:
		if costs[item] / 2 > 0:
			refund[item] = costs[item] / 2
	return refund


## Why a building can't be taken down now, or "" if it can: the player is inside, or something
## the player put in it is still there (a thing they placed, or what a chest or station holds).
## The furniture the house came with, empty, goes with it.
func why_not_take_down(building: Building) -> String:
	if is_inside():
		return "You can't take a house down from inside."
	if building.interior == null:
		return ""
	var own_furniture := InteriorLoader.load_interior(
		BuildingTypes.TYPES[building.type]["interior_map"]
	)
	var tool_use := ToolUse.new(self)
	for object in building.interior.objects():
		if not object.type_data().has("drops"):
			continue
		var own := own_furniture.object_at(object.pos)
		var is_own := own != null and own.type == object.type
		if not is_own or not tool_use.items_held_by(object).is_empty():
			return "Take out what you put in it first."
	return ""


## Takes a building down: half its materials lie in front of its door. Not while
## `why_not_take_down` has a reason. A player whose home bed was in it has the camp's
## sleeping bag for home again (if the bag is gone they wake standing on its spot, as with
## any missing bed). Returns whether it was taken down.
func take_down_building(building: Building) -> bool:
	if why_not_take_down(building) != "":
		return false
	if player.home_map == building.interior:
		player.home_map = world
		player.home_bed = CampSite.sleeping_bag_of_seed(world.world_seed)
	world.remove_building(building)
	world.drop_items(building.door_tile() + Vector2i.DOWN, refund_of_building(building))
	return true


## Puts the player on a tile of the world, out of the house they are in (and off the horse they
## ride, which stays).
func teleport_to(tile: Vector2i) -> void:
	_leave_horse()
	_building_inside = null
	player.position = _tile_centre(tile)
	player.bed_lying_in = null


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


## Pulls the items on the ground near the player towards them and picks up those that
## arrive. What the inventory has no room for stays on the ground, and so do all piles of an
## item while it has no room at all. Does nothing inside a building or on horseback. Only the
## piles in the player's chunk and next to it are looked at: a pile out of reach has no business
## being settled or released here, and the player cannot get further than that in a frame.
func collect_ground_items(delta: float) -> void:
	if is_inside():
		return
	var player_chunk := Chunk.world_to_chunk(player.tile())
	for ground_item in world.ground_items.in_chunks_around(player_chunk, 1):
		ground_item.settle_seconds = maxf(ground_item.settle_seconds - delta, 0.0)
		if ground_item.position.distance_to(player.position) > PULL_RADIUS:
			ground_item.is_dropped_by_player = false
	# On horseback nothing is picked up: only the inventory and eating are possible.
	if player.horse != null:
		return
	for ground_item in world.ground_items.near(player.position, PULL_RADIUS):
		if ground_item.settle_seconds > 0.0 or ground_item.is_dropped_by_player:
			continue
		if not player.inventory.can_add({ground_item.item: 1}):
			continue
		var to_player := player.position - ground_item.position
		if to_player.length() > maxf(PICKUP_RADIUS, PULL_SPEED * delta):
			world.ground_items.move(
				ground_item, ground_item.position + to_player.normalized() * PULL_SPEED * delta
			)
			continue
		ground_item.count = player.inventory.add(ground_item.item, ground_item.count)
		if ground_item.count == 0:
			world.ground_items.remove(ground_item)


## Puts the stack in inventory slot `slot` on the ground in front of the player, as drops of
## the world lie (see `World.drop_items`); the player picks it up again by walking away and back.
## Does nothing inside a building (nothing lies on the ground there). Returns whether it did.
func drop_from_inventory(slot: int) -> bool:
	var stack := player.inventory.slots[slot]
	if is_inside() or stack.is_empty():
		return false
	player.inventory.slots[slot] = {}
	player.inventory.changed.emit()
	for pile in world.drop_items(player.facing_tile(), {stack["item"]: stack["count"]}):
		pile.is_dropped_by_player = true
	return true


## Maps are saved as references, never as copies: `{"kind": "world"}`, or
## `{"kind": "interior", "building": [x, y]}` for the interior of the building with that
## origin. So the current map and the home map stay the very objects they point at.
func to_dict() -> Dictionary:
	var player_data := player.to_dict()
	# A game saved on horseback loads with the player standing beside the horse (or, with no room
	# there, on its spot).
	var spot := Vector2.INF if player.horse == null else _dismount_spot()
	if spot != Vector2.INF:
		player_data["position"] = SaveCodec.float_vector_to_json(spot)
	return {
		"world": world.to_dict(),
		"clock": clock.to_dict(),
		"player": player_data,
		"livestock": livestock.to_array(),
		"npcs": npcs.to_array(),
		"current_map": _map_to_ref(current_map),
		"home_map": _map_to_ref(player.home_map),
	}


## The chunks of the restored world are not loaded yet: whoever shows it streams them in.
static func from_dict(data: Dictionary) -> GameState:
	var state := GameState.new(GameClock.from_dict(data["clock"]))
	state.world = World.from_dict(data["world"], state.clock)
	state.weather = Weather.new(state.world.world_seed, state.sun)
	state.snow_cover = SnowCover.new(state.weather)
	state.player = PlayerState.from_dict(data["player"], state._map_from_ref(data["home_map"]))
	state.livestock.load_array(data["livestock"])
	state.npcs.load_array(data["npcs"])
	state._building_inside = state._building_of_ref(data["current_map"])
	# No sleep wakes between 01:00 and 06:30, so a game saved then was quit by a player who
	# stayed up: they still pass out (`is_up_too_late` itself is not saved).
	var minute := state.clock.minute_of_day
	state.is_up_too_late = minute >= LATE_NIGHT_MINUTE and minute < WAKE_UP_MINUTE
	return state


func _map_to_ref(map: GameMap) -> Dictionary:
	if map == world:
		return {"kind": "world"}
	var building := _building_with_interior(map)
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


func _on_new_day(_day: int) -> void:
	# The clock has already counted the new day, so the night that just ended is the day before:
	# `NightUpkeep.pass_night` works from the weather of `clock.day - 1`.
	player.is_debuffed = false
	# A stump or sapling doesn't grow into a tree under the player's feet.
	var occupied: Array[Vector2i] = []
	if not is_inside():
		occupied.append(player.tile())
	NightUpkeep.pass_night(world, occupied, weather)


## The bed object of the home bed, or null if there is none at that tile now (the bedroll was
## taken down, perhaps for something else to stand there). A bed in the world may be in a chunk
## that is not loaded: that chunk is generated for the look and dropped again, as in the
## console's `tp`.
func _home_bed() -> WorldObject:
	var coords := Chunk.world_to_chunk(player.home_bed)
	var object: WorldObject
	if player.home_map != world or world.is_chunk_loaded(coords):
		object = player.home_map.object_at(player.home_bed)
	else:
		world.add_chunk(WorldGenerator.new(world.world_seed).generate_chunk(coords))
		object = world.object_at(player.home_bed)
		world.remove_chunk(coords)
	return object if object != null and object.is_bed() else null


## The building whose interior this is, or null for the world.
func _building_with_interior(map: GameMap) -> Building:
	for building in world.buildings():
		if building.interior == map:
			return building
	return null


## The middle of the bed's footprint, in tiles: where the player lies.
static func _bed_middle(bed: WorldObject) -> Vector2:
	var footprint: Vector2i = bed.type_data()["footprint"]
	return Vector2(bed.pos) + Vector2(footprint) / 2.0


## Puts the player in the middle of the bed, lying under its blanket until they move.
func _lie_in(bed: WorldObject) -> void:
	player.position = _bed_middle(bed)
	player.bed_lying_in = bed


func _tile_centre(tile: Vector2i) -> Vector2:
	return Vector2(tile) + Vector2(0.5, 0.5)
