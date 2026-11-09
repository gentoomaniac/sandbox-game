extends ResourceCase
## The camp's bedroll and campfire: the hammer takes them down into items, they are crafted and
## set up again elsewhere, the home bed follows the bedroll and the campfire cooks where it stands.

const BEDROLL := WorldObjectTypes.SLEEPING_BAG
const CAMPFIRE := WorldObjectTypes.FIREPLACE

var _builder: Builder
var _camp_bed: WorldObject
var _camp_fire: WorldObject


func before_each() -> void:
	super.before_each()
	_builder = Builder.new(_state)
	_camp_bed = _world.object_at(_state.player.home_bed)
	_camp_fire = _world.object_at(_camp_bed.pos - CampSite.SLEEPING_BAG_OFFSET)


func _take_down(object: WorldObject) -> bool:
	return _builder.take_down(TakeDownTarget.of_object(object))


func _set_up(item: StringName) -> WorldObject:
	_state.player.inventory.add(item, 1)
	_hold(item)
	assert_eq(_state.use_tile(_tile), ToolUse.Use.PLACE)
	return _world.object_at(_tile)


func test_the_camps_bedroll_and_campfire_are_taken_down_into_their_items() -> void:
	_state.player.position = Vector2(_camp_bed.pos) + Vector2(2.5, 0.5)
	assert_true(_take_down(_camp_bed))
	assert_null(_world.object_at(_camp_bed.pos))
	assert_eq(_state.player.inventory.count_of(ItemTypes.SLEEPING_BAG), 1)
	assert_true(_take_down(_camp_fire))
	assert_null(_world.object_at(_camp_fire.pos))
	assert_eq(_state.player.inventory.count_of(ItemTypes.FIREPLACE), 1)


func test_they_are_named_for_what_they_are_when_the_hammer_aims_at_them() -> void:
	assert_eq(TakeDownTarget.of_object(_camp_bed).display_name(), "Bedroll")
	assert_eq(TakeDownTarget.of_object(_camp_fire).display_name(), "Campfire")
	assert_eq(_builder.take_down_target(_camp_fire.pos).object, _camp_fire)


func test_one_lying_in_the_bedroll_gets_up_before_it_is_taken_down() -> void:
	_state.sleep_in(_camp_bed)
	assert_ne(_builder.why_not_take_down(TakeDownTarget.of_object(_camp_bed)), "")
	assert_false(_take_down(_camp_bed))


func test_both_are_crafted_by_hand_from_materials_that_exist() -> void:
	var rules := RecipeRules.default_rules()
	var crafting := Crafting.new(_state)
	for item in [ItemTypes.FIREPLACE, ItemTypes.SLEEPING_BAG]:
		assert_has(rules.recipes_at(&""), item)
		assert_eq(rules.result(item), item)
		assert_eq(crafting.craft(item), Crafting.Result.MISSING_MATERIALS, item)
		for material in rules.materials(item):
			assert_has(ItemTypes.TYPES, material)
			_state.player.inventory.add(material, rules.materials(item)[material])
		assert_eq(crafting.craft(item), Crafting.Result.CRAFTED, item)
		assert_eq(_state.player.inventory.count_of(item), 1)


func test_they_are_set_up_outdoors_where_the_ghost_can_be_drawn() -> void:
	assert_eq(_set_up(ItemTypes.SLEEPING_BAG).type, BEDROLL)
	assert_eq(_state.player.inventory.count_of(ItemTypes.SLEEPING_BAG), 0)
	for type in [BEDROLL, CAMPFIRE]:
		assert_true(WorldObjectTypes.TYPES[type]["outdoors_only"], type)
		var ghost: Texture2D = load(WorldObjectTypes.TYPES[type]["interior_sprite"])
		var footprint: Vector2i = WorldObjectTypes.TYPES[type]["footprint"]
		var tile := TerrainTileset.TILE_SIZE
		# Cut to the picture, not the whole cell of the object atlas.
		assert_lte(ghost.get_width(), 2 * tile, type)
		assert_lte(ghost.get_height(), (footprint.y + 1) * tile, type)


func test_the_bedroll_needs_both_its_tiles_free() -> void:
	_world.add_object(WorldObject.new(WorldObjectTypes.CHEST, _tile + Vector2i.DOWN))
	_state.player.inventory.add(ItemTypes.SLEEPING_BAG, 1)
	_hold(ItemTypes.SLEEPING_BAG)
	assert_ne(_state.use_at(_tile), ToolUse.Use.PLACE)


func test_the_moved_objects_are_in_the_save() -> void:
	_take_down(_camp_fire)
	var fire := _set_up(ItemTypes.FIREPLACE)
	_state.player.position = Vector2(_camp_bed.pos) + Vector2(2.5, 0.5)
	_take_down(_camp_bed)
	var path := "user://camp_objects_test.json"
	assert_true(SaveFile.write(_state, path))
	var restored := SaveFile.read(path)
	DirAccess.remove_absolute(path)
	assert_not_null(restored)
	for pos: Vector2i in [fire.pos, _camp_bed.pos, _camp_fire.pos]:
		var coords := Chunk.world_to_chunk(pos)
		if not restored.world.is_chunk_loaded(coords):
			restored.world.add_chunk(WorldGenerator.new(SEED).generate_chunk(coords))
	assert_eq(restored.world.object_at(fire.pos).type, CAMPFIRE)
	assert_null(restored.world.object_at(_camp_bed.pos))
	assert_null(restored.world.object_at(_camp_fire.pos))
