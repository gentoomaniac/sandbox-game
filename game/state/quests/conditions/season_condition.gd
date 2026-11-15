class_name SeasonCondition
extends QuestCondition
## The season is one of `seasons`, a list of "spring", "summer", "autumn" and "winter".

const NAMES: Array[String] = ["spring", "summer", "autumn", "winter"]


func kind() -> String:
	return "season"


func problems(fields: Dictionary, _quest_ids: Array[String]) -> Array[String]:
	var seasons: Variant = fields.get("seasons")
	if seasons is Array and not seasons.is_empty() and seasons.all(_is_season):
		return []
	return ["seasons is not a list of %s" % ", ".join(NAMES)]


static func _is_season(name: Variant) -> bool:
	return name is String and NAMES.has(name)
