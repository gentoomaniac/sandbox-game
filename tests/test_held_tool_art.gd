extends GutTest
## The pictures of the tools in the hand: every tool has a held sheet, in the cells of the
## character's sheets, in both art sets.

const BODY := "res://assets/character/body_0.png"


func after_each() -> void:
	ArtSet.is_classic = false


func test_every_tool_has_a_held_sheet() -> void:
	for tool in _tools():
		var held_sheet: Variant = ItemTypes.TYPES[tool].get("held_sheet")
		assert_not_null(held_sheet, str(tool))
		if held_sheet != null:
			assert_true(ResourceLoader.exists(_sheet_path(tool)), str(tool))


func test_every_held_sheet_has_the_cells_of_the_body_sheet() -> void:
	for is_classic in [false, true]:
		ArtSet.is_classic = is_classic
		var body: Texture2D = load(ArtSet.path(BODY))
		for tool in _tools():
			if ItemTypes.TYPES[tool].has("held_sheet"):
				var sheet: Texture2D = load(ArtSet.path(_sheet_path(tool)))
				assert_eq(sheet.get_size(), body.get_size(), "%s, classic: %s" % [tool, is_classic])


func _tools() -> Array[StringName]:
	var tools: Array[StringName] = []
	for item: StringName in ItemTypes.TYPES:
		if ItemTypes.TYPES[item].has("tool"):
			tools.append(item)
	return tools


func _sheet_path(tool: StringName) -> String:
	var variant: String = ItemTypes.TYPES[tool]["held_sheet"]
	return Appearance.sheet_path({slot = Appearance.HELD, variant = variant})
