extends ResourceCase
## The dead and the half-dead trees of every kind (issue #102): their types and what felling them
## gives (where the land puts them: test_snag_generation.gd; the save: test_save_snags.gd).

# The iron axe, which pines need and which hits for 2.
var _strong_axe := ItemTypes.tool_item(ItemTypes.AXE, 1)


func _snag_types() -> Array[StringName]:
	var types: Array[StringName] = []
	for kind in WorldObjectSnags.KINDS:
		types.append(WorldObjectSnags.dead_type(kind))
		types.append(WorldObjectSnags.half_dead_type(kind))
	return types


func before_each() -> void:
	super.before_each()
	_make_room()


func _fell(tree: StringName) -> void:
	for x in range(-2, 3):
		_world.remove_object(_tile + Vector2i(x, 0))
	_place(tree)
	_hit(_strong_axe, ceili(WorldObjectTypes.TYPES[tree]["hp"] / 2.0))


# --- The catalog ---


func test_every_kind_has_a_dead_and_a_half_dead_tree_with_its_variants() -> void:
	for kind in WorldObjectSnags.KINDS:
		var dead: Dictionary = WorldObjectTypes.TYPES[WorldObjectSnags.dead_type(kind)]
		var half_dead: Dictionary = WorldObjectTypes.TYPES[WorldObjectSnags.half_dead_type(kind)]
		assert_eq(dead["variants"], 3, kind)
		assert_eq(half_dead["variants"], 2, kind)
		for snag: Dictionary in [dead, half_dead]:
			assert_true(snag["blocks_walking"], kind)
			assert_eq(
				snag["leaves"], WorldObjectTypes.TYPES[kind]["leaves"], "%s: its stump" % kind
			)
			assert_eq(snag["harvest_level"], WorldObjectTypes.TYPES[kind]["harvest_level"], kind)
			assert_gt(snag["sprite_height"], 0, "%s sees through" % kind)


func test_every_snag_is_drawn_in_every_look_with_something_on_every_variant() -> void:
	for look in SeasonBlend.Look.values():
		var image: Image = load(SeasonalArt.path(ObjectTileset.ATLAS_PATH, look)).get_image()
		for type_name in _snag_types():
			var snag: Dictionary = WorldObjectTypes.TYPES[type_name]
			for variant in snag["variants"]:
				var origin := (
					Vector2i(variant, snag["atlas_row"])
					* Vector2i(ObjectTileset.CELL_WIDTH, ObjectTileset.CELL_HEIGHT)
				)
				var cell := image.get_region(
					Rect2i(origin, Vector2i(ObjectTileset.CELL_WIDTH, ObjectTileset.CELL_HEIGHT))
				)
				assert_false(
					cell.is_invisible(), "%s variant %d, look %d" % [type_name, variant, look]
				)


func test_the_tile_set_has_a_tile_for_every_variant_of_every_snag_and_its_trunks() -> void:
	var source: TileSetAtlasSource = ObjectTileset.new().tile_set.get_source(
		SeasonBlend.Look.SUMMER
	)
	for type_name in _snag_types():
		var snag: Dictionary = WorldObjectTypes.TYPES[type_name]
		for variant in snag["variants"]:
			assert_true(source.has_tile(Vector2i(variant, snag["atlas_row"])), type_name)
		var trunk: Dictionary = WorldObjectTypes.TYPES[WorldObjectTypes.trunk_type(
			type_name, false
		)]
		assert_true(source.has_tile(Vector2i(0, trunk["atlas_row"])), "%s trunk" % type_name)


func test_a_snag_has_fewer_logs_than_the_living_tree_and_a_dead_one_fewer_than_a_half_dead_one(
) -> void:
	for kind in WorldObjectSnags.KINDS:
		var living: int = WorldObjectTypes.TYPES[kind]["trunk"]["logs"]
		var half_dead: int = (
			WorldObjectTypes.TYPES[WorldObjectSnags.half_dead_type(kind)]["trunk"]["logs"]
		)
		var dead: int = WorldObjectTypes.TYPES[WorldObjectSnags.dead_type(kind)]["trunk"]["logs"]
		assert_lt(half_dead, living, kind)
		assert_lte(dead, half_dead, kind)
		assert_gte(dead, 1, kind)


# --- Felling ---


func test_felling_a_snag_leaves_the_stump_and_the_trunk_of_its_kind() -> void:
	for type_name in _snag_types():
		_fell(type_name)
		var snag: Dictionary = WorldObjectTypes.TYPES[type_name]
		assert_eq(_world.object_at(_tile).type, snag["leaves"], type_name)
		var trunk := _world.object_at(_tile + Vector2i.RIGHT)
		assert_eq(trunk.type, WorldObjectTypes.trunk_type(type_name, false), type_name)
		var trunk_data := trunk.type_data()
		var kind_trunk: Dictionary = WorldObjectTypes.TYPES[WorldObjectTypes.trunk_type(
			StringName(String(type_name).trim_prefix("half_").trim_prefix("dead_")), false
		)]
		assert_eq(
			trunk_data["atlas_row"], kind_trunk["atlas_row"], "%s: the kind's trunk" % type_name
		)
		assert_eq(trunk_data["drops"], {&"logs": snag["trunk"]["logs"]}, type_name)


func test_the_stump_of_a_snag_remembers_the_living_tree_of_its_kind() -> void:
	_fell(&"half_dead_beech")
	assert_eq(_world.object_at(_tile).state["tree"], "beech")


func test_a_dead_tree_gives_no_seed_and_a_half_dead_one_gives_its_kinds_seed_less_often() -> void:
	var seed_item: StringName = WorldObjectTypes.TYPES[&"oak"]["seed"]
	assert_false(WorldObjectTypes.TYPES[&"dead_oak"].has("seed"))
	var living := 0
	var half_dead := 0
	for day in range(1, 301):
		_state.clock.day = day
		for tree: StringName in [&"oak", &"half_dead_oak", &"dead_oak"]:
			_clear_ground()
			_fell(tree)
			if tree == &"oak":
				living += _dropped(seed_item)
			elif tree == &"half_dead_oak":
				half_dead += _dropped(seed_item)
			else:
				assert_eq(_dropped(seed_item), 0, "a dead oak")
	assert_between(living, 50, 100, "a living oak: a quarter")
	assert_between(half_dead, 15, 50, "a half-dead oak: an eighth")
