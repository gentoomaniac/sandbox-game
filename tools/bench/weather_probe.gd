extends SceneTree
## Prints a year of weather for a few seeds: the share of wet hours, the longest wet spell, the
## wet hours, snow days and days with cloud shadows per season, and the day-by-day strip of one season.
## godot --headless --path . -s tools/bench/weather_probe.gd -- [season 0-3, default 0] [seeds...]


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var strip_season := int(args[0]) if args.size() > 0 else GameClock.Season.SPRING
	var seeds: Array[int] = [1, 12345, 987654]
	if args.size() > 1:
		seeds.assign(Array(args.slice(1)).map(func(text: String) -> int: return int(text)))
	print(
		"seed | wet share | longest spell | wet hours spring/summer/autumn/winter | ",
		"snow days in winter | days with cloud shadows at noon spring/summer/autumn/winter"
	)
	var strips := ""
	for world_seed in seeds:
		var year := WeatherYear.new(world_seed)
		var wet_hours: Array[int] = []
		var cloudy_days: Array[int] = []
		for season in 4:
			wet_hours.append(year.wet_hours_in(season))
			cloudy_days.append(year.days_partly_clouded_in(season))
		print(
			"%d | %.1f %% | %d h | %s | %d | %s"
			% [
				world_seed,
				year.wet_share() * 100.0,
				year.longest_spell(),
				wet_hours,
				year.snow_days_in(GameClock.Season.WINTER),
				cloudy_days
			]
		)
		strips += (
			"\nseed %d, season %d (# wet, . dry; a line per day, 24 hours)\n%s\n"
			% [world_seed, strip_season, year.season_strip(strip_season)]
		)
	print(strips)
	quit()
