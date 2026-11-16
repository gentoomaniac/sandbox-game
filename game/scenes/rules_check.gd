class_name RulesCheck
extends RefCounted
## Whether every rules file, the catalog and the pictures the game needs are valid. Each check
## reports what is wrong by itself (the missing rules, crops, curves or pictures), so a game that
## fails this has nothing more to say before it quits.

## The checks `checks()` has to have, one per family of rules and the catalog and the pictures. It
## is the list to add to with a new family, so that a check dropped from `checks()` is noticed.
const FAMILIES: Array[StringName] = [
	&"energy",
	&"crops",
	&"vegetation",
	&"wildlife",
	&"livestock",
	&"npcs",
	&"villagers",
	&"village_sheet",
	&"npc_talk",
	&"seasons",
	&"buildings",
	&"recipes",
	&"skills",
	&"stations",
	&"sounds",
	&"ambience",
	&"landscape",
	&"paths",
	&"activities",
	&"quests",
	&"friendship",
	&"prices",
	&"shops",
	&"barter",
	&"stall",
	&"music",
	&"attributes",
	&"crop_raids",
	&"flowers",
	&"footprints",
	&"gossip",
	&"leaf_fall",
	&"lighting",
	&"spread",
	&"stork_nests",
	&"tool_grades",
	&"tool_swings",
	&"weather",
	&"yard",
	&"wild_seeds",
	&"village_plan",
	&"catalog",
	&"assets",
]


## Every check by name, in the order they report: the rules files first, then the checks of what
## the rules and the code define together (the catalog), then the pictures. All of them always
## run, so the log shows every problem at once. The catalog is built from some of the rules
## (BuildingRules and others), so with one of those files broken it may add problems that follow
## from it; the first lines of the log are the ones to fix. A new rules family is one more line here
## and one in `FAMILIES`; the same name twice does not parse.
static func checks() -> Dictionary[StringName, Callable]:
	return {
		# Base definitions.
		&"energy": func() -> bool: return EnergyRules.default_rules().is_valid(),
		&"crops": func() -> bool: return CropRules.default_rules().is_valid(),
		&"vegetation": func() -> bool: return Vegetation.default_vegetation().is_valid(),
		&"wildlife": func() -> bool: return WildlifeRules.default_rules().is_valid(),
		&"livestock": func() -> bool: return LivestockRules.default_rules().is_valid(),
		&"npcs": func() -> bool: return NpcRules.default_rules().is_valid(),
		&"villagers": func() -> bool: return VillagerRules.default_rules().is_valid(),
		&"village_sheet": func() -> bool: return VillageSheet.default_sheet().is_valid(),
		&"npc_talk": func() -> bool: return NpcTalkRules.default_rules().is_valid(),
		&"seasons": func() -> bool: return SeasonRules.default_rules().is_valid(),
		&"buildings": func() -> bool: return BuildingRules.default_rules().is_valid(),
		&"recipes": func() -> bool: return RecipeRules.default_rules().is_valid(),
		&"skills": func() -> bool: return SkillRules.default_rules().is_valid(),
		&"stations": func() -> bool: return StationRules.default_rules().is_valid(),
		&"sounds": func() -> bool: return SoundRules.default_rules().is_valid(),
		&"ambience": func() -> bool: return AmbienceRules.default_rules().is_valid(),
		&"landscape": func() -> bool: return LandscapeRules.default_rules().is_valid(),
		&"paths": func() -> bool: return PathRules.default_rules().is_valid(),
		&"activities": func() -> bool: return ActivityRules.default_rules().is_valid(),
		&"quests": func() -> bool: return QuestRules.default_rules().is_valid(),
		&"friendship": func() -> bool: return FriendshipRules.default_rules().is_valid(),
		&"prices": func() -> bool: return Prices.default_prices().is_valid(),
		&"shops": func() -> bool: return ShopRules.default_rules().is_valid(),
		&"barter": func() -> bool: return BarterRules.default_rules().is_valid(),
		&"stall": func() -> bool: return StallRules.default_rules().is_valid(),
		&"music": func() -> bool: return MusicRules.default_rules().is_valid(),
		&"attributes": func() -> bool: return AttributeRules.default_rules().is_valid(),
		&"crop_raids": func() -> bool: return CropRaidRules.default_rules().is_valid(),
		&"flowers": func() -> bool: return FlowerRules.default_rules().is_valid(),
		&"footprints": func() -> bool: return FootprintRules.default_rules().is_valid(),
		&"gossip": func() -> bool: return GossipRules.default_rules().is_valid(),
		&"leaf_fall": func() -> bool: return LeafFallRules.default_rules().is_valid(),
		&"lighting": func() -> bool: return LightingRules.default_rules().is_valid(),
		&"spread": func() -> bool: return SpreadRules.default_rules().is_valid(),
		&"stork_nests": func() -> bool: return StorkNestRules.default_rules().is_valid(),
		&"tool_grades": func() -> bool: return ToolGradeRules.default_rules().is_valid(),
		&"tool_swings": func() -> bool: return ToolSwingRules.default_rules().is_valid(),
		&"weather": func() -> bool: return WeatherRules.default_rules().is_valid(),
		&"yard": func() -> bool: return YardRules.default_rules().is_valid(),
		&"wild_seeds": func() -> bool: return WildSeeds.default_rules().is_valid(),
		&"village_plan": func() -> bool: return VillagePlan.default_plan().is_valid(),
		# What refers to what.
		&"catalog": CatalogCheck.report,
		# The pictures.
		&"assets": AssetCheck.report,
	}


static func is_everything_valid() -> bool:
	var registered := checks()
	var checks_passed := all_pass(registered.values())
	var missing := missing_families(registered.keys())
	for family in missing:
		push_error("no check for %s" % family)
	return checks_passed and missing.is_empty()


## The families that have no check among `registered`.
static func missing_families(registered: Array) -> Array[StringName]:
	var missing: Array[StringName] = []
	for family in FAMILIES:
		if family not in registered:
			missing.append(family)
	return missing


## Whether every check passes. Runs all of them, so that each reports its own problems.
static func all_pass(to_run: Array) -> bool:
	var everything_passed := true
	for check: Callable in to_run:
		if not check.call():
			everything_passed = false
	return everything_passed
