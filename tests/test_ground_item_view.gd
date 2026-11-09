extends GutTest
## Which piles of the ground have a sprite: only those near the focus. The others stay in the
## state and get theirs when the player comes near.

const SIZE := Chunk.CHUNK_SIZE
const FAR := Vector2(SIZE * 40, SIZE * 40)

var _world: World
var _entities: Node2D
var _view: GroundItemView


func before_each() -> void:
	_world = World.new(1)
	_entities = Node2D.new()
	add_child_autofree(_entities)
	_view = GroundItemView.new()
	add_child_autofree(_view)
	_view.show_items(_world, _entities)


func after_each() -> void:
	ArtSet.is_classic = false


func _lay(position: Vector2) -> GroundItem:
	var ground_item := GroundItem.new(ItemTypes.LOGS, 1, position)
	_world.ground_items.add(ground_item)
	return ground_item


func _sprite_count() -> int:
	return _view._sprites.size()


func test_there_is_no_sprite_before_the_focus_is_known() -> void:
	_lay(Vector2(3, 3))
	assert_eq(_sprite_count(), 0)


func test_ten_thousand_distant_piles_and_a_few_near_ones_give_sprites_for_the_near_ones() -> void:
	for index in 10000:
		_lay(FAR + Vector2(index % 100, index / 100) * 3.0)
	var near_piles: Array[GroundItem] = [_lay(Vector2(3, 3)), _lay(Vector2(40, 3))]
	_lay(Vector2(-20, 5))
	_view.set_focus(Vector2i(2, 2))
	assert_eq(_sprite_count(), 3)
	assert_true(_view._sprites.has(near_piles[0]))
	assert_eq(_entities.get_child_count(), 3)


func test_a_pile_laid_near_gets_a_sprite_and_one_laid_far_away_does_not() -> void:
	_view.set_focus(Vector2i(2, 2))
	var near := _lay(Vector2(5, 5))
	_lay(FAR)
	assert_eq(_sprite_count(), 1)
	assert_true(_view._sprites.has(near))


func test_leaving_frees_the_sprites_and_coming_back_makes_them_again_once_each() -> void:
	var pile := _lay(Vector2(5, 5))
	_view.set_focus(Vector2i(2, 2))
	assert_eq(_sprite_count(), 1)
	_view.set_focus(Vector2i(SIZE * 10, 0))
	assert_eq(_sprite_count(), 0)
	await get_tree().process_frame
	assert_eq(_entities.get_child_count(), 0)
	_view.set_focus(Vector2i(2, 2))
	_view.set_focus(Vector2i(2, 3))
	assert_eq(_sprite_count(), 1)
	assert_true(_view._sprites.has(pile))
	assert_eq(_entities.get_child_count(), 1)


func test_a_sprite_is_kept_one_chunk_beyond_the_near_ones() -> void:
	var edge := GroundItemView.NEAR_CHUNKS
	_lay(Vector2((edge + 0.5) * SIZE, 5))
	_view.set_focus(Vector2i(2, 2))
	assert_eq(_sprite_count(), 1)
	_view.set_focus(Vector2i(2 - SIZE, 2))
	assert_eq(_sprite_count(), 1, "one chunk further out, but still kept")
	_view.set_focus(Vector2i(2 - 2 * SIZE, 2))
	assert_eq(_sprite_count(), 0)


func test_a_collected_pile_loses_its_sprite() -> void:
	var pile := _lay(Vector2(5, 5))
	_view.set_focus(Vector2i(2, 2))
	_world.ground_items.remove(pile)
	assert_eq(_sprite_count(), 0)


func test_collecting_a_pile_without_a_sprite_does_nothing_to_the_view() -> void:
	var far := _lay(FAR)
	_view.set_focus(Vector2i(2, 2))
	_world.ground_items.remove(far)
	assert_eq(_sprite_count(), 0)


func test_a_pile_pulled_to_another_chunk_keeps_its_one_sprite() -> void:
	var pile := _lay(Vector2(SIZE - 0.3, 5))
	_view.set_focus(Vector2i(2, 2))
	_world.ground_items.move(pile, Vector2(SIZE + 0.3, 5))
	_view.set_focus(Vector2i(SIZE + 2, 2))
	assert_eq(_sprite_count(), 1)
	assert_eq(_entities.get_child_count(), 1)


func test_a_drop_far_from_the_focus_has_no_hops() -> void:
	_view.set_focus(Vector2i(2, 2))
	_world.ground_items.dropped.emit(Vector2i(FAR), [_lay(FAR)] as Array[GroundItem])
	assert_true(_view._hops.is_empty())


func test_switching_art_changes_the_sprites_there_are_and_the_ones_made_later() -> void:
	_lay(Vector2(5, 5))
	_view.set_focus(Vector2i(2, 2))
	var path := ItemTypes.ground_icon_path(ItemTypes.LOGS)
	ArtSet.is_classic = true
	_view.show_art_set()
	assert_eq(_view._sprites.values()[0].texture.resource_path, ArtSet.path(path))
	_lay(Vector2(6, 5))
	for sprite: Sprite2D in _view._sprites.values():
		assert_eq(sprite.texture.resource_path, ArtSet.path(path))


func test_a_loaded_world_shows_the_piles_near_the_focus() -> void:
	_lay(Vector2(5, 5))
	_lay(FAR)
	var loaded := World.from_dict(_world.to_dict(), GameClock.new())
	var entities := Node2D.new()
	add_child_autofree(entities)
	var view := GroundItemView.new()
	add_child_autofree(view)
	view.show_items(loaded, entities)
	view.set_focus(Vector2i(2, 2))
	assert_eq(view._sprites.size(), 1)
	assert_eq(entities.get_child_count(), 1)
