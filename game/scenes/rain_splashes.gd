class_name RainSplashes
extends ColorRect
## Where the rain splashes on the ground (see rain_splashes.gdshader): a rectangle in the world
## under the objects and the player that keeps over the whole view, wherever the camera goes.
## The shader works from world positions, so the splashes stay in place as it moves along.

var _motion: AmbientMotion


func _init(motion: AmbientMotion) -> void:
	_motion = motion
	name = "RainSplashes"
	material = motion.splashes
	# A tile more than the view, so no edge shows whatever the camera's fraction.
	size = Vector2(ViewMath.VIEWPORT_SIZE + Vector2i.ONE * TerrainTileset.TILE_SIZE)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(_delta: float) -> void:
	visible = _motion.splash_chance > 0.0
	var camera := get_viewport().get_camera_2d()
	if camera != null:
		position = (camera.position - size / 2).round()
