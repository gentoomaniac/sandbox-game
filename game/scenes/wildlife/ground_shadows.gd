class_name GroundShadows
extends Node2D
## The small shadows that birds in flight cast on the ground below them. They go on the
## WildlifeView's `ground` layer, under everything that stands, and fall to the lower right of
## the point below each bird, as the light is from the upper left. Each bird sets its point
## every frame (`set_point`), so the points are kept and never made anew.

const COLOR := Color(0.0, 0.0, 0.0, 0.4)
const SHIFT := Vector2(16.0, 12.0)

## Half the width of a shadow in pixels.
var half_width := 4
## How far from the point below its bird a shadow falls: SHIFT high in the air, nothing for a
## bird on the ground.
var shift := SHIFT
var _points := PackedVector2Array()


func _init(count: int, shadow_half_width := 4) -> void:
	_points.resize(count)
	half_width = shadow_half_width


## Puts shadow `index` below the bird at a point of the ground.
func set_point(index: int, ground_point: Vector2) -> void:
	_points[index] = ground_point
	queue_redraw()


func _draw() -> void:
	# A flat oval of four rows, its ends rounded off.
	for point in _points:
		var centre := (point + shift).round()
		for row in 4:
			var half := half_width - (0 if row == 1 or row == 2 else 2)
			draw_rect(Rect2(centre + Vector2(-half, row - 1), Vector2(half * 2, 1)), COLOR)
