class_name SeasonalArt
extends RefCounted
## Which picture file shows a look (see SeasonBlend.Look). Summer is the plain file; the other
## looks add their name before the extension, as the art generator writes them
## (tools/art/seasons.py): terrain_snow.png, kate_lit_snow.png.


## The file of `summer_path` as it looks in `look`.
static func path(summer_path: String, look: SeasonBlend.Look) -> String:
	if look == SeasonBlend.Look.SUMMER:
		return summer_path
	var look_name: String = SeasonBlend.Look.keys()[look]
	return (
		"%s_%s.%s" % [summer_path.get_basename(), look_name.to_lower(), summer_path.get_extension()]
	)


## The file of a house picture: houses only change under snow.
static func house_path(summer_path: String, is_snowy: bool) -> String:
	return path(summer_path, SeasonBlend.Look.SNOW if is_snowy else SeasonBlend.Look.SUMMER)
