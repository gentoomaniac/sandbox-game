class_name FriendTarget
extends ActivityTarget
## The yard of the house of one of the villager's friends.


func kind() -> String:
	return "friend"


func is_searched() -> bool:
	return true


func has_door() -> bool:
	return true
