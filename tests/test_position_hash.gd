extends GutTest
## Pins values so that a change to the hash, which would move every generated tree, is
## noticed.


func test_known_values() -> void:
	assert_eq(PositionHash.of(Vector2i(0, 0)), 0)
	assert_eq(PositionHash.of(Vector2i(1, 0)), 2328593439)
	assert_eq(PositionHash.of(Vector2i(0, 1)), 1364076727)
	assert_eq(PositionHash.of(Vector2i(-5, 7)), 642244051)
	assert_eq(PositionHash.of(Vector2i(1000, -1024), 42), 3128576049)


func test_values_are_non_negative_32_bit() -> void:
	for x in range(-40, 40):
		var value := PositionHash.of(Vector2i(x, -x * 3), x)
		assert_between(value, 0, PositionHash.MASK)
