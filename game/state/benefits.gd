class_name Benefits
extends RefCounted
## What a villager gives the player by how they think of them (design/villagers/relationships.md,
## "What a level opens"): `allows` asks FriendshipRules about the villager's level and their
## sheet's `benefit_level`, so that places that give or refuse something ask a benefit, never a
## number. A benefit is told to the model (see NpcPrompt) and applied by the game, so what a
## villager says matches what the game does.


## Whether `npc` gives the player `benefit` (a FriendshipRules BENEFITS one) at their friendship.
static func allows(
	npc: Npc, benefit: StringName, villagers := VillagerRules.default_rules()
) -> bool:
	var earlier := villagers.benefit_levels(npc.id) if villagers.has(npc.id) else {}
	var friendship := FriendshipRules.default_rules()
	return friendship.allows(benefit, friendship.level_of(npc.opinion), earlier)
