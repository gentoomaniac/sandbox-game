class_name PlayerRest
extends RefCounted
## Where the player lives, sleeps and wakes: the doors between the world and the houses, the bed
## that is home, sleeping, passing out and the time they take, and standing in the world again at
## a chosen tile. It keeps nothing: every function is given the game.

## Sleeping and passing out wake the player the next time the clock shows this.
const WAKE_UP_MINUTE := 6 * GameClock.MINUTES_PER_HOUR + 30
## Passing out sleeps at least this long, even when the morning comes sooner.
const PASS_OUT_MINUTES := 10 * GameClock.MINUTES_PER_HOUR
## The sleep fills of data/energy.cfg are in percent of the energy and health bars.
const PERCENT := 100.0
## A player who is still awake when the clock shows this has stayed up too late and passes out.
const LATE_NIGHT_MINUTE := 1 * GameClock.MINUTES_PER_HOUR


## Whether the player stands on a tile that leads to another map: the door of a building in
## the world, or the exit of the interior they are in. Never on horseback: a horse that stood in a
## doorway when they got on it is ridden out of it, not into the house.
static func door_underfoot(state: GameState) -> bool:
	if state.player.horse != null:
		return false
	var tile := state.player.tile()
	if state.is_inside():
		return tile == state.building_inside.interior.exit_tile
	var building := state.world.building_at(tile)
	return building != null and building.door_tile() == tile and building.has_inside()


## Whether the tile the player faces is the door of a building (which they can't ride through);
## the bell frame has none to go through.
static func is_door_ahead(state: GameState) -> bool:
	var building := state.world.building_at(state.player.facing_tile())
	return (
		not state.is_inside()
		and building != null
		and building.door_tile() == state.player.facing_tile()
		and building.has_inside()
	)


## Takes the player through the door under their feet: into the building (making its interior
## the first time), or out to the tile in front of its door.
static func pass_door(state: GameState) -> void:
	assert(door_underfoot(state), "No door under the player")
	if state.is_inside():
		state.player.position = _tile_centre(state.building_inside.door_tile() + Vector2i.DOWN)
		state.building_inside = null
		return
	state.building_inside = state.world.building_at(state.player.tile())
	state.player.position = _tile_centre(state.building_inside.inside().entry_tile())


## The nearest bed the player can reach, or null. Their own tile counts.
static func bed_in_reach(state: GameState) -> WorldObject:
	return Interaction.nearest_in_reach(
		state, func(object: WorldObject) -> bool: return object.is_bed()
	)


## Sleeps until the next morning (WAKE_UP_MINUTE), makes the bed home and fills energy and
## health as far as the bed does (and a debuff still allows).
static func sleep_in(state: GameState, bed: WorldObject) -> void:
	assert(bed.is_bed(), "Not a bed: %s" % bed.type)
	_pass_time(state, state.clock.minutes_until(WAKE_UP_MINUTE), false)
	_wake_up_in(state, bed)


## `sleep_in` spread over frames (see Simulation `skip_over_frames`): `await` it.
static func sleep_in_over_frames(state: GameState, bed: WorldObject, next_frame: Callable) -> void:
	assert(bed.is_bed(), "Not a bed: %s" % bed.type)
	await _skip_time_over_frames(state, state.clock.minutes_until(WAKE_UP_MINUTE), next_frame)
	_wake_up_in(state, bed)


## A bed set up while the home has no bed (the bedroll that was home was taken down) becomes the
## home: the bed follows the bedroll to where it is set up again.
static func make_home_if_bedless(state: GameState, bed: WorldObject) -> void:
	if bed.is_bed() and _home_bed(state) == null:
		state.player.home_map = state.current_map
		state.player.home_bed = bed.pos


## Lets time pass while the player is awake. Reaching LATE_NIGHT_MINUTE means they have stayed
## up too late (`is_up_too_late`), unless the `nolate` cheat is on.
static func pass_awake_time(state: GameState, minutes: int) -> void:
	if not state.cheats.is_late_off and minutes >= state.clock.minutes_until(LATE_NIGHT_MINUTE):
		state.is_up_too_late = true
	_pass_time(state, minutes, true)


## The player passes out: they sleep until the next morning (WAKE_UP_MINUTE) but at least
## PASS_OUT_MINUTES, and wake in the home bed with the debuff of that day (it ends at the next
## new day) and no items lost. Returns how many minutes they slept.
static func pass_out(state: GameState) -> int:
	var minutes := _pass_out_minutes(state)
	_pass_time(state, minutes, false)
	_wake_up_after_pass_out(state)
	return minutes


## `pass_out` spread over frames (see Simulation `skip_over_frames`): `await` it.
static func pass_out_over_frames(state: GameState, next_frame: Callable) -> int:
	var minutes := _pass_out_minutes(state)
	await _skip_time_over_frames(state, minutes, next_frame)
	_wake_up_after_pass_out(state)
	return minutes


## Puts the player in their home bed, on its map (the world or the inside of a house): lying in
## its middle until they move. With no bed at the home (taken down, or something else on its
## tile) they stand at the world's start point, where a new game begins, and that is home until a
## bed is set up or they sleep in one (decided by the user, 2026-11-09). If something now
## stands on that spot they are put on the nearest free ground.
static func go_to_home_bed(state: GameState) -> void:
	var player := state.player
	state.travel.leave_horse(state)
	state.building_inside = state.building_with_interior(player.home_map)
	var bed := _home_bed(state)
	if bed != null:
		_lie_in(state, bed)
		return
	state.building_inside = null
	player.home_map = state.world
	player.home_bed = CampSite.spawn_of_seed(state.world.world_seed)
	player.position = _tile_centre(player.home_bed)
	player.bed_lying_in = null
	state.travel.put_player_on_free_ground(state)


## Puts the player on a tile of the world, out of the house they are in (and off the horse they
## ride, which stays).
static func teleport_to(state: GameState, tile: Vector2i) -> void:
	state.travel.leave_horse(state)
	state.building_inside = null
	state.player.position = _tile_centre(tile)
	state.player.bed_lying_in = null
	state.explored.see(tile)


static func _wake_up_in(state: GameState, bed: WorldObject) -> void:
	var player := state.player
	state.is_up_too_late = false
	_lie_in(state, bed)
	player.home_map = state.current_map
	player.home_bed = bed.pos
	var fill := state.energy_rules.sleep_fill(bed.type)
	var energy_fill := fill * player.attributes.max_energy() / PERCENT
	player.energy = minf(maxf(player.energy, energy_fill), state.energy_cap())
	player.health = maxf(player.health, fill * player.attributes.max_health() / PERCENT)


static func _pass_out_minutes(state: GameState) -> int:
	return maxi(state.clock.minutes_until(WAKE_UP_MINUTE), PASS_OUT_MINUTES)


static func _wake_up_after_pass_out(state: GameState) -> void:
	state.is_up_too_late = false
	go_to_home_bed(state)
	state.player.is_debuffed = true
	state.player.energy = state.energy_cap()
	if not state.cheats.is_god:
		state.player.health = state.energy_rules.debuff_health()


## The player lives through `minutes`, awake (played: the frames move the animals) or asleep
## (skipped: they are made up for): a new day ends the debuff of the last one. The console's
## `skip` does not come this way, it leaves the player alone.
static func _pass_time(state: GameState, minutes: int, is_played: bool) -> void:
	var day_before := state.clock.day
	if is_played:
		state.simulation.advance(minutes)
	else:
		_put_lantern_out_for_sleep(state)
		state.simulation.skip(minutes)
	_end_debuff_on_new_day(state, day_before)


static func _skip_time_over_frames(state: GameState, minutes: int, next_frame: Callable) -> void:
	var day_before := state.clock.day
	_put_lantern_out_for_sleep(state)
	await state.simulation.skip_over_frames(minutes, next_frame)
	_end_debuff_on_new_day(state, day_before)


## Going to bed, or passing out, puts the lantern out: the candle never burns unattended.
static func _put_lantern_out_for_sleep(state: GameState) -> void:
	state.player.is_lantern_lit = false


static func _end_debuff_on_new_day(state: GameState, day_before: int) -> void:
	if state.clock.day != day_before:
		state.player.is_debuffed = false


## The bed object of the home bed, or null if there is none at that tile now (the bedroll was
## taken down, perhaps for something else to stand there). A bed in the world may be in a chunk
## that is not loaded: that chunk is generated for the look and dropped again, as in the
## console's `tp`.
static func _home_bed(state: GameState) -> WorldObject:
	var world := state.world
	var player := state.player
	var coords := Chunk.world_to_chunk(player.home_bed)
	var object: WorldObject
	if player.home_map != world or world.is_chunk_loaded(coords):
		object = player.home_map.object_at(player.home_bed)
	else:
		world.add_chunk(WorldGenerator.new(world.world_seed).generate_chunk(coords))
		object = world.object_at(player.home_bed)
		world.remove_chunk(coords)
	return object if object != null and object.is_bed() else null


## Puts the player in the middle of the bed, lying under its blanket until they move.
static func _lie_in(state: GameState, bed: WorldObject) -> void:
	var footprint: Vector2i = bed.type_data()["footprint"]
	state.player.position = Vector2(bed.pos) + Vector2(footprint) / 2.0
	state.player.bed_lying_in = bed


static func _tile_centre(tile: Vector2i) -> Vector2:
	return Vector2(tile) + Vector2(0.5, 0.5)
