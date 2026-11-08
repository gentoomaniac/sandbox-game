extends GutTest
## The pictures of riding: the columns of the ridden horse, a riding sheet for every layer the
## player can wear, and the ridden horse's sheets of every look.


func test_a_ridden_horse_stands_walks_or_trots() -> void:
	assert_eq(PlayerView.ride_column(false, true, 3.0), PlayerView.RIDE_IDLE_COLUMN)
	var step := 1.0 / PlayerView.RIDE_FRAMES_PER_SECOND
	var walk := []
	var trot := []
	for i in PlayerView.RIDE_WALK_COLUMNS.size():
		walk.append(PlayerView.ride_column(true, false, (i + 0.5) * step))
		trot.append(PlayerView.ride_column(true, true, (i + 0.5) * step))
	assert_eq(walk, PlayerView.RIDE_WALK_COLUMNS)
	assert_eq(trot, PlayerView.RIDE_TROT_COLUMNS)


func test_every_layer_the_player_wears_has_a_riding_sheet() -> void:
	for item: StringName in ItemTypes.TYPES:
		if ItemTypes.TYPES[item].has("layer_variant"):
			var slot: StringName = Appearance.LAYER_OF_EQUIPMENT_SLOT[Equipment.slot_of(item)]
			_assert_riding_sheet({slot = slot, variant = ItemTypes.TYPES[item]["layer_variant"]})
	for hair in PlayerView.HAIR_COUNT:
		_assert_riding_sheet({slot = Appearance.HAIR, variant = str(hair)})
	_assert_riding_sheet({slot = Appearance.BODY, variant = "0"})


func _assert_riding_sheet(layer: Dictionary) -> void:
	var texture: Texture2D = load(Appearance.riding_sheet_path(layer))
	assert_not_null(texture, Appearance.riding_sheet_path(layer))
	if texture != null:
		assert_eq(
			texture.get_size(), Vector2(TerrainTileset.TILE_SIZE, PlayerView.FRAME_HEIGHT * 4)
		)


func test_every_horse_look_has_its_ridden_sheets() -> void:
	var size: Vector2i = WildlifeSprites.HORSE["size"]
	var sheet_size := Vector2(
		size.x * PlayerView.RIDE_COLUMNS, size.y * PlayerView.FACING_ROWS.size()
	)
	for look: String in LivestockRules.default_rules().looks(LivestockRules.HORSE):
		for part in ["", "_over"]:
			var texture: Texture2D = load(PlayerView.RIDDEN_HORSE_PATH % [look, part])
			assert_eq(texture.get_size(), sheet_size, look + part)
