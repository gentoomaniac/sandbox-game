class_name WildTarget
extends ActivityTarget
## A meadow tile away from home.


func kind() -> String:
	return "wild"


func is_searched() -> bool:
	return true
