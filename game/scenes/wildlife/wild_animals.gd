class_name WildAnimals
extends RefCounted
## Which animal class makes each kind of wild animal of WildlifeRules, the one place that knows.


## A new animal of a kind, not yet in the view. The flocks of birds and the storks on roofs are not
## made here: WildlifeView gives them their course.
static func create(kind: StringName) -> Animal:
	match kind:
		WildlifeRules.BIRD:
			return Bird.new()
		WildlifeRules.RABBIT:
			return Rabbit.new()
		WildlifeRules.SQUIRREL:
			return Squirrel.new()
		WildlifeRules.DEER:
			return Deer.new()
		WildlifeRules.BEE:
			return Bee.new()
		WildlifeRules.BUTTERFLY:
			return Butterfly.new()
		WildlifeRules.FIREFLY:
			return Firefly.new()
		WildlifeRules.STORK:
			return Stork.new(WildlifeRules.STORK)
		WildlifeRules.GEESE, WildlifeRules.CROWS, WildlifeRules.OYSTERCATCHER, WildlifeRules.DUNLIN:
			return GroundFlock.new(kind)
		WildlifeRules.MOUSE:
			return Mouse.new()
		WildlifeRules.FROG:
			return Frog.new()
		WildlifeRules.GULL:
			return Gull.new()
		WildlifeRules.TERN:
			return Tern.new()
	return null
