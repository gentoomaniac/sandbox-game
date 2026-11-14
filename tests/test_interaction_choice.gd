extends ResourceCase
## What E does (Interaction `choice_at`): the first of the villager, the horse, the chest or
## station, the bell frame and the bed that applies, and getting off on horseback.


func _kind() -> Interaction.Kind:
	return Interaction.choice_at(_state, _tile).kind


func test_e_does_nothing_with_nothing_in_reach() -> void:
	assert_eq(_kind(), Interaction.Kind.NOTHING)


func test_e_speaks_to_a_villager_before_anything_else() -> void:
	var npc := Npc.create(5, Vector2(_tile) + Vector2(0.5, 0.5), _state.npcs.rules)
	_state.npcs.add(npc)
	_place(WorldObjectTypes.CHEST)
	var choice := Interaction.choice_at(_state, _tile)
	assert_eq(choice.kind, Interaction.Kind.CHAT)
	assert_eq(choice.subject, npc)


func test_e_gets_on_a_saddled_horse_before_a_chest() -> void:
	var horse := FarmAnimal.new(LivestockRules.HORSE, &"bay", Vector2(_tile) + Vector2(0.5, 0.5))
	horse.is_saddled = true
	_state.livestock.add(horse)
	_place(WorldObjectTypes.CHEST)
	var choice := Interaction.choice_at(_state, _tile)
	assert_eq(choice.kind, Interaction.Kind.MOUNT)
	assert_eq(choice.subject, horse)


func test_e_opens_a_chest_a_crafting_station_and_a_process_station() -> void:
	var kinds := {
		WorldObjectTypes.CHEST: Interaction.Kind.OPEN_CHEST,
		WorldObjectTypes.FIREPLACE: Interaction.Kind.OPEN_CRAFTING,
		WorldObjectTypes.KILN: Interaction.Kind.OPEN_STATION_GRID,
	}
	for type: StringName in kinds:
		_world.remove_object(_tile)
		var object := _place(type)
		var choice := Interaction.choice_at(_state, _tile)
		assert_eq(choice.kind, kinds[type], str(type))
		assert_eq(choice.subject, object, str(type))


func test_e_rings_a_bell_frame_in_reach() -> void:
	var frame := _place_building_nearby(BuildingTypes.BELL_FRAME)
	var beside := TerrainTileset.tile_centre(frame.origin + Vector2i(-1, 0))
	_state.player.position = beside / TerrainTileset.TILE_SIZE
	var choice := Interaction.choice_at(_state, _state.player.facing_tile())
	assert_eq(choice.kind, Interaction.Kind.RING_BELL)
	assert_eq(choice.subject, frame)


func test_e_sleeps_in_a_bed_in_reach() -> void:
	var bag := _place(WorldObjectTypes.SLEEPING_BAG)
	var choice := Interaction.choice_at(_state, _tile + Vector2i(0, 1))
	assert_eq(choice.kind, Interaction.Kind.SLEEP)
	assert_eq(choice.subject, bag)


func test_e_on_horseback_gets_off_whatever_is_around() -> void:
	_place(WorldObjectTypes.CHEST)
	_state.player.horse = FarmAnimal.new(LivestockRules.HORSE, &"bay", _state.player.position)
	assert_eq(_kind(), Interaction.Kind.DISMOUNT)
