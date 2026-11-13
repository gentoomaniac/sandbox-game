class_name CameraController
extends Node
## Second stage of the rendering. Points the world camera, which sits on the whole art pixel
## nearest to the target and never zooms, and shows the matching part of the world viewport
## on the window through the sharp-bilinear shader (see ViewMath), shifted by the target's
## fraction. So the world scrolls at sub-pixel precision while everything in the viewport
## stays on the art pixel grid. Ctrl and the mouse wheel, or the zoom keys, zoom around the
## camera target (the wheel alone steps through the hotbar, see Main). The camera API is
## CameraRig's, reached through `rig`.

## Wheel notches one press of a zoom key counts for; holding the key repeats it.
const KEY_ZOOM_NOTCHES := 2.0

@export var world_viewport: SubViewport
@export var world_camera: Camera2D
@export var screen: TextureRect

var rig := CameraRig.new()


func _ready() -> void:
	world_viewport.size = ViewMath.VIEWPORT_SIZE
	screen.texture = world_viewport.get_texture()


func _unhandled_input(event: InputEvent) -> void:
	if rig.is_playing():
		return
	if event.is_action_pressed("zoom_in", true):
		rig.zoom_by_wheel(KEY_ZOOM_NOTCHES)
	elif event.is_action_pressed("zoom_out", true):
		rig.zoom_by_wheel(-KEY_ZOOM_NOTCHES)
	elif event is InputEventMouseButton and event.pressed and event.ctrl_pressed:
		_zoom_by_wheel_event(event)


func _zoom_by_wheel_event(event: InputEventMouseButton) -> void:
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


## The part of the viewport the window shows, in its pixels.
func visible_region() -> Rect2:
	var window_size := _window_size()
	return Rect2(
		ViewMath.region_origin(rig.position, window_size, rig.zoom),
		ViewMath.visible_size(window_size, rig.zoom)
	)


## The part of the world the camera shows, in art pixels of the world.
func view_rect() -> Rect2:
	return rig.view_rect(_window_size())


## The art-pixel position of the world under the mouse.
func mouse_world_position() -> Vector2:
	# The mouse is in UI units, which depend on the window's size and the UI scale.
	var window_position := ViewMath.ui_to_window(
		get_viewport().get_mouse_position(), _window_size(), get_viewport().get_visible_rect().size
	)
	return ViewMath.window_to_world(window_position, _window_size(), rig.position, rig.zoom)


## Where an art-pixel position of the world is on screen, in UI units (where the HUD is placed).
func world_to_ui(world_position: Vector2) -> Vector2:
	var window_position := ViewMath.world_to_window(
		world_position, _window_size(), rig.position, rig.zoom
	)
	return window_position * get_viewport().get_visible_rect().size / _window_size()


func _window_size() -> Vector2:
	return ViewMath.window_size(get_window())
