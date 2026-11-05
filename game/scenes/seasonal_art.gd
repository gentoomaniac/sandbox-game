class_name SeasonalArt
extends RefCounted
## Which picture file shows a season. Summer is the plain file; the other seasons add
## their name before the extension, as the art generator writes them (tools/art/seasons.py):
## terrain_winter.png, small_house_lit_autumn.png.


## The file of `summer_path` as it looks in `season`.
static func path(summer_path: String, season: GameClock.Season) -> String:
	if season == GameClock.Season.SUMMER:
		return summer_path
	var season_name: String = GameClock.SEASON_NAMES[season]
	return (
		"%s_%s.%s"
		% [summer_path.get_basename(), season_name.to_lower(), summer_path.get_extension()]
	)
