class_name AssetCheck
extends RefCounted
## Whether the pictures the data refers to can be loaded. A picture that is in the repo but
## not imported yet (the game was started without the editor or `--import` after new art
## came in) loads as nothing, which would show as an invisible house or object much later.

const HINT := "Run `make run`, or `godot --headless --import` once, to import new assets."


## The pictures the data files and tables refer to that can't be loaded.
static func missing() -> Array[String]:
	var paths: Array[String] = []
	for building: Dictionary in BuildingTypes.TYPES.values():
		for picture: String in [building["sprite"], building["sprite_lit"]]:
			paths.append(picture)
			paths.append(SeasonalArt.house_path(picture, true))
	for look in SeasonBlend.Look.values():
		paths.append(SeasonalArt.path(ObjectTileset.ATLAS_PATH, look))
	for item: StringName in ItemTypes.TYPES:
		if item != ItemTypes.NONE:
			paths.append(ItemTypes.ICON_PATH % item)
			paths.append(ItemTypes.GROUND_ICON_PATH % item)
	var crops := CropRules.default_rules()
	for crop_id in crops.crop_ids():
		paths.append(crops.crop(crop_id)["sheet"])
	return paths.filter(func(path: String) -> bool: return load(path) == null)


## Reports the missing pictures; returns whether all are there.
static func report() -> bool:
	var paths := missing()
	for path in paths:
		push_error("Missing or not imported: %s" % path)
	if not paths.is_empty():
		push_error(HINT)
	return paths.is_empty()
