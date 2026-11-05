class_name GameState
extends RefCounted
## Everything that makes up one game: the world, the clock and the player. Plain state with
## no rendering or input; scenes read it and send it actions such as `sleep_in`.

## How close (in tiles, diagonals included) the player must be to a bed to sleep in it.
const BED_REACH := 1

var world: World
var clock := GameClock.new()
var player := PlayerState.new()


## A new game: the player starts at a camp site near the world centre, with home set to its
## sleeping bag. The chunks around the camp are generated into the world here.
static func new_game(world_seed: int) -> GameState:
	var state := GameState.new()
	state.world = World.new(world_seed)
	var camp := CampSite.create(state.world, WorldGenerator.new(world_seed))
	state.player.position = Vector2(camp.spawn_pos) + Vector2(0.5, 0.5)
	state.player.home_bed = camp.sleeping_bag_pos
	return state


## The nearest bed the player can reach, or null. Their own tile counts.
func bed_in_reach() -> WorldObject:
	var player_tile := player.tile()
	var nearest: WorldObject = null
	for y in range(-BED_REACH, BED_REACH + 1):
		for x in range(-BED_REACH, BED_REACH + 1):
			var object := world.object_at(player_tile + Vector2i(x, y))
			if object == null or object.sleep_minutes() == 0:
				continue
			if nearest == null or _distance_to_player(object) < _distance_to_player(nearest):
				nearest = object
	return nearest


## Sleeps through the bed's fixed sleep time, and makes it home.
func sleep_in(bed: WorldObject) -> void:
	assert(bed.sleep_minutes() > 0, "Not a bed: %s" % bed.type)
	clock.advance(bed.sleep_minutes())
	player.home_bed = bed.pos


func _distance_to_player(object: WorldObject) -> float:
	return (Vector2(object.pos) + Vector2(0.5, 0.5)).distance_to(player.position)
