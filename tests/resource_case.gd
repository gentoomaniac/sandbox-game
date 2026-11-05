class_name ResourceCase
extends GutTest
## What the tests of felling, mining and foraging share: a game with a patch of grass in front
## of the player, and helpers to put objects there and let days pass.

const SEED := 7
## Tiles around the camp that are searched for a spot with grass in front of the player.
const SEARCH := 6
const MIDSUMMER := 45

var _state: GameState
var _world: World
var _tile: Vector2i


func before_each() -> void:
	_state = GameState.new_game(SEED)
	_world = _state.world
	_tile = _grass_tile()
	_state.player.position = Vector2(_tile) + Vector2(0.5, 0.5) - Vector2(0, 1)
	_state.player.facing = Vector2i.DOWN


## Clears the row of the tile of what stands on it, two tiles to each side, and makes it grass:
## room for the trunk of a felled tree.
func _make_room() -> void:
	for x in range(-2, 3):
		var pos := _tile + Vector2i(x, 0)
		if pos != _tile:
			_world.remove_object(pos)
		_world.set_terrain(pos, Tile.Terrain.GRASS)


## Berry bushes bear and ferns stand, whatever their thresholds.
func _set_midsummer() -> void:
	_state.clock.day = MIDSUMMER


func _grass_tile() -> Vector2i:
	var center := _state.player.tile()
	for y in range(-SEARCH, SEARCH):
		for x in range(-SEARCH, SEARCH):
			var pos := center + Vector2i(x, y + 1)
			if (
				_world.is_free_on(pos, Tile.Terrain.GRASS)
				and _world.is_free_on(pos - Vector2i(0, 1), Tile.Terrain.GRASS)
			):
				return pos
	fail_test("no grass near the camp")
	return center


func _hold(item: StringName) -> void:
	var inventory := _state.player.inventory
	for slot in Inventory.HOTBAR_SIZE:
		if inventory.item_in(slot) == item:
			inventory.select(slot)
			return
	inventory.add(item, 1)
	_hold(item)


func _place(type: StringName, tree := "") -> WorldObject:
	var object := WorldObject.new(type, _tile)
	if tree != "":
		object.state["tree"] = tree
	_world.add_object(object)
	return object


## Uses the tile in front of the player `times` times with `tool_item`; returns the last use.
func _hit(tool_item: StringName, times: int) -> GameState.Use:
	_hold(tool_item)
	var use := GameState.Use.NOTHING
	for _i in times:
		use = _state.use_facing_tile()
	return use


func _sleep_days(days: int) -> void:
	for _i in days:
		_state.clock.advance(GameClock.MINUTES_PER_DAY)


## Unloads the chunk of the tile and generates it again, as walking away and back does.
func _reload_chunk() -> void:
	var coords := Chunk.world_to_chunk(_tile)
	_world.remove_chunk(coords)
	_world.add_chunk(WorldGenerator.new(SEED).generate_chunk(coords))


## The game saved and loaded, with the chunks that are loaded now and that of the tile.
func _through_save() -> GameState:
	var restored := GameState.from_dict(JSON.parse_string(JSON.stringify(_state.to_dict())))
	var to_load := _world.loaded_chunk_coords()
	if not to_load.has(Chunk.world_to_chunk(_tile)):
		to_load.append(Chunk.world_to_chunk(_tile))
	for coords in to_load:
		restored.world.add_chunk(WorldGenerator.new(SEED).generate_chunk(coords))
	return restored


func _count(item: StringName) -> int:
	return _state.player.inventory.count_of(item)


func _dropped(item: StringName) -> int:
	return _world.ground_count_of(item)


func _clear_ground() -> void:
	for ground_item in _world.ground_items():
		_world.remove_ground_item(ground_item)


## Fills every slot but the selected one.
func _fill_inventory() -> void:
	for slot in Inventory.SLOT_COUNT:
		if (
			slot != _state.player.inventory.selected_slot
			and _state.player.inventory.slots[slot].is_empty()
		):
			_state.player.inventory.slots[slot] = {"item": ItemTypes.TURNIP, "count": 99}
