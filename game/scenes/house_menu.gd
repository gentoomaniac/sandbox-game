class_name HouseMenu
extends RefCounted
## The hammer's menu on a building, in a ChoiceDialog: who lives there, and a button for each way
## to give it to a villager near (see Households `offers`: "Give to ..." for a home, "... works
## here" for a workplace). Escape or Close leaves everything as it was.

var _dialog: ChoiceDialog
var _homes: Households


func _init(dialog: ChoiceDialog, homes: Households) -> void:
	_dialog = dialog
	_homes = homes


## Opens the menu on `building` and returns when the player has chosen.
func open(building: Building) -> void:
	var offers := _homes.offers(building)
	var choices: Array[String] = []
	for offer in offers:
		choices.append(offer["text"])
	choices.append("Close")
	_dialog.ask(building.type_data()["name"], _text_of(building, offers), choices, offers.size())
	var choice: int = await _dialog.answered
	if choice < offers.size():
		_homes.accept(offers[choice], building)


func _text_of(building: Building, offers: Array[Dictionary]) -> String:
	var names: Array[String] = []
	for resident in _homes.residents_of(building):
		names.append(resident.name)
	var text := (
		"Lives here: %s." % ", ".join(names) if not names.is_empty() else "Nobody lives here."
	)
	if offers.is_empty():
		text += " Nobody near can be given it."
	return text
