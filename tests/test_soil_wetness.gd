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


func test_a_tile_fades_from_a_wetter_side_and_not_from_one_as_wet_or_drier() -> void:
	var fades := SoilWetness.fades(
		1,
		255,
		_neighbour_looks(1, {SoilWetness.EAST: 3, SoilWetness.WEST: 0, SoilWetness.NORTH: 1})
	)
	assert_eq(fades.keys(), [SoilWetness.EAST])
	assert_eq(fades[SoilWetness.EAST].y, SoilWetness._fade_row(3, 1), "from step 3 into step 1")
	assert_eq(SoilWetness.fades(2, 255, _neighbour_looks(2)), {}, "a bed as wet all over")


func test_each_pair_of_steps_has_a_row_of_its_own() -> void:
	var rows := {}
	for wetter in range(1, SoilWetness.LOOKS):
		for drier in wetter:
			rows[SoilWetness._fade_row(wetter, drier)] = true
	assert_eq(rows.keys().size(), 6)
	assert_eq(rows.keys().max(), 5)


func test_a_fade_along_a_side_is_cut_where_the_bed_ends_beside_it() -> void:
	var looks := _neighbour_looks(0, {SoilWetness.EAST: 2})
	var inside := SoilWetness.fades(0, 255, looks)[SoilWetness.EAST].x
	var at_the_edge := (
		SoilWetness
		. fades(0, SoilWetness.EAST | SoilWetness.SOUTH | SoilWetness.SOUTH_EAST, looks)[
			SoilWetness.EAST
		]
		. x
	)
	var notched := SoilWetness.fades(0, 255 & ~SoilWetness.NORTH_EAST, looks)[SoilWetness.EAST].x
	assert_eq(inside, 1 * 9 + 2 * 3 + 2, "east, both ends inside the bed")
	assert_eq(at_the_edge, 1 * 9 + 0 * 3 + 2, "the north of it not tilled")
	assert_eq(notched, 1 * 9 + 1 * 3 + 2, "the north tilled, the north-east not")


func test_a_corner_fades_only_inside_the_bed_and_where_its_sides_are_drier() -> void:
	var looks := _neighbour_looks(0, {SoilWetness.NORTH_WEST: 3})
	var fades := SoilWetness.fades(0, 255, looks)
	assert_eq(fades.keys(), [SoilWetness.NORTH_WEST])
	assert_eq(fades[SoilWetness.NORTH_WEST], Vector2i(4 * 9 + 3, SoilWetness._fade_row(3, 0)))
	var without_the_west := 255 & ~SoilWetness.WEST & ~SoilWetness.NORTH_WEST
	assert_eq(SoilWetness.fades(0, without_the_west, looks), {}, "the bed's rim lies at the corner")
	looks[SoilWetness.NORTH] = 3
	assert_false(
		SoilWetness.fades(0, 255, looks).has(SoilWetness.NORTH_WEST), "the north covers it"
	)
	looks[SoilWetness.NORTH] = 2
	assert_true(
		SoilWetness.fades(0, 255, looks).has(SoilWetness.NORTH_WEST), "darker than the north"
	)
