class_name FriendTarget
extends ActivityTarget
## The yard of the house of one of the villager's `people` who has one within `search_tiles` of
## their home, which one picked from the day and their name.


func kind() -> String:
	return "friend"


func is_searched() -> bool:
	return true


func has_door() -> bool:
	return true


func spot_of(npc: Npc, day: int, places: ActivityPlaces) -> Vector2:
	var home := places.home_point(npc)
	var yards: Array[Vector2] = []
	for friend_id: String in npc.people:
		var friend := places.npcs.find(friend_id)
		if (
			friend != null
			and friend.house != null
			and friend.house.yard().distance_to(home) <= places.rules.search_tiles(kind())
		):
			yards.append(friend.house.yard())
	if yards.is_empty():
		return ActivityPlaces.NOWHERE
	return yards[posmod(hash([npc.name, day]), yards.size())]
