extends ResourceCase
## The pull of the piles on the ground towards the player: not through what stops walking.

const FRAME := 1.0 / 60.0


func before_each() -> void:
	super.before_each()
	_make_room()


## A pile lying at `offset` from the player, as if it had been dropped there.
func _lay(item: StringName, count: int, offset: Vector2) -> GroundItem:
	var ground_item := GroundItem.new(item, count, _state.player.position + offset)
	_world.ground_items.add(ground_item)
	return ground_item


func _walk_frames(frames: int) -> void:
	for _i in frames:
		GroundPickup.collect(_state, FRAME)


## Puts the player at the right edge of their tile, so a pile 1.2 tiles on lies two tiles over, and
## `blocker` (an object type, if any) and the given terrain on the tile between. Returns the pile.
func _lay_pile_behind(blocker: StringName, terrain := Tile.Terrain.GRASS) -> GroundItem:
	var player_tile := _state.player.tile()
	_state.player.position = Vector2(player_tile) + Vector2(0.95, 0.5)
	for x in range(0, 3):
		_world.set_terrain(player_tile + Vector2i(x, 0), Tile.Terrain.GRASS)
		_world.remove_object(player_tile + Vector2i(x, 0))
	var between := player_tile + Vector2i.RIGHT
	_world.set_terrain(between, terrain)
	if blocker != &"":
		_world.add_object(WorldObject.new(blocker, between))
	return _lay(ItemTypes.LOGS, 1, Vector2(1.2, 0))


func test_a_pile_behind_a_blocked_tile_is_not_pulled() -> void:
	var behind := _lay_pile_behind(WorldObjectTypes.STONE)
	var spot := behind.position
	_walk_frames(30)
	assert_eq(behind.position, spot)
	assert_eq(_count(ItemTypes.LOGS), 0)


func test_a_pile_behind_water_is_not_pulled() -> void:
	var behind := _lay_pile_behind(&"", Tile.Terrain.WATER)
	var spot := behind.position
	_walk_frames(30)
	assert_eq(behind.position, spot)


func test_a_pile_over_walkable_ground_is_pulled_past_the_edge_of_a_tile() -> void:
	_lay_pile_behind(&"")
	_walk_frames(30)
	assert_eq(_count(ItemTypes.LOGS), 1)
