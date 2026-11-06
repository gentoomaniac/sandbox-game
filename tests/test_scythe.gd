extends ResourceCase
## The scythe and tall grass: the pattern of a swing, hay on the ground, regrowth, the seasons
## and saving.

const WINTER := 105
const AUTUMN := 80
const SPRING := 12
## The tiles around the player's tile that are made grass and filled with tall grass.
const FIELD_RADIUS := 3

var _centre: Vector2i


func before_each() -> void:
	super.before_each()
	_set_midsummer()
	_centre = _tile
	_state.player.position = Vector2(_centre) + Vector2(0.5, 0.5)


## Tall grass on every tile within FIELD_RADIUS of the centre.
func _fill_field() -> void:
	for y in range(-FIELD_RADIUS, FIELD_RADIUS + 1):
		for x in range(-FIELD_RADIUS, FIELD_RADIUS + 1):
			var pos := _centre + Vector2i(x, y)
			_world.remove_object(pos)
			if _world.tile_at(pos).terrain != Tile.Terrain.GRASS:
				_world.set_terrain(pos, Tile.Terrain.GRASS)
			_world.add_object(WorldObject.new(WorldObjectTypes.TALL_GRASS, pos))


func _mown_tiles() -> Array[Vector2i]:
	var mown: Array[Vector2i] = []
	for y in range(-FIELD_RADIUS, FIELD_RADIUS + 1):
		for x in range(-FIELD_RADIUS, FIELD_RADIUS + 1):
			var pos := _centre + Vector2i(x, y)
			if _world.object_at(pos).is_picked():
				mown.append(pos)
	mown.sort()
	return mown


func _sorted(tiles: Array[Vector2i]) -> Array[Vector2i]:
	tiles.sort()
	return tiles


# --- The pattern ---


func test_a_swing_mows_two_tiles_ahead_and_the_sides_of_the_nearer_one_for_each_facing() -> void:
	var expectations := {
		Vector2i.DOWN: [Vector2i(0, 1), Vector2i(0, 2), Vector2i(-1, 1), Vector2i(1, 1)],
		Vector2i.UP: [Vector2i(0, -1), Vector2i(0, -2), Vector2i(-1, -1), Vector2i(1, -1)],
		Vector2i.LEFT: [Vector2i(-1, 0), Vector2i(-2, 0), Vector2i(-1, -1), Vector2i(-1, 1)],
		Vector2i.RIGHT: [Vector2i(1, 0), Vector2i(2, 0), Vector2i(1, -1), Vector2i(1, 1)],
	}
	for facing: Vector2i in expectations:
		_fill_field()
		_state.player.facing = facing
		_hold(ItemTypes.SCYTHE)
		assert_eq(_state.use_facing_tile(), ToolUse.Use.MOW)
		var expected: Array[Vector2i] = []
		for offset: Vector2i in expectations[facing]:
			expected.append(_centre + offset)
		assert_eq(_mown_tiles(), _sorted(expected), "facing %s" % facing)


func test_a_swing_mows_only_the_tall_grass_in_its_pattern() -> void:
	_world.remove_object(_centre + Vector2i.DOWN)
	_world.add_object(WorldObject.new(WorldObjectTypes.TALL_GRASS, _centre + Vector2i.DOWN))
	var shrub_tile := _centre + Vector2i(1, 1)
	_world.remove_object(shrub_tile)
	_world.add_object(WorldObject.new(WorldObjectTypes.SHRUB, shrub_tile))
	_state.player.facing = Vector2i.DOWN
	_hold(ItemTypes.SCYTHE)
	assert_eq(_state.use_facing_tile(), ToolUse.Use.MOW)
	assert_eq(_world.object_at(shrub_tile).type, WorldObjectTypes.SHRUB)
	assert_eq(_dropped(ItemTypes.HAY), 2, "only the one tuft gave hay")


func test_mowing_nothing_does_nothing_and_costs_nothing() -> void:
	_state.player.facing = Vector2i.DOWN
	_world.remove_object(_centre + Vector2i.DOWN)
	_hold(ItemTypes.SCYTHE)
	assert_eq(_state.use_at(_centre + Vector2i.DOWN), ToolUse.Use.NOTHING)
	assert_eq(_state.use_facing_tile(), ToolUse.Use.NOTHING)
	assert_eq(_state.player.energy, PlayerState.MAX_ENERGY)
	assert_eq(_dropped(ItemTypes.HAY), 0)


func test_mowing_costs_one_action_of_energy() -> void:
	_fill_field()
	_state.player.facing = Vector2i.DOWN
	_hold(ItemTypes.SCYTHE)
	_state.use_facing_tile()
	assert_lt(_state.player.energy, PlayerState.MAX_ENERGY)
	var after_one := _state.player.energy
	_state.use_facing_tile()
	assert_eq(_state.player.energy, after_one, "the tufts are mown: nothing more to do")


func test_a_hand_does_not_pick_tall_grass() -> void:
	_fill_field()
	_hold(ItemTypes.NONE)
	assert_eq(_state.use_at(_centre + Vector2i.DOWN), ToolUse.Use.NOTHING)


# --- Hay and regrowth ---


func test_mown_grass_drops_hay_on_the_ground_and_looks_mown() -> void:
	_fill_field()
	var tuft := _world.object_at(_centre + Vector2i.DOWN)
	var tall_look := ObjectTileset.atlas_cell(tuft)
	_state.player.facing = Vector2i.DOWN
	_hold(ItemTypes.SCYTHE)
	_state.use_facing_tile()
	assert_eq(_dropped(ItemTypes.HAY), 4 * 2)
	assert_eq(_count(ItemTypes.HAY), 0, "it lies on the ground until collected")
	assert_ne(ObjectTileset.atlas_cell(tuft), tall_look)
	assert_same(_world.object_at(_centre + Vector2i.DOWN), tuft, "mowing does not remove it")


func test_mown_grass_grows_back_after_its_regrow_days() -> void:
	_fill_field()
	var tuft := _world.object_at(_centre + Vector2i.DOWN)
	var tall_look := ObjectTileset.atlas_cell(tuft)
	var regrow_days: int = WorldObjectTypes.TYPES[WorldObjectTypes.TALL_GRASS]["regrow_days"]
	_state.player.facing = Vector2i.DOWN
	_hold(ItemTypes.SCYTHE)
	_state.use_facing_tile()
	_sleep_days(regrow_days - 1)
	assert_true(tuft.is_picked())
	assert_eq(_state.use_at(_centre + Vector2i.DOWN), ToolUse.Use.NOTHING)
	_sleep_days(1)
	assert_false(tuft.is_picked())
	assert_eq(ObjectTileset.atlas_cell(tuft), tall_look)
	_clear_ground()
	assert_eq(_state.use_facing_tile(), ToolUse.Use.MOW)
	assert_eq(_dropped(ItemTypes.HAY), 2 * 4, "four tufts again")


# --- The seasons ---


func test_tall_grass_is_there_in_summer_and_gone_in_winter() -> void:
	var tuft := WorldObject.new(WorldObjectTypes.TALL_GRASS, _centre + Vector2i.DOWN)
	_world.remove_object(tuft.pos)
	_world.add_object(tuft)
	assert_same(_world.object_at(tuft.pos), tuft)
	_state.clock.day = WINTER
	assert_true(_world.is_dormant(tuft))
	assert_null(_world.object_at(tuft.pos))
	_hold(ItemTypes.SCYTHE)
	_state.player.facing = Vector2i.DOWN
	assert_eq(_state.use_facing_tile(), ToolUse.Use.NOTHING, "nothing to mow in winter")


func test_tall_grass_comes_in_over_spring_and_thins_in_autumn() -> void:
	var vegetation := _world.vegetation
	var in_spring := _share_present(vegetation, SPRING)
	var in_summer := _share_present(vegetation, MIDSUMMER)
	var in_autumn := _share_present(vegetation, AUTUMN)
	assert_gt(in_summer, 0.99, "all of it stands in summer")
	assert_between(in_spring, 0.05, in_summer - 0.2)
	assert_between(in_autumn, 0.05, in_summer - 0.2)
	assert_eq(_share_present(vegetation, WINTER), 0.0)


func _share_present(vegetation: Vegetation, day: int) -> float:
	var present := 0
	for x in 200:
		if vegetation.is_present(&"tall_grass", SEED, Vector2i(x, 3), day):
			present += 1
	return present / 200.0


func test_tall_grass_is_drawn_tall_and_mown_in_every_look() -> void:
	var object_type: Dictionary = WorldObjectTypes.TYPES[WorldObjectTypes.TALL_GRASS]
	assert_eq(ObjectTileset.looks_count(object_type), 2 * object_type["variants"])
	for look in SeasonBlend.Look.values():
		var image: Image = load(SeasonalArt.path(ObjectTileset.ATLAS_PATH, look)).get_image()
		for variant in ObjectTileset.looks_count(object_type):
			var cell := Vector2i(variant, object_type["atlas_row"])
			var region := Rect2i(
				cell * Vector2i(ObjectTileset.CELL_WIDTH, ObjectTileset.CELL_HEIGHT),
				Vector2i(ObjectTileset.CELL_WIDTH, ObjectTileset.CELL_HEIGHT)
			)
			assert_false(
				image.get_region(region).is_invisible(), "look %d, variant %d" % [look, variant]
			)


# --- Saving ---


func test_mown_grass_stays_mown_through_the_save() -> void:
	_fill_field()
	_state.player.facing = Vector2i.DOWN
	_hold(ItemTypes.SCYTHE)
	_state.use_facing_tile()
	_sleep_days(1)
	var mown_before := _mown_tiles()
	var restored := _through_save()
	_world = restored.world
	assert_eq(_mown_tiles(), mown_before)
	assert_eq(_world.ground_items.count_of(ItemTypes.HAY), 8)


func test_the_scythe_and_shovel_are_in_the_starting_items_within_the_hotbar() -> void:
	var inventory := Inventory.with_starting_items()
	for item in [ItemTypes.SCYTHE, ItemTypes.SHOVEL, ItemTypes.TURNIP_SEEDS]:
		var slot := -1
		for index in Inventory.HOTBAR_SIZE:
			if inventory.item_in(index) == item:
				slot = index
		assert_ne(slot, -1, "%s is on the hotbar" % item)


func test_mowing_throws_no_hit_effect() -> void:
	assert_eq(
		HitEffect.kind_for(WorldObjectTypes.TALL_GRASS, SeasonBlend.Look.SUMMER),
		HitEffect.Kind.NONE
	)
	var hits: Array[WorldObject] = []
	_world.object_hit.connect(func(object: WorldObject) -> void: hits.append(object))
	_fill_field()
	_state.player.facing = Vector2i.DOWN
	_hold(ItemTypes.SCYTHE)
	_state.use_facing_tile()
	assert_eq(hits.size(), 0)
