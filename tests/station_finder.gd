class_name StationFinder
extends RefCounted
## Finds the crafting station of a kind that stands in the player's reach, as the camp of a new
## game has them (the campfire is a hearth).


static func in_reach(state: GameState, kind: StringName) -> WorldObject:
	var station := Interaction.nearest_in_reach(
		state,
		func(object: WorldObject) -> bool:
			return StationRules.default_rules().station_of(object.type) == kind
	)
	assert(station != null, "No %s in the player's reach" % kind)
	return station
