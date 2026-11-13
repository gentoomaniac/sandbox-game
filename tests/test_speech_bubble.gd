extends GutTest
## The bubble over a villager (SpeechBubble): the line in a plate that wraps when long, put over
## the villager's head as the camera shows them, popping up, fading and gone after its time.

const SECONDS := 5.0

var _bubble: SpeechBubble
var _antje: Npc


func before_each() -> void:
	_bubble = SpeechBubble.new()
	add_child_autoqfree(_bubble)
	_antje = Npc.create_villager("antje", Vector2(10, 10), VillagerRules.default_rules())


## The UI position of a point of the world: the point itself.
func _to_ui(point: Vector2) -> Vector2:
	return point


func _plate() -> PanelContainer:
	return _bubble.get_child(0).get_child(0)


func test_a_bubble_shows_nothing_until_a_line_is_said() -> void:
	assert_false(_bubble.is_showing())
	assert_eq(_bubble.text(), "")
	_bubble.show_line(_antje, "Rain again.", SECONDS)
	assert_true(_bubble.is_showing())
	assert_eq(_bubble.speaker(), _antje)
	assert_eq(_bubble.text(), "Rain again.")


func test_the_tail_tip_is_over_the_head_of_the_villager() -> void:
	_bubble.show_line(_antje, "Rain again.", SECONDS)
	_bubble.update(1.0, _to_ui)
	var root: Control = _bubble.get_child(0)
	var head := Vector2(10, 10) * TerrainTileset.TILE_SIZE - Vector2(0, SpeechBubble.ABOVE_FEET)
	assert_eq(root.position, head)
	var plate := _plate()
	assert_lt(plate.position.y + plate.size.y, 0.0, "the plate is over the tip")
	assert_almost_eq(plate.position.x + plate.size.x / 2.0, 0.0, 1.0)


func test_a_long_line_wraps_into_a_taller_plate() -> void:
	_bubble.show_line(_antje, "Hm.", SECONDS)
	_bubble.update(1.0, _to_ui)
	var short_height := _plate().size.y
	var short_width := _plate().size.x
	_bubble.show_line(
		_antje, "The ditches will be full by noon, and the cows stand in the wet.", SECONDS
	)
	_bubble.update(1.0, _to_ui)
	assert_lte(_plate().size.x, SpeechBubble.MAX_TEXT_WIDTH + 2.0 * SpeechBubble.PADDING.x + 2.0)
	assert_gt(_plate().size.x, short_width)
	assert_gt(_plate().size.y, short_height)


func test_the_bubble_pops_up_and_fades_out_at_the_end() -> void:
	_bubble.show_line(_antje, "Rain again.", SECONDS)
	_bubble.update(0.0, _to_ui)
	var root: Control = _bubble.get_child(0)
	var settled_y := Vector2(10, 10).y * TerrainTileset.TILE_SIZE - SpeechBubble.ABOVE_FEET
	assert_eq(root.position.y, settled_y + ThoughtBubble.POP_DROP)
	_bubble.update(1.0, _to_ui)
	assert_eq(root.position.y, settled_y)
	assert_eq(root.modulate.a, 1.0)
	_bubble.update(SECONDS - 1.0 - 0.1, _to_ui)
	assert_between(root.modulate.a, 0.1, 0.9)


func test_the_bubble_is_gone_after_its_time() -> void:
	_bubble.show_line(_antje, "Rain again.", SECONDS)
	_bubble.update(SECONDS + 0.1, _to_ui)
	assert_false(_bubble.is_showing())
	assert_null(_bubble.speaker())
	assert_false(_bubble.get_child(0).visible)


func test_it_follows_the_villager() -> void:
	_bubble.show_line(_antje, "Rain again.", SECONDS)
	_bubble.update(1.0, _to_ui)
	var before: Vector2 = _bubble.get_child(0).position
	_antje.position += Vector2(2, 0)
	_bubble.update(0.1, _to_ui)
	assert_eq(_bubble.get_child(0).position.x - before.x, 2.0 * TerrainTileset.TILE_SIZE)
