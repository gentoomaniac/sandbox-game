extends GutTest
## The piles on the floor of a room are drawn by the InteriorView among its furniture.

const KATE_MAP := "res://maps/interiors/kate.tmx"


func _drawn_entities(view: InteriorView) -> int:
	return (
		view
		. entities
		. get_children()
		. filter(func(node: Node) -> bool: return not node.is_queued_for_deletion())
		. size()
	)


func test_the_view_draws_the_piles_on_the_floor_among_the_furniture() -> void:
	var view := InteriorView.new()
	add_child_autofree(view)
	var interior := InteriorLoader.load_interior(KATE_MAP)
	var lying := GroundItem.new(ItemTypes.LOGS, 2, Vector2(3.5, 4.5))
	interior.ground_items.add(lying)
	view.show_interior(interior)
	assert_eq(_drawn_entities(view), 10, "the furniture and the pile, which stands among it")
	var pile: Sprite2D = view.entities.get_children().filter(_is_pile)[0]
	assert_eq(pile.position, Vector2(3.5, 4.5) * TerrainTileset.TILE_SIZE)
	interior.ground_items.add(GroundItem.new(ItemTypes.STONE, 1, Vector2(4.5, 4.5)))
	assert_eq(_drawn_entities(view), 11, "one laid later is drawn at once")
	interior.ground_items.remove(lying)
	await wait_frames(1)
	assert_eq(_drawn_entities(view), 10, "and one collected is gone")


func test_the_piles_of_the_room_left_are_not_drawn_in_the_next() -> void:
	var view := InteriorView.new()
	add_child_autofree(view)
	var interior := InteriorLoader.load_interior(KATE_MAP)
	interior.ground_items.add(GroundItem.new(ItemTypes.LOGS, 2, Vector2(3.5, 4.5)))
	view.show_interior(interior)
	view.show_interior(InteriorLoader.load_interior(KATE_MAP))
	await wait_frames(1)
	assert_eq(_drawn_entities(view), 9)


func test_a_pile_on_the_floor_switches_with_the_art() -> void:
	var view := InteriorView.new()
	add_child_autofree(view)
	var interior := InteriorLoader.load_interior(KATE_MAP)
	interior.ground_items.add(GroundItem.new(ItemTypes.LOGS, 2, Vector2(3.5, 4.5)))
	view.show_interior(interior)
	ArtSet.show(true, get_tree())
	var pile: Sprite2D = view.entities.get_children().filter(_is_pile)[0]
	var path := ItemTypes.ground_icon_path(ItemTypes.LOGS)
	assert_eq(pile.texture.resource_path, ArtSet.path(path))
	assert_ne(pile.texture.resource_path, path, "classic art")
	ArtSet.show(false, get_tree())
	assert_eq(pile.texture.resource_path, path)


func _is_pile(node: Node) -> bool:
	return node is Sprite2D and "/ground_items/" in node.texture.resource_path
