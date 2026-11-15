extends ResourceCase
## The steps of a walker (#64): a print every step of the way it walks, to either side of its
## line and turned the way it goes, for the player and for a villager.

var _footprints: Footprints


func before_each() -> void:
	super.before_each()
	_footprints = _world.footprints
	_footprints.is_snowed_at = func(_tile: Vector2i) -> bool: return true
	_world.set_terrain(_tile, Tile.Terrain.GRASS)


func _ring_size(tile: Vector2i) -> int:
	var ring := _footprints.ring_of(Chunk.world_to_chunk(tile))
	return 0 if ring == null else ring.size


## A walker with no steps made yet walks one step's length to the middle of `tile`: leaves one
## print there. A little over the step, for what float sums leave out.
func _step_onto(tile: Vector2i, toes := Vector2.RIGHT) -> void:
	var to := Vector2(tile) + Vector2(0.5, 0.5)
	var step := FootprintRules.default_rules().step_tiles()
	_footprints.walk(_world, Footprints.Stride.new(), to - toes * step * 1.01, to)


func test_a_walker_leaves_a_print_every_step_along_the_way() -> void:
	var step := FootprintRules.default_rules().step_tiles()
	var stride := Footprints.Stride.new()
	var from := Vector2(_tile) + Vector2(0.1, 0.5)
	# Walked in small pieces, as frames are, over ten and a half steps.
	for piece in 105:
		var at := from + Vector2.RIGHT * piece * step / 10.0
		_footprints.walk(_world, stride, at, at + Vector2.RIGHT * step / 10.0)
	assert_eq(_ring_size(_tile), 10)
	var ring := _footprints.ring_of(Chunk.world_to_chunk(_tile))
	assert_almost_eq(ring.position[1].x - ring.position[0].x, step, 0.001)


func test_a_slower_walk_makes_the_same_prints_for_the_same_distance() -> void:
	var stride := Footprints.Stride.new()
	var from := Vector2(_tile) + Vector2(0.1, 0.5)
	_footprints.walk(_world, stride, from, from + Vector2.RIGHT * 0.1)
	assert_eq(_ring_size(_tile), 0, "less than a step")
	_footprints.walk(_world, stride, from, from + Vector2.RIGHT * 0.4)
	assert_eq(_ring_size(_tile), 1, "the pieces add up to a step")


func test_the_feet_alternate_to_either_side_of_the_line() -> void:
	var step := FootprintRules.default_rules().step_tiles()
	var stride := Footprints.Stride.new()
	var from := Vector2(_tile) + Vector2(0.0, 0.5)
	_footprints.walk(_world, stride, from, from + Vector2.RIGHT * step * 3.5)
	var ring := _footprints.ring_of(Chunk.world_to_chunk(_tile))
	assert_eq(ring.size, 3)
	assert_ne(ring.cell[0], ring.cell[1])
	assert_eq(ring.cell[0], ring.cell[2])
	var side := FootprintRules.default_rules().foot_side_tiles()
	# Walking east, the left foot is on the north side (smaller y).
	assert_almost_eq(ring.position[0].y, from.y - side, 0.001)
	assert_almost_eq(ring.position[1].y, from.y + side, 0.001)


func test_the_toes_follow_the_direction_of_the_walk_at_any_angle() -> void:
	var ring: Footprints.Ring
	var directions := [
		Vector2.RIGHT, Vector2.UP, Vector2(1.0, 1.0).normalized(), Vector2(3.0, -1.0).normalized()
	]
	for toes: Vector2 in directions:
		_step_onto(_tile, toes)
		ring = _footprints.ring_of(Chunk.world_to_chunk(_tile))
		var turned := Vector2.UP.rotated(ring.rotation[ring.next - 1])
		assert_almost_eq(turned.dot(toes), 1.0, 0.001, "toes %s" % toes)


func test_a_jump_is_not_steps() -> void:
	var from := Vector2(_tile) + Vector2(0.5, 0.5)
	_footprints.walk(_world, Footprints.Stride.new(), from, from + Vector2(50.0, 0.0))
	assert_eq(_ring_size(_tile), 0)


func test_a_print_lies_within_its_tile() -> void:
	for toes in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
		_step_onto(_tile, toes)
	var ring := _footprints.ring_of(Chunk.world_to_chunk(_tile))
	for slot in ring.size:
		assert_eq(Vector2i(ring.position[slot].floor()), _tile)


func test_the_player_leaves_prints_on_foot_and_not_on_horseback() -> void:
	_state.player.position = Vector2(_tile) + Vector2(0.5, 0.5)
	# Six frames of a quarter tile, a tile and a half: three steps.
	for _frame in 6:
		_state.walk(Vector2.RIGHT, 0.05)
	assert_eq(_ring_size(_tile), 3)
	_state.player.horse = FarmAnimal.new(LivestockRules.HORSE, &"bay", _state.player.position)
	for _frame in 6:
		_state.walk(Vector2.RIGHT, 0.05)
	assert_eq(_ring_size(_tile), 3, "the horse's hooves are for #65")


func test_a_villager_leaves_prints_by_the_way_it_walks() -> void:
	var step := FootprintRules.default_rules().step_tiles()
	var npc := Npc.new("Test", &"female", Appearance.new(), Vector2(_tile) + Vector2(0.5, 0.5))
	Npcs.leave_footprint(_world, npc, npc.position + Vector2.RIGHT * step * 0.5)
	assert_eq(_ring_size(_tile), 0, "half a step")
	Npcs.leave_footprint(_world, npc, npc.position + Vector2.RIGHT * step)
	assert_eq(_ring_size(_tile), 1)
	var ring := _footprints.ring_of(Chunk.world_to_chunk(_tile))
	assert_almost_eq(Vector2.UP.rotated(ring.rotation[0]).x, 1.0, 0.001, "east")
