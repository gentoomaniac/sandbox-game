class_name RulesCheck
extends RefCounted
## Whether every rules file, the catalog and the pictures the game needs are valid. Each check
## reports what is wrong by itself (the missing rules, crops, curves or pictures), so a game that
## fails this has nothing more to say before it quits.


static func is_everything_valid() -> bool:
	return (
		EnergyRules.default_rules().is_valid()
		and CropRules.default_rules().is_valid()
		and Vegetation.default_vegetation().is_valid()
		and WildlifeRules.default_rules().is_valid()
		and LivestockRules.default_rules().is_valid()
		and NpcRules.default_rules().is_valid()
		and VillagerRules.default_rules().is_valid()
		and VillageSheet.default_sheet().is_valid()
		and NpcTalkRules.default_rules().is_valid()
		and SeasonRules.default_rules().is_valid()
		and BuildingRules.default_rules().is_valid()
		and RecipeRules.default_rules().is_valid()
		and SkillRules.default_rules().is_valid()
		and StationRules.default_rules().is_valid()
		and CatalogCheck.report()
		and SoundRules.default_rules().is_valid()
		and AmbienceRules.default_rules().is_valid()
		and LandscapeRules.default_rules().is_valid()
		and PathRules.default_rules().is_valid()
		and AssetCheck.report()
	)
