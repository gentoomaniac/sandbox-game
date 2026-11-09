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
