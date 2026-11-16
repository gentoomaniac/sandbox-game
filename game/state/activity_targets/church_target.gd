class_name ChurchTarget
extends ActivityTarget
## The yard of the nearest church.


func kind() -> String:
	return "church"


func is_searched() -> bool:
	return true


func has_door() -> bool:
	return true
