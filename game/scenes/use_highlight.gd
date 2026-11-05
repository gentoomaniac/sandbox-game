class_name UseHighlight
extends Node2D
## Outlines the tile in front of the player while the use action would do something there.

# Palette colour cream (see tools/art/generate.py).
const COLOR := Color("f1e6c2", 0.8)

var _state: GameState
var _target := Vector2i.ZERO
var _is_visible := false


func show_for(state: GameState) -> void:
	_state = state


func _process(_delta: float) -> void:
	if _state == null:
		return
	var target := _state.player.facing_tile()
	var is_visible := _state.use_at(target) != GameState.Use.NOTHING
	if target != _target or is_visible != _is_visible:
		_target = target
		_is_visible = is_visible
		queue_redraw()


func _draw() -> void:
	if _is_visible:
		var tile_size := TerrainTileset.TILE_SIZE
		draw_rect(Rect2(Vector2(_target * tile_size), Vector2(tile_size, tile_size)), COLOR, false)
