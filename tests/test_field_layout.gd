extends GutTest
## The fields the land is cut into, and what the generator makes of their boundaries: Knicks,
## walls and fences on the Geest, dykes along the floodplain, and gaps that keep every field open.

const SEED := 42
## An area of the plain field layout, flood-filled from a corner: the fields inside the inner
## area must all be reached.
const AREA := Rect2i(-120, -120, 240, 240)
const INNER := Rect2i(-80, -80, 160, 160)

var _layout := FieldLayout.new(SEED)


func test_the_same_seed_gives_the_same_fields_and_another_seed_others() -> void:
	var other := FieldLayout.new(SEED + 1)
	var again := FieldLayout.new(SEED)
	var differs := false
	for y in range(-40, 40):
		for x in range(-40, 40):
			var pos := Vector2i(x, y)
			assert_eq(again.boundary_at(pos), _layout.boundary_at(pos), str(pos))
			differs = differs or other.boundary_at(pos) != _layout.boundary_at(pos)
	assert_true(differs)


func test_a_covered_area_answers_as_the_layout_does() -> void:
	var covered := FieldLayout.new(SEED)
	covered.cover(Rect2i(-20, -20, 40, 40))
	for y in range(-30, 30):
		for x in range(-30, 30):
			var pos := Vector2i(x, y)
			assert_eq(covered.boundary_at(pos), _layout.boundary_at(pos), str(pos))


func test_the_boundaries_have_every_kind_in_about_its_share() -> void:
	var counts := {}
	for y in range(AREA.position.y, AREA.end.y):
		for x in range(AREA.position.x, AREA.end.x):
			var boundary := _layout.boundary_at(Vector2i(x, y))
			counts[boundary] = counts.get(boundary, 0) + 1
	var tiles := float(AREA.get_area())
	assert_between(counts[WorldObjectTypes.KNICK] / tiles, 0.05, 0.15)
	assert_gt(counts[WorldObjectTypes.STONE_WALL], 100)
	assert_gt(counts[WorldObjectTypes.WATTLE_FENCE], 100)
	assert_gt(counts[FieldLayout.GAP], 100)


func test_a_gap_has_the_boundary_on_two_sides_and_free_tiles_on_the_others() -> void:
	for y in range(INNER.position.y, INNER.end.y):
		for x in range(INNER.position.x, INNER.end.x):
			var pos := Vector2i(x, y)
			if _layout.boundary_at(pos) != FieldLayout.GAP:
				continue
			var east_west := _is_on_boundary(pos + Vector2i.LEFT)
			assert_eq(_is_on_boundary(pos + Vector2i.RIGHT), east_west, str(pos))
			assert_ne(_is_on_boundary(pos + Vector2i.UP), east_west, str(pos))
			assert_ne(_is_on_boundary(pos + Vector2i.DOWN), east_west, str(pos))


func test_no_field_is_shut_in() -> void:
	var reached := {AREA.position: true}
	var queue: Array[Vector2i] = [AREA.position]
	while not queue.is_empty():
		var pos: Vector2i = queue.pop_back()
		for side in World.CONNECTION_SIDES:
			var next: Vector2i = pos + side
			if AREA.has_point(next) and not reached.has(next) and not _is_on_boundary(next):
				reached[next] = true
				queue.append(next)
	for y in range(INNER.position.y, INNER.end.y):
		for x in range(INNER.position.x, INNER.end.x):
			var pos := Vector2i(x, y)
			if not _is_on_boundary(pos):
				assert_true(reached.has(pos), "shut in at %s" % pos)
				if not reached.has(pos):
					return


func _is_on_boundary(pos: Vector2i) -> bool:
	var boundary := _layout.boundary_at(pos)
	return boundary != &"" and boundary != FieldLayout.GAP


# --- What the generator makes of them ---


func test_the_geest_has_knicks_walls_and_fences_and_the_floodplain_dykes() -> void:
	var generator := WorldGenerator.new(SEED)
	var seen := {}
	for y in range(-200, 200, 2):
		for x in range(-100, 100):
			var pos := Vector2i(x, y)
			var terrain := generator.terrain_at(pos)
			var object_type := generator.object_type_at(pos, terrain)
			if object_type in LandscapeRules.default_rules().kind_shares():
				assert_false(generator._is_marsh(pos), "%s in the marsh at %s" % [object_type, pos])
				assert_eq(terrain, Tile.Terrain.GRASS, str(pos))
				seen[object_type] = true
			if object_type == WorldObjectTypes.DYKE:
				assert_true(generator._river_distance(pos) < WorldGenerator.DYKE_PROBE_DISTANCE)
				seen[object_type] = true
	for kind in [
		WorldObjectTypes.KNICK,
		WorldObjectTypes.STONE_WALL,
		WorldObjectTypes.WATTLE_FENCE,
		WorldObjectTypes.DYKE,
	]:
		assert_true(seen.has(kind), "no %s" % kind)


func test_a_gap_and_the_tiles_beside_it_can_be_walked_through() -> void:
	var generator := WorldGenerator.new(SEED)
	var gaps := 0
	for y in range(INNER.position.y, INNER.end.y):
		for x in range(INNER.position.x, INNER.end.x):
			var pos := Vector2i(x, y)
			if _layout.boundary_at(pos) != FieldLayout.GAP:
				continue
			gaps += 1
			for offset: Vector2i in [Vector2i.ZERO] + World.CONNECTION_SIDES:
				var tile := pos + offset
				if _is_on_boundary(tile):
					continue
				var terrain := generator.terrain_at(tile)
				var object_type := generator.object_type_at(tile, terrain)
				assert_true(
					object_type == &"" or not WorldObjectTypes.TYPES[object_type]["blocks_walking"],
					"%s blocks at %s" % [object_type, tile]
				)
	assert_gt(gaps, 50)
