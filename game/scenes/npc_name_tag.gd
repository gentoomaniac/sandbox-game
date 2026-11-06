class_name NpcNameTag
extends CanvasLayer
## The name of the villager that E would speak to (see Interaction `npc_to_chat`), over their
## head. It is UI text, the size of the HUD's at any zoom, placed over the villager where the
## camera shows them. Main says which villager each frame.

## The bottom of the name, in art pixels above the villager's feet: just over the head.
const ABOVE_FEET := 30
const THEME := preload("res://game/scenes/ui_theme.tres")

var _label := Label.new()


func _init() -> void:
	_label.theme = THEME
	_label.visible = false
	add_child(_label)


func is_shown() -> bool:
	return _label.visible


func text() -> String:
	return _label.text


## Shows the villager's name over them as `camera` shows them, or nothing for null.
func show_over(npc: Npc, camera: CameraController) -> void:
	_label.visible = npc != null
	if npc == null:
		return
	_label.text = npc.name
	var head := npc.position * TerrainTileset.TILE_SIZE - Vector2(0, ABOVE_FEET)
	var size := _label.get_minimum_size()
	_label.position = (camera.world_to_ui(head) - Vector2(size.x / 2.0, size.y)).round()
