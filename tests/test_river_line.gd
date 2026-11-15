extends GutTest
## The river's centre line: it winds, it is continuous, and it has a width that changes.

const SEED := 42
const COLUMNS := Vector2i(-300, 1000)


func test_the_line_is_the_same_for_the_same_seed_and_differs_between_seeds() -> void:
	var river := RiverLine.new(SEED)
	assert_eq(river.line_y(123.0), RiverLine.new(SEED).line_y(123.0))
	assert_ne(river.line_y(123.0), RiverLine.new(SEED + 1).line_y(123.0))


func test_the_line_stays_within_its_swing_and_never_jumps() -> void:
	var river := RiverLine.new(SEED)
	var swing := RiverLine.MEANDER_AMPLITUDE + RiverLine.BEND_AMPLITUDE
	for x in range(COLUMNS.x, COLUMNS.y):
		assert_lt(absf(river.line_y(x)), swing)
		assert_lt(absf(river.line_y(x + 1) - river.line_y(x)), 1.5, "a step at %d" % x)


func test_the_line_has_small_bends_besides_the_big_swing() -> void:
	var river := RiverLine.new(SEED)
	var turns := 0
	var going_south := river.line_y(COLUMNS.x + 1) > river.line_y(COLUMNS.x)
	for x in range(COLUMNS.x, COLUMNS.y, 5):
		var is_south := river.line_y(x + 5) > river.line_y(x)
		if is_south != going_south:
			turns += 1
			going_south = is_south
	assert_gt(turns, 12, "the line turns over %d columns" % (COLUMNS.y - COLUMNS.x))


func test_the_river_is_wider_in_some_places_than_in_others() -> void:
	var river := RiverLine.new(SEED)
	var widest := 0.0
	var narrowest := INF
	for x in range(COLUMNS.x, COLUMNS.y):
		widest = maxf(widest, river.widening_at(x))
		narrowest = minf(narrowest, river.widening_at(x))
	assert_gt(widest - narrowest, RiverLine.MAX_WIDENING * 0.6, "the width changes")
	assert_between(narrowest, 0.0, RiverLine.MAX_WIDENING)
	assert_between(widest, 0.0, RiverLine.MAX_WIDENING)
