extends GutTest
## Which villagers have a view: only those near the focus. The others go on in the state.

const SIZE := Chunk.CHUNK_SIZE

var _npcs: Npcs
var _world: World
var _entities: Node2D
var _views: NpcViews


func before_each() -> void:
	_npcs = Npcs.new(Sun.new())
	_world = World.new(1)
	_entities = Node2D.new()
	add_child_autofree(_entities)
	_views = NpcViews.new()
	add_child_autofree(_views)
	_views.show_npcs(_npcs, _entities, _world)


func after_each() -> void:
	ArtSet.is_classic = false


## A villager at `position`, on a chunk that is loaded (the chunk of every villager is, but for the
## ones the tests unload).
func _villager_at(position: Vector2) -> Npc:
	_load_chunk_of(position)
	var npc := Npc.create(1, position, NpcRules.default_rules())
	_npcs.add(npc)
	return npc


func _load_chunk_of(position: Vector2) -> void:
	var coords := Chunk.world_to_chunk(Vector2i(position.floor()))
	if World.is_chunk_in_bounds(coords) and not _world.is_chunk_loaded(coords):
		_world.add_chunk(WorldGenerator.new(1).generate_chunk(coords))


func _focus_and_update(world_pos: Vector2i) -> void:
	_views.set_focus(world_pos)
	_views._process(0.0)


func test_there_is_no_view_before_the_focus_is_known() -> void:
	_villager_at(Vector2(3, 3))
	_views._process(0.0)
	assert_eq(_entities.get_child_count(), 0)


func test_only_the_villagers_near_the_focus_have_a_view() -> void:
	_villager_at(Vector2(3, 3))
	_villager_at(Vector2(SIZE * 30, 3))
	_villager_at(Vector2(-SIZE * 2, 3))
	_focus_and_update(Vector2i(2, 2))
	assert_eq(_entities.get_child_count(), 2)


func test_a_villager_who_comes_into_the_world_near_the_focus_gets_a_view() -> void:
	_focus_and_update(Vector2i(2, 2))
	_villager_at(Vector2(5, 5))
	_villager_at(Vector2(SIZE * 30, 3))
	assert_eq(_entities.get_child_count(), 1)


func test_a_villager_who_walks_away_loses_the_view_and_gets_it_back_once() -> void:
	var npc := _villager_at(Vector2(3, 3))
	_focus_and_update(Vector2i(2, 2))
	npc.position = Vector2(SIZE * 30, 3)
	_focus_and_update(Vector2i(2, 2))
	await get_tree().process_frame
	assert_eq(_entities.get_child_count(), 0)
	npc.position = Vector2(4, 4)
	_focus_and_update(Vector2i(2, 2))
	_focus_and_update(Vector2i(2, 2))
	assert_eq(_entities.get_child_count(), 1)


func test_a_villager_who_is_inside_a_building_has_no_view_in_the_world() -> void:
	var npc := _villager_at(Vector2(3, 3))
	_focus_and_update(Vector2i(2, 2))
	assert_eq(_entities.get_child_count(), 1)
	npc.inside = Building.new(BuildingTypes.KATE, Vector2i.ZERO)
	_focus_and_update(Vector2i(2, 2))
	await get_tree().process_frame
	assert_eq(_entities.get_child_count(), 0)
	npc.inside = null
	_focus_and_update(Vector2i(2, 2))
	assert_eq(_entities.get_child_count(), 1, "and one again when they come out")


func test_a_view_is_kept_one_chunk_beyond_where_it_is_made() -> void:
	var edge := NpcViews.NEAR_CHUNKS
	_villager_at(Vector2((edge + 0.5) * SIZE, 5))
	_focus_and_update(Vector2i(2, 2))
	assert_eq(_entities.get_child_count(), 1)
	_focus_and_update(Vector2i(2 - SIZE, 2))
	assert_eq(_entities.get_child_count(), 1)
	_focus_and_update(Vector2i(2 - 2 * SIZE, 2))
	await get_tree().process_frame
	assert_eq(_entities.get_child_count(), 0)


func test_the_state_of_a_villager_without_a_view_goes_on() -> void:
	var npc := _villager_at(Vector2(SIZE * 30, 3))
	npc.activity = Npc.Activity.WALK
	npc.heading = Vector2.RIGHT
	npc.seconds_left = 5.0
	_focus_and_update(Vector2i(2, 2))
	var clock := GameClock.new()
	clock.day = 45
	clock.minute_of_day = 12 * 60
	_npcs.update(0.05, World.new(1), Vector2.ZERO, clock)
	assert_eq(_entities.get_child_count(), 0)
	assert_ne(npc.seconds_left, 5.0)


func test_a_villager_who_leaves_the_world_loses_the_view_at_once() -> void:
	var gone := _villager_at(Vector2(3, 3))
	var stays := _villager_at(Vector2(5, 5))
	_focus_and_update(Vector2i(2, 2))
	_npcs.remove(gone)
	await get_tree().process_frame
	assert_eq(_entities.get_child_count(), 1)
	_focus_and_update(Vector2i(2, 2))
	assert_eq(_entities.get_child_count(), 1, "the one who left gets no view again")
	assert_eq(_npcs.all(), [stays] as Array[Npc])


func test_a_villager_on_a_chunk_that_is_not_loaded_has_no_view_until_it_is() -> void:
	var npc := _villager_at(Vector2(3, 3))
	_world.remove_chunk(Vector2i.ZERO)
	_focus_and_update(Vector2i(2, 2))
	assert_eq(_entities.get_child_count(), 0, "near, but there is no ground under it")
	_load_chunk_of(npc.position)
	_focus_and_update(Vector2i(2, 2))
	assert_eq(_entities.get_child_count(), 1)


func test_a_villager_walks_on_to_a_chunk_that_is_not_loaded_and_loses_the_view() -> void:
	_villager_at(Vector2(3, 3))
	_focus_and_update(Vector2i(2, 2))
	assert_eq(_entities.get_child_count(), 1)
	_world.remove_chunk(Vector2i.ZERO)
	_focus_and_update(Vector2i(2, 2))
	await get_tree().process_frame
	assert_eq(_entities.get_child_count(), 0)
