extends GutTest
## The room the player is in shows the villagers who are inside that building (#8), where they
## stand in it, and only them.

var _npcs: Npcs
var _entities: Node2D
var _views: InteriorNpcViews
var _house: Building
var _other: Building


func before_each() -> void:
	_npcs = Npcs.new(Sun.new())
	_entities = Node2D.new()
	add_child_autofree(_entities)
	_views = InteriorNpcViews.new()
	add_child_autofree(_views)
	_views.show_npcs(_npcs, _entities)
	_house = Building.new(BuildingTypes.KATE, Vector2i(10, 10))
	_other = Building.new(BuildingTypes.KATE, Vector2i(20, 10))


func _villager_in(building: Building) -> Npc:
	var npc := Npc.create(1, building.yard(), _npcs.rules)
	npc.inside = building
	npc.inside_position = Vector2(3.5, 4.5)
	_npcs.add(npc)
	building.inside()
	return npc


func _view_of(npc: Npc) -> NpcView:
	for child in _entities.get_children():
		if child is NpcView and child.npc == npc:
			return child
	return null


func test_the_room_shows_the_villagers_inside_its_building() -> void:
	var npc := _villager_in(_house)
	_villager_in(_other)
	_views.show_room(_house.inside())
	assert_eq(_entities.get_child_count(), 1)
	assert_not_null(_view_of(npc))


func test_a_villager_is_drawn_where_they_stand_in_the_room() -> void:
	var npc := _villager_in(_house)
	_views.show_room(_house.inside())
	assert_eq(_view_of(npc).position, Vector2(3.5, 4.5) * TerrainTileset.TILE_SIZE)


func test_no_room_shows_no_one() -> void:
	_villager_in(_house)
	_views.show_room(null)
	assert_eq(_entities.get_child_count(), 0)


func test_leaving_the_room_takes_the_views_away() -> void:
	_villager_in(_house)
	_views.show_room(_house.inside())
	_views.show_room(null)
	await get_tree().process_frame
	assert_eq(_entities.get_child_count(), 0)


func test_one_who_comes_out_while_the_player_is_there_goes() -> void:
	var npc := _villager_in(_house)
	_views.show_room(_house.inside())
	npc.inside = null
	_views._process(0.0)
	await get_tree().process_frame
	assert_eq(_entities.get_child_count(), 0)


func test_one_who_goes_in_while_the_player_is_there_appears() -> void:
	var npc := _villager_in(_house)
	npc.inside = null
	_views.show_room(_house.inside())
	assert_eq(_entities.get_child_count(), 0)
	npc.inside = _house
	_views._process(0.0)
	assert_eq(_entities.get_child_count(), 1)


func test_a_villager_who_leaves_the_world_goes_from_the_room() -> void:
	var npc := _villager_in(_house)
	_views.show_room(_house.inside())
	_npcs.remove(npc)
	await get_tree().process_frame
	assert_eq(_entities.get_child_count(), 0)


func test_a_view_follows_the_villager_walking_about_the_room() -> void:
	var npc := _villager_in(_house)
	_views.show_room(_house.inside())
	npc.inside_position = Vector2(5.5, 4.5)
	_view_of(npc)._process(0.0)
	assert_eq(_view_of(npc).position, Vector2(5.5, 4.5) * TerrainTileset.TILE_SIZE)
