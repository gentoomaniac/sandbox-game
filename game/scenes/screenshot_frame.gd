class_name ScreenshotFrame
extends Node
## The scene `make screenshot SIZE=WxH` starts instead of Main: it runs the game in a viewport
## of exactly that size, so the picture shows what a window of that size shows, whatever size
## the window manager gives the real one (Wayland ignores the size asked for, and may scale it).
## The viewport is stretched like the project's window: the UI is laid out in the project's base
## size, grown to the aspect ratio, times the UI scale the game sets on the real window.

const MAIN_SCENE := preload("res://game/scenes/main.tscn")

var _screen: SubViewport


func _ready() -> void:
	_screen = SubViewport.new()
	_screen.size = StartupOptions.from_command_line().screenshot_size
	_screen.size_2d_override_stretch = true
	_screen.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	ViewMath.screen_size = _screen.size
	add_child(_screen)
	_screen.add_child(MAIN_SCENE.instantiate())


func _process(_delta: float) -> void:
	var base := Vector2(get_tree().root.content_scale_size)
	var scale := minf(_screen.size.x / base.x, _screen.size.y / base.y)
	scale *= get_tree().root.content_scale_factor
	_screen.size_2d_override = Vector2i((Vector2(_screen.size) / scale).round())
