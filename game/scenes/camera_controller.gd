class_name CameraController
extends Node
## Second stage of the rendering. Points the world camera, which sits on a whole art pixel
## and never zooms, and shows the matching part of the world viewport on the window through
## the sharp-bilinear shader (see ViewMath). The mouse wheel zooms around the camera target.
## The camera API is CameraRig's, reached through `rig`.

@export var world_viewport: SubViewport
@export var world_camera: Camera2D
@export var screen: TextureRect

var rig := CameraRig.new()


func _ready() -> void:
	world_viewport.size = ViewMath.VIEWPORT_SIZE
	screen.texture = world_viewport.get_texture()


func _unhandled_input(event: InputEvent) -> void:
	if rig.is_playing() or not event is InputEventMouseButton or not event.pressed:
		return
	if event.button_index == MOUSE_BUTTON_WHEEL_UP:
		rig.zoom_by_wheel(event.factor)
	elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		rig.zoom_by_wheel(-event.factor)


func _process(delta: float) -> void:
	rig.advance(delta)
	var window_size := _window_size()
	world_camera.position = ViewMath.snapped_camera(rig.position)
	var origin := ViewMath.region_origin(rig.position, window_size, rig.zoom)
	var material := screen.material as ShaderMaterial
	material.set_shader_parameter("region_origin", origin)
	material.set_shader_parameter("region_size", ViewMath.visible_size(window_size, rig.zoom))
	material.set_shader_parameter("texels_to_pixels", ViewMath.screen_scale(window_size, rig.zoom))


## The art-pixel position of the world under the mouse.
func mouse_world_position() -> Vector2:
	# The UI is scaled with the window (content scale), the mouse is in its units.
	var ui_to_window := _window_size() / get_viewport().get_visible_rect().size
	var window_position := get_viewport().get_mouse_position() * ui_to_window
	return ViewMath.window_to_world(window_position, _window_size(), rig.position, rig.zoom)


func _window_size() -> Vector2:
	return Vector2(get_window().size)
