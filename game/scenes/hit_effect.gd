class_name HitEffect
extends RefCounted
## What flies off an object when a tool hits it. Pure logic, so it can be tested apart from the
## drawing (see HitParticles).

## DUST is only raised together with SPLINTERS (see HitParticles), `kind_for` never gives it.
## SWEAT and SWEAT_HEAVY are not thrown off objects but off a tired player's head (see
## TirednessSigns).
enum Kind { NONE, LEAVES_GREEN, LEAVES_AUTUMN, NEEDLES, SNOW, SPLINTERS, DUST, SWEAT, SWEAT_HEAVY }


## The effect of a hit on an object of `type` that is drawn in `look`. A frosty tree counts as
## its season's look: the caller passes that, as the frost says nothing about its foliage.
static func kind_for(type: StringName, look: SeasonBlend.Look) -> Kind:
	if (
		type
		in [
			WorldObjectTypes.STONE,
			WorldObjectTypes.BOULDER,
			WorldObjectTypes.DEAD_STUMP,
			WorldObjectTypes.CHEST
		]
	):
		return Kind.SPLINTERS
	var is_snowy := look == SeasonBlend.Look.SNOW or look == SeasonBlend.Look.DUSTING
	match type:
		WorldObjectTypes.OAK, WorldObjectTypes.KNICK:
			if is_snowy:
				return Kind.SNOW
			match look:
				SeasonBlend.Look.YOUNG_LEAVES, SeasonBlend.Look.SPRING, SeasonBlend.Look.SUMMER:
					return Kind.LEAVES_GREEN
				SeasonBlend.Look.AUTUMN:
					return Kind.LEAVES_AUTUMN
		WorldObjectTypes.SPRUCE, WorldObjectTypes.PINE:
			return Kind.SNOW if is_snowy else Kind.NEEDLES
	return Kind.NONE
