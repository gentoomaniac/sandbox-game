extends GutTest
## How far the plants among the objects sway, by kind: small plants more than big ones (see
## AmbientMotion.SWAY_PROFILES).


func test_grass_sways_more_than_bushes_and_bushes_more_than_trees() -> void:
	var grass := [WorldObjectTypes.TALL_GRASS, WorldObjectTypes.REEDS, WorldObjectTypes.FERN_BUSH]
	var bushes := [WorldObjectTypes.BERRY_BUSH, WorldObjectTypes.SHRUB, WorldObjectTypes.SAPLING]
	var trees := [
		WorldObjectTypes.OAK,
		WorldObjectTypes.SPRUCE,
		WorldObjectTypes.PINE,
		WorldObjectTypes.BEECH,
		WorldObjectTypes.BIRCH,
		WorldObjectTypes.ALDER,
		WorldObjectTypes.WILLOW,
	]
	assert_gt(_least_strength(grass), _most_strength(bushes))
	assert_gt(_least_strength(bushes), _most_strength(trees))
	# In a light air the grass's tips flick and the trees stand still.
	var light_air := AmbientMotion.sway_for(2.0)
	assert_gte(light_air * _least_strength(grass), 0.5, "rounds to a pixel")
	assert_lt(light_air * _most_strength(trees), 0.5, "rounds to nothing")


func _least_strength(types: Array) -> float:
	return types.map(func(type: StringName) -> float: return _strength(type)).min()


func _most_strength(types: Array) -> float:
	return types.map(func(type: StringName) -> float: return _strength(type)).max()


func _strength(type: StringName) -> float:
	return AmbientMotion.SWAY_PROFILES[type]["strength"]
