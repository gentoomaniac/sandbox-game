class_name ChickenFlocks
extends RefCounted
## Which chickens belong together (task 204): a flock is the chickens that stand within
## `[rooster] flock_tiles` of one another, one after the other, and of a coop: the hens of a coop
## are one flock with it, and loose chickens far from any coop another. Each flock has one rooster
## (see Livestock `spawn`). Plain geometry on points, so the save upgrade can use it on saved data.


## The flocks of the chickens at `chickens` (positions in tiles), each as the indices into it, in
## the order of the first chicken of each. A coop at one of `coops` links the chickens near it.
static func groups(
	chickens: Array[Vector2], coops: Array[Vector2], flock_tiles: float
) -> Array[PackedInt32Array]:
	var points: Array[Vector2] = []
	points.append_array(chickens)
	points.append_array(coops)
	# Each point leads to the first point of its flock.
	var leader := PackedInt32Array()
	for index in points.size():
		leader.append(index)
	for index in points.size():
		for other in index:
			if points[index].distance_to(points[other]) <= flock_tiles:
				var from := _leader_of(leader, index)
				var to := _leader_of(leader, other)
				leader[maxi(from, to)] = mini(from, to)
	var flocks: Dictionary[int, PackedInt32Array] = {}
	for index in chickens.size():
		var flock_leader := _leader_of(leader, index)
		var flock: PackedInt32Array = flocks.get(flock_leader, PackedInt32Array())
		flock.append(index)
		flocks[flock_leader] = flock
	var found: Array[PackedInt32Array] = []
	found.assign(flocks.values())
	return found


static func _leader_of(leader: PackedInt32Array, index: int) -> int:
	while leader[index] != index:
		index = leader[index]
	return index


## Where a rooster is wanted: the position of the first chicken of each flock that has none, given
## the `animals` (the chickens among them are the flocks') and the places of the `coops`.
static func spots_without_rooster(
	animals: Array[FarmAnimal], coops: Array[Vector2], flock_tiles: float
) -> Array[Vector2]:
	var chickens: Array[FarmAnimal] = []
	var positions: Array[Vector2] = []
	for animal in animals:
		if animal.species == LivestockRules.CHICKEN:
			chickens.append(animal)
			positions.append(animal.position)
	var spots: Array[Vector2] = []
	for flock in groups(positions, coops, flock_tiles):
		var has_rooster := false
		for index in flock:
			has_rooster = has_rooster or chickens[index].is_rooster()
		if not has_rooster:
			spots.append(positions[flock[0]])
	return spots
