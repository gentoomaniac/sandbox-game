class_name SeasonalArt
extends RefCounted
## Which picture file shows a look (see SeasonBlend.Look). Summer is the plain file; the other
## looks add their name before the extension, as the art generator writes them
## (tools/art/seasons.py): terrain_snow.png, kate_lit_snow.png.

## The looks of a house picture: its roof follows the season of the grass (a turf roof greens
## in spring and darkens in autumn and winter). The snow lies over it by the shader, from a
## picture of its own (see `roof_snow_path`).
const HOUSE_LOOKS: Array[SeasonBlend.Look] = [
	SeasonBlend.Look.SPRING,
	SeasonBlend.Look.SUMMER,
	SeasonBlend.Look.AUTUMN,
	SeasonBlend.Look.BARE,
]


## The file of `summer_path` as it looks in `look`.
static func path(summer_path: String, look: SeasonBlend.Look) -> String:
	if look == SeasonBlend.Look.SUMMER:
		return summer_path
	var look_name: String = SeasonBlend.Look.keys()[look]
	return (
		"%s_%s.%s" % [summer_path.get_basename(), look_name.to_lower(), summer_path.get_extension()]
	)


## The file of the snow on the roof of a house, which has the size of its pictures, from the file
## of its unlit summer picture: kate.png has kate_snow_cover.png (see tools/art/cover.py).
static func roof_snow_path(unlit_summer_path: String) -> String:
	return (
		"%s_snow_cover.%s" % [unlit_summer_path.get_basename(), unlit_summer_path.get_extension()]
	)


## The file of a house picture in `look`, one of HOUSE_LOOKS.
static func house_path(summer_path: String, look: SeasonBlend.Look) -> String:
	assert(look in HOUSE_LOOKS, "a house has no picture for look %d" % look)
	return path(summer_path, look)
