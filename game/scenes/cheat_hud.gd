class_name CheatHud
extends CanvasLayer
## A small line under the clock naming the cheats that are on; hidden when none is.

const THEME := preload("res://game/scenes/ui_theme.tres")

var _cheats: CheatFlags
var _label := Label.new()


func _init() -> void:
	# Two lines below the clock, leaving the line between for notes (see HarvestHud).
	_label.position = Vector2(4, 22)
	_label.theme = THEME
	add_child(_label)


func show_cheats(cheats: CheatFlags) -> void:
	_cheats = cheats


func _process(_delta: float) -> void:
	var names := _cheats.active_names()
	_label.visible = not names.is_empty()
	_label.text = " · ".join(names)
