class_name CharacterPreview
extends Control
## The player's character facing the viewer, standing still: the idle frame of every layer
## sheet (see Appearance), drawn at a whole-number `pixel_scale`.

const FRAME_SIZE := Vector2i(TerrainTileset.TILE_SIZE, PlayerView.FRAME_HEIGHT)
const BACKGROUND_COLOR := Color("3a2920")  # palette soil_dark, see tools/art/palette.py

var pixel_scale := 4:
	set(value):
		pixel_scale = value
		custom_minimum_size = Vector2(FRAME_SIZE * pixel_scale)
		queue_redraw()

var _appearance: Appearance


func show_appearance(appearance: Appearance) -> void:
	_appearance = appearance
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), BACKGROUND_COLOR)
	if _appearance == null:
		return
	var sheet_cell := Vector2i(PlayerView.IDLE_COLUMN, PlayerView.FACING_ROWS[Vector2i.DOWN])
	var source := Rect2(sheet_cell * FRAME_SIZE, FRAME_SIZE)
	var target := Rect2(Vector2.ZERO, Vector2(FRAME_SIZE * pixel_scale))
	for layer in _appearance.layers_for(Vector2i.DOWN):
		draw_texture_rect_region(load(Appearance.sheet_path(layer)), target, source)
