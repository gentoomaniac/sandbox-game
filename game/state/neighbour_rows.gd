class_name NeighbourRows
extends RefCounted
## What the neighbours tab of the character window shows (design/villagers/relationships.md): a row
## for each villager of the world, the closest friends first and those of a level by name, with
## their look, the level and its name, and, for the tooltip, the next level and what it brings. The
## points are never shown. Plain state: the panel only draws these.

const NEXT_TEXT := "Next: %s. %s"
const BRINGS_TEXT := "Brings: %s."
const NOTHING_NEW_TEXT := "A deeper friendship."
const TOP_TEXT := "As close a friend as there is."


## The rows, each `{name, look, level, level_name, next}`: the look is an Appearance, `next` the
## text of the tooltip.
static func of(state: GameState) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	var friendship := FriendshipRules.default_rules()
	for npc in state.npcs.all():
		var level := friendship.level_of(npc.opinion)
		var row := {
			"name": npc.name,
			"look": npc.appearance,
			"level": level,
			"level_name": friendship.level_name(level),
			"next": _next_text(npc, level, friendship),
		}
		rows.append(row)
	rows.sort_custom(
		func(first: Dictionary, second: Dictionary) -> bool:
			if first["level"] != second["level"]:
				return first["level"] > second["level"]
			return first["name"] < second["name"]
	)
	return rows


## "Next: Neighbour. Brings: barters at the market price, says what they want this year." Which
## benefits are new at the next level counts the villager's own sheet (see Benefits).
static func _next_text(npc: Npc, level: int, friendship: FriendshipRules) -> String:
	if level == FriendshipRules.LEVEL_COUNT:
		return TOP_TEXT
	var villagers := VillagerRules.default_rules()
	var earlier := villagers.benefit_levels(npc.id) if villagers.has(npc.id) else {}
	var brings: Array[String] = []
	for benefit in FriendshipRules.BENEFITS:
		if (
			not friendship.allows(benefit, level, earlier)
			and friendship.allows(benefit, level + 1, earlier)
		):
			brings.append(friendship.benefit_text(benefit))
	var what := NOTHING_NEW_TEXT if brings.is_empty() else BRINGS_TEXT % ", ".join(brings)
	return NEXT_TEXT % [friendship.level_name(level + 1), what]
