

## 221. Rain comes in spells of hours, not days; autumn is the wettest season

- [x] Done

Done: 2026-11-13. Humidity has octaves of its own (HUMIDITY_OCTAVES in weather.gd, mostly of
hours) instead of sharing the wind's gust octaves (spells of days), and the seasonal humidity in
data/weather.cfg was retuned (spring 44, summer 49, autumn 66, winter 52 mean; summer cloudiness
-0.05). Rain or snow now comes in spells of 15 to 25 h at most, 13 to 17 % of hours, autumn the
wettest and spring the driest, for seeds 1, 12345 and 987654 (tests/test_weather_year.gd).
`make weather-probe` prints the year. Side effect: midwinter hours with snow fell from 42 % to 16 %;
snow still lies on 23 to 28 winter days. Existing saves get the new weather (it is a function of
seed and time).

The user, 2026-11-13: "is the weather affected by skip? I skipped like 20 times and still had
rain" (after `weather auto`). Skip does change the weather (Weather.at is a function of the day
and minute), but a probe over one year (rain > 0.05 per hour, tile 0,0) showed spells far too long
and the seasons unlike the coast:

| seed | wet hours | longest spell | wet hours spring / summer / autumn / winter |
|---|---|---|---|
| 1 | 10 % | 22 h | 27 / 20 / 176 / 58 |
| 12345 | 20 % | 112 h | 358 / 47 / 162 / 12 |
| 987654 | 20 % | 64 h | 254 / 23 / 265 / 22 |

- Tune the weather (game/state/weather.gd, data/weather.cfg: the humidity noise octaves and the
  seasonal curves) so rain comes as showers and passing fronts: a spell lasts hours, rarely more
  than about a day, with dry hours between; the North Frisian coast's year: autumn and early
  winter the wettest, spring the driest, summer showery. Pick the numbers into data/weather.cfg
  (the user tunes them).
- Keep what depends on it working: the forced weathers, snow (SnowCover), soil wetness and
  farming upkeep (rain_in_hour), the thunder, the cloud cover (task 194/219), the ambience.
- A test over a year for a few seeds: the longest spell under a bound, wet hours per season in
  the intended order, a share of wet hours in a range. A short report for the user with the new
  table (as above) and a day-by-day picture of one season.
