class_name VillagerActivities
extends RefCounted
## Which activities (see ActivityRules) a villager has: the set `base`, the set of their work and
## the extras of their sheet, less what the sheet skips. A villager written by hand names the set
## of their work in their sheet, a made-up one has the set of their trade (the tables of
## data/npcs.cfg); a trade the tables no longer have gives `base` only.

## The ids of the activities, `base` first, each once.
var ids: Array[String] = []
## They go to church only on the feasts (see ActivityRules `feast_days`).
var is_church_feasts_only := false


static func of(
	npc: Npc, villagers: VillagerRules, npc_rules: NpcRules, rules: ActivityRules
) -> VillagerActivities:
	var activities := VillagerActivities.new()
	var sheet := villagers.villager(npc.id) if villagers.has(npc.id) else {}
	var work_set: String = (
		sheet.get(VillagerRules.WORK_SET_KEY, "")
		if not sheet.is_empty()
		else npc_rules.work_set_of_trade(npc.trade)
	)
	var wanted := rules.set_activities(ActivityRules.BASE_SET)
	if rules.has_set(work_set):
		wanted.append_array(rules.set_activities(work_set))
	wanted.append_array(sheet.get(VillagerRules.ACTIVITIES_KEY, []))
	var skips: Array = sheet.get(VillagerRules.SKIPS_KEY, [])
	for id in wanted:
		if not activities.ids.has(id) and not skips.has(id):
			activities.ids.append(id)
	activities.is_church_feasts_only = sheet.get(VillagerRules.CHURCH_FEASTS_ONLY_KEY, false)
	return activities
