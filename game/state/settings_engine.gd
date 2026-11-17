class_name SettingsEngine
extends RefCounted
## Where the settings meet the engine: what the window is and what the player's choice does to it.
## GameSettings itself is the values and the file.


## Whether the window is fullscreen now, as the command line or project left it.
static func is_fullscreen() -> bool:
	var mode := DisplayServer.window_get_mode()
	return (
		mode == DisplayServer.WINDOW_MODE_FULLSCREEN
		or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
	)


static func set_fullscreen(value: bool) -> void:
	DisplayServer.window_set_mode(
		DisplayServer.WINDOW_MODE_FULLSCREEN if value else DisplayServer.WINDOW_MODE_WINDOWED
	)
