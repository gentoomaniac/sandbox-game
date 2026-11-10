class_name Coop
extends RefCounted
## The chicken coop of the farm yard (task 122; the numbers are `[coop]` in data/livestock.cfg):
## where the hens go to sleep, how many fit, and the eggs in its nests. A coop is a Building of the
## type `[coop] building`; its nests are the hay piles of its inside, each with the eggs in it as
## `eggs` in the object's state, and a hen that is in it stands on a tile of its footprint. Plain
## functions: Livestock decides when a hen goes in and out.

## What a nest is: the straw of the coop's inside.
const NEST_TYPE := WorldObjectTypes.HAY_PILE
## Why a hen walks to a coop (`goal_need` of a FarmAnimal).
const ROOST := &"roost"


## The building as a coop, or null if it is none (or there is no building).
static func of(building: Building, yard: YardRules) -> Building:
	return building if building != null and building.type == yard.coop("building") else null


## The coop whose inside the tile is, or null: a tile of its footprint but its door's, which is
## walked on and so is no inside.
static func housing(world: World, tile: Vector2i, yard: YardRules) -> Building:
	var building := of(world.building_at(tile), yard)
	return building if building != null and is_inside(world, tile, building) else null


## Whether the tile is inside the building: a tile of its footprint but its door's.
static func is_inside(world: World, tile: Vector2i, building: Building) -> bool:
	return world.building_at(tile) == building and tile != building.door_tile()


## Whether the building is a coop.
static func is_coop(building: Building, yard: YardRules) -> bool:
	return of(building, yard) != null


## The coop with a free roost nearest to the hen within `[coop] call_tiles` of the front of its
## door, that `is_reachable` (a Callable of the tile in front of the door) says she can get to, or
## null. `animals` are all the farm animals, to count who is in each or on her way, and `reserved`
## the roosts that are taken as well, by coop origin.
static func nearest_free(
	world: World,
	animals: Array[FarmAnimal],
	feet: Vector2,
	yard: YardRules,
	reserved: Dictionary,
	is_reachable: Callable
) -> Building:
	var nearest: Building = null
	var nearest_distance: float = yard.coop("call_tiles")
	for building in world.buildings():
		if not is_coop(building, yard):
			continue
		var front := door_front(building)
		var distance := front.distance_to(feet)
		if (
			distance <= nearest_distance
			and occupancy(world, building, animals, reserved) < yard.coop("roosts")
			and is_reachable.call(Vector2i(front.floor()))
		):
			nearest = building
			nearest_distance = distance
	return nearest


## Where a hen stands to go in: the middle of the tile in front of the door.
static func door_front(building: Building) -> Vector2:
	return Vector2(building.door_tile() + Vector2i.DOWN) + Vector2(0.5, 0.5)


## Where a hen is that is in the coop: the middle of its first tile.
static func roost_spot(building: Building) -> Vector2:
	return Vector2(building.origin) + Vector2(0.5, 0.5)


## How many hens are in the building now.
static func hens_in(world: World, building: Building, animals: Array[FarmAnimal]) -> int:
	var count := 0
	for animal in animals:
		if animal.species == LivestockRules.CHICKEN and is_inside(world, animal.tile(), building):
			count += 1
	return count


## How many roosts of the building are taken: the hens in it, those on their way to it, and the
## `reserved` ones.
static func occupancy(
	world: World, building: Building, animals: Array[FarmAnimal], reserved: Dictionary
) -> int:
	var count := hens_in(world, building, animals) + int(reserved.get(building.origin, 0))
	for animal in animals:
		var is_on_the_way := (
			animal.goal_need == ROOST
			and animal.goal_source == building.origin
			and animal.goal.is_finite()
			and not is_inside(world, animal.tile(), building)
		)
		if is_on_the_way:
			count += 1
	return count


## Whether a hen can go in: fewer hens are in the building than it has roosts.
static func has_room(
	world: World, building: Building, animals: Array[FarmAnimal], yard: YardRules
) -> bool:
	return hens_in(world, building, animals) < yard.coop("roosts")


## A hen lays an egg in a nest of the coop that has room, with the chance `egg_chance`; returns
## whether she did. The inside is made if nobody has been in yet.
static func lay_egg(building: Building, yard: YardRules, rng: RandomNumberGenerator) -> bool:
	if rng.randf() >= float(yard.coop("egg_chance")):
		return false
	for nest in nests(building):
		if eggs_in(nest) < int(yard.coop("nest_eggs")):
			nest.state["eggs"] = eggs_in(nest) + 1
			return true
	return false


## The nests of the coop.
static func nests(building: Building) -> Array[WorldObject]:
	var found: Array[WorldObject] = []
	for object in building.inside().objects():
		if object.type == NEST_TYPE:
			found.append(object)
	return found


static func eggs_in(nest: WorldObject) -> int:
	return int(nest.state.get("eggs", 0))


## Takes the eggs out of a nest; returns how many there were.
static func take_eggs(nest: WorldObject) -> int:
	var taken := eggs_in(nest)
	nest.state["eggs"] = 0
	return taken
