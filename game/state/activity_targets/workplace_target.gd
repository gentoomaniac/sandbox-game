class_name WorkplaceTarget
extends ActivityTarget
## The villager's workplace; with none, the yard of their home.


func kind() -> String:
	return "workplace"


func has_door() -> bool:
	return true
