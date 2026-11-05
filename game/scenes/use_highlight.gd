class_name UseHighlight
extends Node2D
## Outlines the tile the use action aims at (see Targeting): the one under the mouse while the
## mouse is moving, otherwise the one in front of the player.
##
## - In reach and `use_at` has something to do there: outline.
## - Under the mouse, in reach, nothing to do: a faint outline, so the cursor still shows
##   where it points. In front of the player the highlight stays off then.
## - Under the mouse, out of reach: translucent red outline and fill; the action does nothing.
## Drawn in world space, so it sits on the pixel grid and zooms with the world.

## The mouse target stays this long after the last mouse motion, then fades out ...
const MOUSE_IDLE_SECONDS := 3.0
## ... over this long, and the facing tile takes over.
const MOUSE_FADE_SECONDS := 0.5

# Palette colours cream and ember (see tools/art/generate.py).
const COLOR := Color("f1e6c2", 0.8)
const COLOR_NOTHING_TO_DO := Color("f1e6c2", 0.3)
const COLOR_OUT_OF_REACH := Color("a8402e", 0.9)
## Out of reach the tile is also filled, with this much of the outline's opacity. Filled
## more strongly, ember on grass reads as bare soil.
const OUT_OF_REACH_FILL_SHARE := 0.2

## Off while something else owns the mouse (build mode).
var is_enabled := true
## Debug: pretends the mouse is always on this tile.
var debug_mouse_tile: Variant = null

var _state: GameState
var _camera: CameraController
var _last_mouse_motion_seconds := -INF
var _drawn_tile := Vector2i.ZERO
var _drawn_color := Color.TRANSPARENT
var _is_drawn_filled := false


func show_for(state: GameState, camera: CameraController) -> void:
	_state = state
	_camera = camera


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		note_mouse_activity()


func note_mouse_activity() -> void:
	_last_mouse_motion_seconds = _now_seconds()


## The tile a use action aims at right now.
func targeting() -> Targeting:
	var mouse_tile := Vector2i((_camera.mouse_world_position() / TerrainTileset.TILE_SIZE).floor())
	if debug_mouse_tile != null:
		mouse_tile = debug_mouse_tile
	var is_mouse_active := _mouse_opacity() > 0.0
	return Targeting.resolve(
		_state.player.tile(), _state.player.facing_tile(), mouse_tile, is_mouse_active
	)


func _process(_delta: float) -> void:
	if _state == null:
		return
	var target := targeting()
	var color := _color_for(target) if is_enabled else Color.TRANSPARENT
	var is_filled := not target.is_in_reach
	if target.tile != _drawn_tile or color != _drawn_color or is_filled != _is_drawn_filled:
		_drawn_tile = target.tile
		_drawn_color = color
		_is_drawn_filled = is_filled
		queue_redraw()


func _draw() -> void:
	if _drawn_color.a == 0.0:
		return
	var tile_size := TerrainTileset.TILE_SIZE
	var rect := Rect2(Vector2(_drawn_tile * tile_size), Vector2(tile_size, tile_size))
	if _is_drawn_filled:
		draw_rect(rect, Color(_drawn_color, _drawn_color.a * OUT_OF_REACH_FILL_SHARE))
	draw_rect(rect, _drawn_color, false)


func _color_for(target: Targeting) -> Color:
	if target.source == Targeting.Source.FACING:
		return COLOR if _state.use_at(target.tile) != GameState.Use.NOTHING else Color.TRANSPARENT
	if not target.is_in_reach:
		return _color_with_opacity(COLOR_OUT_OF_REACH)
	var has_use := _state.use_at(target.tile) != GameState.Use.NOTHING
	return _color_with_opacity(COLOR if has_use else COLOR_NOTHING_TO_DO)


func _color_with_opacity(color: Color) -> Color:
	return Color(color, color.a * _mouse_opacity())


## 1 while the mouse is in use, fading to 0 once it has been idle.
func _mouse_opacity() -> float:
	if debug_mouse_tile != null:
		return 1.0
	var idle_seconds := _now_seconds() - _last_mouse_motion_seconds
	return clampf(1.0 - (idle_seconds - MOUSE_IDLE_SECONDS) / MOUSE_FADE_SECONDS, 0.0, 1.0)


func _now_seconds() -> float:
	return Time.get_ticks_msec() / 1000.0
