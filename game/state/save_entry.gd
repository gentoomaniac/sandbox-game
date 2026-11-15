class_name SaveEntry
extends RefCounted
## One save of the load list: where it is, what its header says, and why it can't be loaded if it
## can't (see SaveList `entries`).

var path: String
## Null when the file holds no header and none can be made of it.
var header: SaveHeader
## Why the save can't be loaded; "" when it can, as far as its header says. The file is only
## checked as a whole when it is loaded (see SaveFile `load_game`).
var problem := ""


func _init(save_path: String, save_header: SaveHeader, why_not := "") -> void:
	path = save_path
	header = save_header
	problem = why_not


func is_loadable() -> bool:
	return problem == ""
