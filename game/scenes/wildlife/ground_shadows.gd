class_name GroundShadows
extends Node2D
## The small shadows that birds in flight cast on the ground below them. They go on the
## WildlifeView's `ground` layer, under everything that stands, and fall to the lower right of
## the point below each bird, as the light is from the upper left. Each bird sets its point
## every frame (`set_point`), so the points are kept and never made anew.

const COLOR := Color(0.0, 0.0, 0.0, 0.4)
const SHIFT := Vector2(8.0, 6.0) * TerrainTileset.ART_16_SCALE

## Half the width of a shadow in pixels of the 16 px art, past its middle pixel.
var half_width := 2
## How far from the point below its bird a shadow falls: SHIFT high in the air, nothing for a
## bird on the ground.
var shift := SHIFT
var _points := PackedVector2Array()


func _init(count: int, shadow_half_width := 2) -> void:
	_points.resize(count)
	half_width = shadow_half_width


## Puts shadow `index` below the bird at a point of the ground.
func set_point(index: int, ground_point: Vector2) -> void:
	_points[index] = ground_point
	queue_redraw()


func _draw() -> void:
	for point in _points:
		# On the grid of the 16 px art, as the shadow is drawn on it.
		var art_scale := TerrainTileset.ART_16_SCALE
		var centre := ((point + shift) / art_scale).round() * art_scale
		draw_set_transform(centre, 0.0, Vector2.ONE * art_scale)
		draw_rect(Rect2(-half_width, 0, half_width * 2 + 1, 1), COLOR)
		draw_rect(Rect2(-half_width + 1, 1, half_width * 2 - 1, 1), COLOR)
