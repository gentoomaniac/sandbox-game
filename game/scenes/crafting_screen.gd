class_name CraftingScreen
extends Modal
## The crafting menu over the game: a panel with a row for every recipe of one place (see
## RecipeRow). C opens it for the recipes made by hand; E on a station opens it for that station's
## recipes, under the station's name and the player's points in the skills they practise. A click
## on a row the player can make crafts it, and a note says what the craft taught. A process station
## (the kiln, the oven) has its own window instead (ProcessScreen). Like the character screen, it
## takes the input while it is open (Main sees to that, and closes it on C and E; Escape is the
## Modal's).

const DROPPED_NOTE := "Inventory full: the rest was dropped on the ground"
const NO_STATION_NOTE := "Too far from the station"
const WRONG_STATION_NOTE := "Made at the %s"
const HAND_TITLE := "Crafting"
const NOTHING_NOTE := "Nothing to make here yet."
const AT_CAP_NOTE := "%s is held at the skill cap: let a skill fade (K)."
const LEARNT_ALL_NOTE := "This teaches you no more %s."

var _crafting: Crafting
var _inventory: Inventory
## The station whose recipes are shown, or null for those made by hand.
var _station: WorldObject
var _title_label := Label.new()
var _skills_label := Label.new()
var _rows_column := VBoxContainer.new()
var _rows: Array[RecipeRow] = []
var _note_label := Label.new()


func _init() -> void:
	super()
	close_actions = [&"interact"]
	var column := VBoxContainer.new()
	for label in [_title_label, _skills_label]:
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		column.add_child(label)
	column.add_child(_scrolling(_rows_column))
	column.add_child(_note_label)
	_panel.add_child(column)


## Showing the crafting of another game lets go of the old one's.
func show_crafting(crafting: Crafting, inventory: Inventory) -> void:
	if _crafting != null:
		close()
		_inventory.changed.disconnect(_refresh)
		_crafting.practised.disconnect(_on_practised)
		_crafting.player_skills().changed.disconnect(_refresh)
	_crafting = crafting
	_inventory = inventory
	inventory.changed.connect(_refresh)
	crafting.practised.connect(_on_practised)
	crafting.player_skills().changed.connect(_refresh)
	_show_recipes()


## Opens the menu of `station` (an object that is a station, see StationRules); `open()` opens
## that of the recipes made by hand.
func open_station(station: WorldObject) -> void:
	close()
	_station = station
	open()


func _on_open() -> void:
	_show_recipes()
	_show_note(NOTHING_NOTE if _rows.is_empty() else "")
	_refresh()


func _on_close() -> void:
	_station = null


func _station_id() -> StringName:
	return &"" if _station == null else StationRules.default_rules().station_of(_station.type)


## Builds the rows of the place the menu is open for.
func _show_recipes() -> void:
	for row in _rows:
		row.free()
	_rows.clear()
	var station := _station_id()
	_title_label.text = (
		HAND_TITLE if station == &"" else StationRules.default_rules().station_name(station)
	)
	for recipe_id in _crafting.rules.recipes_at(station):
		var row := RecipeRow.new(recipe_id, _crafting, _inventory)
		row.pressed.connect(_craft.bind(recipe_id))
		_rows_column.add_child(row)
		_rows.append(row)


func _craft(recipe_id: StringName) -> void:
	_show_note("")
	match _crafting.craft(recipe_id, _station):
		Crafting.Result.DROPPED:
			_show_note(DROPPED_NOTE)
		Crafting.Result.NO_STATION:
			_show_note(NO_STATION_NOTE)
		Crafting.Result.WRONG_STATION:
			var kind := _crafting.rules.station_of(recipe_id)
			_show_note(WRONG_STATION_NOTE % StationRules.default_rules().station_name(kind))
	_refresh()


func _on_practised(skill: StringName, gained: float, wanted: float) -> void:
	_show_note(practised_note(_crafting.player_skills(), skill, gained, wanted))


## What a craft taught: "+2.0 Masonry", or why it taught less than it would.
static func practised_note(
	skills: Skills, skill: StringName, gained: float, wanted: float
) -> String:
	var skill_name := skills.rules.skill_name(skill)
	if wanted == 0.0:
		return LEARNT_ALL_NOTE % skill_name.to_lower()
	if gained < wanted:
		return AT_CAP_NOTE % skill_name
	return "+%.1f %s" % [gained, skill_name]


func _show_note(text: String) -> void:
	_note_label.text = text
	_note_label.visible = text != ""


func _refresh() -> void:
	for row in _rows:
		row.refresh()
	_skills_label.text = _skills_text()
	_skills_label.visible = _skills_label.text != ""


## "Cooking 23.5": the player's points in the skills the shown recipes practise.
func _skills_text() -> String:
	var skills := _crafting.player_skills()
	var parts: Array[String] = []
	for row in _rows:
		var skill := _crafting.rules.skill(row.recipe_id)
		if skill == &"":
			continue
		var part := "%s %.1f" % [skills.rules.skill_name(skill), skills.points(skill)]
		if not parts.has(part):
			parts.append(part)
	return "  ".join(parts)
