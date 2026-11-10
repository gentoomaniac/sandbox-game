extends GutTest
## The snapshot of a save (SaveFile `snapshot`): the game of its moment, copied so that nothing
## the game does afterwards reaches it, and made into the save of that moment by a thread.

const SEED := 7

var _state: GameState
var _world: World
## The tiles the game is lived in at the start: soil with a crop, a chest, a tree to fell.
var _field: Vector2i
var _chest: WorldObject
var _tree: WorldObject
var _pile: GroundItem
var _villager: Npc
var _animal: FarmAnimal


func before_each() -> void:
	_state = GameState.new_game(SEED)
	_world = _state.world
	var middle := _state.player.tile()
	var generator := WorldGenerator.new(SEED)
	for coords in [Chunk.world_to_chunk(middle), Chunk.world_to_chunk(middle + Vector2i(40, 0))]:
		if not _world.is_chunk_loaded(coords):
			_world.add_chunk(generator.generate_chunk(coords))
	_live_in_the_game()


func _free_tile(index: int) -> Vector2i:
	var around := _state.player.tile()
	var found := 0
	for x in range(2, 30):
		var pos := around + Vector2i(x, 0)
		if _world.is_free_on(pos, Tile.Terrain.GRASS):
			if found == index:
				return pos
			found += 1
	fail_test("no free tile")
	return around


## A game with something of every kind in it: soil, a crop, wet soil, a felled tree, a chest with
## items, piles on the ground, a worn and a dug tile, a villager with a chat, an animal.
func _live_in_the_game() -> void:
	_field = _free_tile(0)
	_world.set_terrain(_field, Tile.Terrain.SOIL)
	var crop := WorldObject.new(WorldObjectTypes.TURNIP, _field)
	crop.state["growth"] = 2.0
	_world.add_object(crop)
	_world.set_moisture(_field, 0.4)
	_chest = WorldObject.new(WorldObjectTypes.CHEST, _free_tile(1))
	_chest.storage.add(ItemTypes.TURNIP, 5)
	_world.add_object(_chest)
	_tree = WorldObject.new(WorldObjectTypes.OAK, _free_tile(2))
	_tree.state["damage"] = 1.0
	_world.add_object(_tree)
	_pile = GroundItem.new(ItemTypes.STONE, 3, Vector2(_free_tile(3)) + Vector2(0.3, 0.6))
	_world.ground_items.add(_pile)
	_world.wear_tile(_free_tile(4), 2.0)
	_world.spend_clay_spot(_free_tile(5))
	_villager = Npc.create(3, Vector2(_free_tile(6)), _state.npcs.rules)
	_villager.add_chat_line(1, 400, true, "hello")
	_state.npcs.add(_villager)
	_state.livestock.spawn(LivestockRules.COW, 1, Vector2(_free_tile(7)), _world)
	_animal = _state.livestock.all()[0]
	_state.player.inventory.add(ItemTypes.TURNIP, 2)


## Changes at least one thing of every kind the snapshot holds, by the ways the game does.
func _change_everything() -> void:
	_world.set_terrain(_free_tile(8), Tile.Terrain.SOIL)
	_world.set_terrain(_field, Tile.Terrain.GRASS)
	_world.remove_object(_tree.pos)
	_world.add_object(WorldObject.new(WorldObjectTypes.STONE, _free_tile(9)))
	_chest.storage.add(ItemTypes.LOGS, 7)
	_chest.storage.remove(ItemTypes.TURNIP, 5)
	_world.remove_object(_field)
	_world.set_moisture(_field, 0.9)
	_pile.count = 9
	_world.ground_items.move(_pile, _pile.position + Vector2(1, 1))
	_world.ground_items.add(GroundItem.new(ItemTypes.LOGS, 1, Vector2(_free_tile(10))))
	_world.wear_tile(_free_tile(4), 3.0)
	_world.recover_clay_spots()
	_world.spend_clay_spot(_free_tile(11))
	_villager.add_chat_line(1, 401, false, "and more")
	_villager.position += Vector2(1, 1)
	_villager.memories.append("a memory")
	_animal.position += Vector2(2, 2)
	_state.player.inventory.add(ItemTypes.LOGS, 4)
	_state.player.position += Vector2(3, 3)
	_state.clock.advance(125)
	_state.livestock.spawn(LivestockRules.SHEEP, 1, Vector2(_free_tile(12)), _world)


func test_what_the_game_does_after_a_snapshot_does_not_reach_it() -> void:
	var before := JSON.stringify(_state.to_dict(), "\t")
	var snapshot := SaveFile.snapshot(_state)
	var game_before := _state.to_dict()

	_change_everything()

	var game_after := _state.to_dict()
	for part in ["clock", "player", "livestock", "npcs"]:
		assert_true(game_after[part] != game_before[part], "%s changed" % part)
	for part in game_before["world"]:
		if part != "seed" and part != "buildings":
			assert_true(
				game_after["world"][part] != game_before["world"][part], "%s changed" % part
			)
	var snapshot_text := SaveFile.text_of(snapshot)
	var snapshot_game: Dictionary = JSON.parse_string(snapshot_text)["game"]
	assert_eq(snapshot_game, JSON.parse_string(before), "the snapshot is the game of its moment")


func test_a_snapshot_of_the_game_of_an_hour_later_has_the_soil_as_of_then() -> void:
	var first := SaveFile.snapshot(_state)
	_state.simulation.advance(6 * GameClock.MINUTES_PER_HOUR)
	var second := SaveFile.snapshot(_state)

	var moisture_first: float = _moisture_in(first, _field)
	var moisture_second: float = _moisture_in(second, _field)

	assert_ne(moisture_first, moisture_second, "six hours changed the soil")
	assert_almost_eq(moisture_second, _world.moisture_at(_field), 0.0001)


func _moisture_in(snapshot: Dictionary, tile: Vector2i) -> float:
	var entries: Array = World.dict_of(snapshot["game"]["world"])["soil_moisture"]
	for entry: Array in entries:
		if SaveCodec.vector_from_json(entry) == tile:
			return entry[2]
	fail_test("no moisture saved for %s" % tile)
	return -1.0
