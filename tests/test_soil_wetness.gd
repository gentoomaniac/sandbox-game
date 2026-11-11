extends GutTest
## The looks of tilled soil by moisture and the shapes of a bed (see SoilWetness).


func test_soil_looks_a_step_darker_with_each_quarter_of_moisture() -> void:
	assert_eq(SoilWetness.look_for(0.0), 0)
	assert_eq(SoilWetness.look_for(0.24), 0)
	assert_eq(SoilWetness.look_for(0.25), 1)
	assert_eq(
		SoilWetness.look_for(CropRules.default_rules().farming("default_moisture")),
		1,
		"fresh soil is on the second step"
	)
	assert_eq(SoilWetness.look_for(0.49), 1)
	assert_eq(SoilWetness.look_for(0.5), 2)
	assert_eq(SoilWetness.look_for(0.74), 2)
	assert_eq(SoilWetness.look_for(0.75), 3)
	assert_eq(SoilWetness.look_for(1.0), SoilWetness.LOOKS - 1)


func test_a_bed_shape_keeps_a_corner_only_with_both_its_sides() -> void:
	var tilled := [Vector2i(1, 0), Vector2i(1, 1), Vector2i(-1, -1), Vector2i(0, 1)]
	var shape := SoilWetness.bed_shape(
		func(pos: Vector2i) -> bool: return pos in tilled, Vector2i.ZERO
	)
	assert_eq(shape, SoilWetness.EAST | SoilWetness.SOUTH | SoilWetness.SOUTH_EAST)


func test_the_atlas_has_a_column_for_each_of_the_47_bed_shapes() -> void:
	assert_eq(SoilWetness._columns.size(), 47)
	assert_eq(SoilWetness._columns[0], 0)
	assert_eq(SoilWetness._columns[255], 46)


## The steps of the 8 neighbours of a tile: all `look`, those in `others` as given.
func _neighbour_looks(look: int, others := {}) -> Dictionary:
	var looks := {}
	for neighbour: int in SoilWetness.NEIGHBOUR_OFFSETS:
		looks[neighbour] = others.get(neighbour, look)
	return looks


## The layer of the edge pieces of a side or corner `direction` of `slot` (see SoilWetness.edges).
func _layer(direction: int, slot := 0) -> int:
	var index := SoilWetness.SIDES.find(direction)
	if index < 0:
		index = SoilWetness.SIDES.size() + SoilWetness.CORNERS.find(direction)
	return index * SoilWetness.PIECE_SLOTS + slot


## The row of the edge atlas of a bite (a drier step) or a bulge (a wetter one) of `step`.
func _row(is_bulge: bool, step: int, phase: int) -> int:
	var piece := step + SoilWetness.PIECE_SLOTS - 1 if is_bulge else step
	return piece * SoilWetness.PHASES + phase


func test_a_wetter_side_bulges_into_a_tile_and_a_drier_one_bites_out_of_it() -> void:
	var pos := Vector2i(5, 7)
	var looks := _neighbour_looks(
		1, {SoilWetness.EAST: 3, SoilWetness.WEST: 0, SoilWetness.NORTH_EAST: 3}
	)
	var edges := SoilWetness.edges(pos, 1, looks)
	var east := SoilWetness.EAST
	var west := SoilWetness.WEST
	assert_eq(edges.keys(), [_layer(east), _layer(east, 1), _layer(west)])
	var east_phase := SoilWetness.edge_phase(pos, east)
	assert_eq(edges[_layer(east)].y, _row(true, 2, east_phase), "the step between first")
	assert_eq(edges[_layer(east, 1)].y, _row(true, 3, east_phase), "the wettest on top")
	assert_eq(edges[_layer(west)].y, _row(false, 0, SoilWetness.edge_phase(pos, west)))


func test_a_tile_as_wet_as_its_tilled_neighbours_has_no_edges() -> void:
	assert_eq(SoilWetness.edges(Vector2i.ZERO, 2, _neighbour_looks(2)), {})
	var by_grass := _neighbour_looks(2, {SoilWetness.EAST: -1, SoilWetness.SOUTH_EAST: -1})
	assert_eq(SoilWetness.edges(Vector2i.ZERO, 2, by_grass), {}, "the bed's rim is no edge")


func test_a_sides_edge_runs_on_turns_or_ends_at_the_beds_rim() -> void:
	var north := SoilWetness.NORTH
	var looks := _neighbour_looks(
		0,
		{
			north: 2,
			SoilWetness.NORTH_WEST: 2,
			SoilWetness.EAST: -1,
			SoilWetness.NORTH_EAST: 2,
		}
	)
	var column := func() -> int: return SoilWetness.edges(Vector2i.ZERO, 0, looks)[_layer(north)].x
	var runs_on := SoilWetness.END_RUNS_ON
	var turns := SoilWetness.END_TURNS
	assert_eq(column.call(), runs_on * 3 + SoilWetness.END_RIM, "west runs on, east at the rim")
	looks[SoilWetness.EAST] = 0
	assert_eq(column.call(), runs_on * 3 + runs_on)
	looks[SoilWetness.NORTH_EAST] = 1
	assert_eq(column.call(), runs_on * 3 + turns, "the edge beyond is another")
	looks[SoilWetness.EAST] = 2
	assert_eq(column.call(), runs_on * 3 + turns, "the patch turns")


func test_a_patchs_corner_is_rounded_off_and_its_hollow_filled_in() -> void:
	var north_east := SoilWetness.NORTH_EAST
	var corner_column := SoilWetness.SIDES.size() * 9
	var variant := PositionHash.of(Vector2i.ZERO, north_east) % SoilWetness.PHASES
	var wet_corner := _neighbour_looks(3, {SoilWetness.NORTH: 0, SoilWetness.EAST: 1})
	var edges := SoilWetness.edges(Vector2i.ZERO, 3, wet_corner)
	assert_eq(edges[_layer(north_east)], Vector2i(corner_column, _row(false, 2, variant)))
	assert_eq(edges[_layer(north_east, 1)], Vector2i(corner_column, _row(false, 1, variant)))
	assert_false(edges.has(_layer(north_east, 2)), "down to the less dry side only")
	var hollow := _neighbour_looks(0, {SoilWetness.NORTH: 3, SoilWetness.EAST: 1})
	edges = SoilWetness.edges(Vector2i.ZERO, 0, hollow)
	assert_eq(edges[_layer(north_east)], Vector2i(corner_column, _row(true, 1, variant)))
	assert_false(edges.has(_layer(north_east, 1)))
	var one_side_only := _neighbour_looks(0, {SoilWetness.NORTH: 3})
	assert_false(SoilWetness.edges(Vector2i.ZERO, 0, one_side_only).has(_layer(north_east)))


func test_the_line_of_an_edge_runs_on_from_tile_to_tile_and_both_tiles_agree() -> void:
	var pos := Vector2i(-3, 11)
	var north := SoilWetness.edge_phase(pos, SoilWetness.NORTH)
	assert_eq(SoilWetness.edge_phase(pos + Vector2i.RIGHT, SoilWetness.NORTH), (north + 1) % 4)
	assert_eq(SoilWetness.edge_phase(pos + Vector2i.UP, SoilWetness.SOUTH), north)
	var west := SoilWetness.edge_phase(pos, SoilWetness.WEST)
	assert_eq(SoilWetness.edge_phase(pos + Vector2i.DOWN, SoilWetness.WEST), (west + 1) % 4)
	assert_eq(SoilWetness.edge_phase(pos + Vector2i.LEFT, SoilWetness.EAST), west)


func test_the_edge_atlas_is_as_large_as_its_pieces() -> void:
	var texture: Texture2D = load(SoilWetness.EDGE_TEXTURE_PATH)
	var columns := SoilWetness.SIDES.size() * 9 + SoilWetness.CORNERS.size()
	var rows := 2 * SoilWetness.PIECE_SLOTS * SoilWetness.PHASES
	assert_eq(texture.get_size(), Vector2(columns, rows) * SoilWetness.TILE_SIZE)
