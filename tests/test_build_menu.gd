extends ClickCase
## The build menu above the hotbar: a row of the buildings, the chosen one's other styles in a
## column above it, and a click that picks without reaching the land under the menu.


## Counts the clicks that get past the menu to the game (BuildMode takes them unhandled).
class ClickCounter:
	extends Node

	var clicks := 0

	func _unhandled_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed:
			clicks += 1


var _state: GameState
var _builder: Builder
var _menu: BuildMenu


func before_each() -> void:
	_make_window()
	_state = GameState.new_game(1)
	_builder = Builder.new(_state)
	_builder.select_hammer()
	_menu = BuildMenu.new()
	_window.add_child(_menu)
	_menu.bind(_builder, _state.player.inventory)
	await get_tree().process_frame


func _cell(building: StringName, style: StringName) -> Control:
	return _menu._cells[building][style]


func _click(position: Vector2) -> void:
	for is_pressed in [true, false]:
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = is_pressed
		click.position = position
		_window.push_input(click)


func test_only_the_chosen_buildings_other_styles_stand_in_a_column_above_it() -> void:
	_builder.choose(BuildingTypes.SHACK)
	await get_tree().process_frame
	assert_false(_cell(BuildingTypes.KATE, &"brick").is_visible_in_tree())
	_builder.choose(BuildingTypes.KATE)
	await get_tree().process_frame
	var kate := _cell(BuildingTypes.KATE, &"").get_global_rect()
	var brick := _cell(BuildingTypes.KATE, &"brick").get_global_rect()
	var geest := _cell(BuildingTypes.KATE, &"geest").get_global_rect()
	assert_true(_cell(BuildingTypes.KATE, &"brick").is_visible_in_tree())
	assert_lt(brick.end.y, kate.position.y, "the first style just above the row")
	assert_lt(geest.end.y, brick.position.y)
	assert_eq(brick.position.x, kate.position.x)
	assert_false(_menu._columns.has(BuildingTypes.SHACK), "one style: no column")


func test_a_click_on_a_cell_picks_its_building_and_style_and_does_not_reach_the_land() -> void:
	var counter := ClickCounter.new()
	_window.add_child(counter)
	_click(_cell(BuildingTypes.BARN, &"").get_global_rect().get_center())
	assert_eq(_builder.choice, BuildingTypes.BARN)
	_builder.choose(BuildingTypes.KATE)
	await get_tree().process_frame
	_click(_cell(BuildingTypes.KATE, &"geest").get_global_rect().get_center())
	assert_eq([_builder.choice, _builder.style], [BuildingTypes.KATE, &"geest"])
	assert_eq(counter.clicks, 0)
	_click(Vector2(320, 20))
	assert_eq(counter.clicks, 1, "a click away from the menu is the game's")


func _is_lit(cell: Control) -> bool:
	return cell.get_theme_stylebox("panel") == _menu._chosen_box


func test_picking_with_the_keys_lights_the_cell_and_shows_its_style_in_the_preview() -> void:
	_builder.choose(BuildingTypes.FISHER_HUT)
	_builder.pick(1)
	_builder.pick_style(1)
	await get_tree().process_frame
	assert_true(_is_lit(_cell(BuildingTypes.KATE, &"brick")))
	assert_false(_is_lit(_cell(BuildingTypes.KATE, &"")))
	assert_false(_is_lit(_cell(BuildingTypes.FISHER_HUT, &"")))
	assert_eq(_menu._preview_name.text, "Brick Kate")


func test_a_material_that_is_short_is_marked_and_one_carried_is_not() -> void:
	_builder.choose(BuildingTypes.SHACK)
	_state.player.inventory.add(ItemTypes.LOGS, 20)
	await get_tree().process_frame
	var texts: Array = (
		_menu
		. _material_labels
		. filter(func(label: Label) -> bool: return label.visible)
		. map(func(label: Label) -> String: return label.text)
	)
	assert_eq(texts, ["Logs 20/20", "Stone 0/5 !"])


func test_taking_down_puts_the_row_away() -> void:
	_builder.toggle_taking_down()
	await get_tree().process_frame
	assert_false(_cell(BuildingTypes.SHACK, &"").is_visible_in_tree())
	_builder.toggle_taking_down()
	await get_tree().process_frame
	assert_true(_cell(BuildingTypes.SHACK, &"").is_visible_in_tree())


func test_why_a_spot_is_refused_shows_beside_the_mouse_not_in_the_preview() -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = Vector2(100, 50)
	_window.push_input(motion)
	_menu.show_message("This land doesn't look safe to build on.")
	await get_tree().process_frame
	assert_true(_menu._note.is_visible_in_tree())
	assert_false(_menu._preview.is_ancestor_of(_menu._message))
	assert_eq(_menu._note.position, Vector2(100, 50) + BuildMenu.NOTE_OFFSET)
	motion = InputEventMouseMotion.new()
	motion.position = Vector2(140, 60)
	_window.push_input(motion)
	await get_tree().process_frame
	assert_eq(_menu._note.position, Vector2(140, 60) + BuildMenu.NOTE_OFFSET, "it follows")
	_menu.show_message("")
	assert_false(_menu._note.visible)
