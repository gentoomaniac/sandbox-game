class_name PathsHud
extends CanvasLayer
## The way of the villager nearest the player that is on a trip (see Npcs `path_text`), in the
## bottom right corner, for watching how villagers find their way (the console's `goto` sends one).
## Off by default; the `toggle_paths` action shows and hides it. While it is off nothing is asked.

const THEME := preload("res://game/scenes/ui_theme.tres")

var _npcs: Npcs
var _player: PlayerState
var _label := Label.new()


func _init() -> void:
	visible = false
	_label.theme = THEME
	_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_label.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_label.offset_right = -4
	_label.offset_bottom = -4
	add_child(_label)


func _ready() -> void:
	set_process(false)  # A node with a `_process` starts it when it enters the tree.


## Shows the paths of the villagers of `npcs` that are near `player`.
func setup(npcs: Npcs, player: PlayerState) -> void:
	_npcs = npcs
	_player = player


func toggle() -> void:
	visible = not visible
	set_process(visible)


func _process(_delta: float) -> void:
	var text := _npcs.path_text(_player.position)
	if _label.text != text:
		_label.text = text
