class_name HitEffect
extends RefCounted
## What flies off an object when a tool hits it. Pure logic, so it can be tested apart from the
## drawing (see HitParticles).

## DUST is only raised together with SPLINTERS (see HitParticles), `kind_for` never gives it.
## SWEAT and SWEAT_HEAVY are not thrown off objects but off a tired player's head (see
## TirednessSigns).
enum Kind { NONE, LEAVES_GREEN, LEAVES_AUTUMN, NEEDLES, SNOW, SPLINTERS, DUST, SWEAT, SWEAT_HEAVY }

## What drops leaves while it has them: the broadleaved trees and the hedge.
const LEAFY: Array[StringName] = [
	WorldObjectTypes.OAK,
	WorldObjectTypes.BEECH,
	WorldObjectTypes.BIRCH,
	WorldObjectTypes.WILLOW,
	WorldObjectTypes.KNICK,
]


## The effect of a hit on an object of `type` that is drawn in `look`. A frosty tree counts as
## its season's look: the caller passes that, as the frost says nothing about its foliage.
static func kind_for(type: StringName, look: SeasonBlend.Look) -> Kind:
	if (
		type
		in [
			WorldObjectTypes.STONE,
			WorldObjectTypes.BOULDER,
			WorldObjectTypes.DEAD_STUMP,
			WorldObjectTypes.CHEST,
			WorldObjectTypes.STONE_WALL,
			WorldObjectTypes.WATTLE_FENCE,
		]
	):
		return Kind.SPLINTERS
	var is_snowy := look == SeasonBlend.Look.SNOW or look == SeasonBlend.Look.DUSTING
	if type in [WorldObjectTypes.SPRUCE, WorldObjectTypes.PINE]:
		return Kind.SNOW if is_snowy else Kind.NEEDLES
	if type in LEAFY:
		if is_snowy:
			return Kind.SNOW
		match look:
			SeasonBlend.Look.YOUNG_LEAVES, SeasonBlend.Look.SPRING, SeasonBlend.Look.SUMMER:
				return Kind.LEAVES_GREEN
			SeasonBlend.Look.AUTUMN:
				return Kind.LEAVES_AUTUMN
	return Kind.NONE
