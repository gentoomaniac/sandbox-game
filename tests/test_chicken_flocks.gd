extends GutTest
## Which chickens are one flock (task 204): those within the distance of one another or of a coop,
## one after the other.


func test_chickens_near_one_another_are_a_flock_and_a_far_one_is_another() -> void:
	var chickens: Array[Vector2] = [Vector2(0, 0), Vector2(5, 0), Vector2(10, 0), Vector2(50, 0)]

	var flocks := ChickenFlocks.groups(chickens, [] as Array[Vector2], 6.0)

	assert_eq(flocks, [PackedInt32Array([0, 1, 2]), PackedInt32Array([3])])


func test_a_coop_between_two_far_chickens_makes_them_one_flock() -> void:
	var chickens: Array[Vector2] = [Vector2(0, 0), Vector2(10, 0)]
	var coops: Array[Vector2] = [Vector2(5, 0)]

	assert_eq(ChickenFlocks.groups(chickens, coops, 6.0), [PackedInt32Array([0, 1])])


func test_a_coop_with_no_chicken_near_is_no_flock() -> void:
	var chickens: Array[Vector2] = []
	var coops: Array[Vector2] = [Vector2(5, 0)]

	assert_eq(ChickenFlocks.groups(chickens, coops, 6.0), [] as Array[PackedInt32Array])
