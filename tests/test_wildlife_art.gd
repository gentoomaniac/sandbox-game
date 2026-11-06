extends GutTest
## The wildlife and livestock sheets agree with the layout the code expects, and the console can
## spawn.


func test_every_sheet_has_a_cell_per_frame_of_every_action() -> void:
	for kind: StringName in WildlifeSprites.SHEETS:
		var sheet: Dictionary = WildlifeSprites.SHEETS[kind]
		var size: Vector2i = sheet["size"]
		var texture: Texture2D = load(WildlifeSprites.SHEET_PATH % kind)
		assert_eq(texture.get_width(), size.x * WildlifeSprites.max_frames(kind), kind)
		assert_eq(texture.get_height(), size.y * sheet["actions"].size(), kind)


## The flocks show birds and geese, and a stork on a roof is a stork.
func test_every_kind_shows_a_sheet() -> void:
	var sheets_of_others := {
		WildlifeRules.FLOCK: WildlifeRules.BIRD,
		WildlifeRules.ROOF_STORK: WildlifeRules.STORK,
		WildlifeRules.GEESE: GooseFlock.SHEET,
		WildlifeRules.FLYING_GEESE: GooseFlock.SHEET,
	}
	for kind in WildlifeRules.KINDS:
		assert_true(WildlifeSprites.SHEETS.has(sheets_of_others.get(kind, kind)), kind)


func test_every_look_of_every_farm_animal_has_a_sheet() -> void:
	var rules := LivestockRules.default_rules()
	for species in LivestockRules.SPECIES:
		for look: String in rules.looks(species):
			assert_true(WildlifeSprites.SHEETS.has(StringName("%s_%s" % [species, look])), look)


func test_the_spawn_command_asks_for_animals() -> void:
	var state := GameState.new_game(1)
	var console := Console.new(state)
	assert_eq(console.run("spawn deer 2"), ["No animals here"])
	var asked := []
	console.wildlife_spawner = func(kind: StringName, count: int) -> int:
		asked.append([kind, count])
		return count
	assert_eq(console.run("spawn deer 2"), ["Spawned 2 of 2 deer"])
	assert_eq(asked, [[&"deer", 2]])
	assert_eq(console.run("spawn dragon")[0], "Unknown animal: dragon")
	assert_eq(console.run("spawn deer many"), ["Usage: spawn <kind> [count]"])
	assert_eq(console.complete("spawn dee"), "spawn deer ")
