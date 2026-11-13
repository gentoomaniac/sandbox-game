

## 219. Cloud shadows look broken: hard lines instead of soft clouds

- [x] Done

Done: 2026-11-13. Cause: on the user's laptop Godot runs on the NVIDIA RTX 4070 (Vulkan, Forward+),
where the shared sine hash (`fract(sin(dot(p, ...)) * 43758.5)`) of large world coordinates gave
other values than on the AMD desktop, which showed as hard-edged rectangular blocks. hash.gdshaderinc
now hashes the float bits with PCG2D (same bits on every GPU; rain, splashes, water, fire and lily
pads changed their random patterns only). The cloud shadows use gradient noise with a small domain
warp (soft rounded patches), a pattern size that no longer follows the cover (`size_growth` removed,
so no pulsing), and a pattern that repeats every 32 patches so the drift wraps without a jump.

The user, 2026-11-12: "cloud are working but the textures are kind of broken. Full of hard lines
etc doesn't look like good at all."
- The user, 2026-11-13: "on my other system the cloud shadows look great". So the hard lines
  show on one machine only: first find what differs (GPU and driver, the renderer the project
  uses there and its shader float precision, window size and scale, how long the game had run,
  since the drift grows without bound) and reproduce it, before changing the look.
  The user, 2026-11-13: the lines show on this laptop (hybrid graphics: Intel Arc, Meteor Lake-P,
  and an NVIDIA RTX 4070 Max-Q; check which one Godot runs on), and look great on an AMD Ryzen 9
  with a Radeon RX 7900 GRE. Prime suspect: game/scenes/hash.gdshaderinc hashes with
  `fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453)`, whose sin of large world coordinates is
  computed with different precision per GPU and driver (known to give lines and patterns on Intel
  and some NVIDIA drivers). An integer hash (uint arithmetic, e.g. PCG or a 2D xxhash variant)
  gives the same bits on every GPU. The hash is shared (fog, precipitation, other shaders that
  include it): switching it changes their patterns too, so check them with screenshots.
  The lines show right from the start of the game (the user, 2026-11-13), so the unbounded drift
  is not the cause (still bound it).
- The shadows of task 194 (game/scenes/cloud_shadows.gdshader, numbers in data/lighting.cfg
  [cloud_shadows], fed by WeatherView) work, but the patches show hard lines. Take screenshots
  first (cloudy weather by day, `--weather cloudy`, both arts, standing still and while they drift)
  and find the cause. Suspects: the value noise interpolates on an axis-aligned grid, so its
  octaves (not rotated against each other) leave straight creases; the CONTRAST stretch and clamp
  flatten whole areas into plateaus with sharp rims; `size` follows the cover live, so the pattern
  rescales around the world origin when the cover changes; the drift offset grows without bound
  and the hash loses float precision after a while (which shows as banding).
- Fix it at the cause so the shadows read as soft, rounded clouds: a smoother noise (gradient or
  simplex noise, rotated octaves, perhaps a little domain warp for billowy shapes), soft edges with
  no straight lines or grid, no pulsing when the cover changes, and a drift kept bounded (wrap it
  without a jump). Still drawn in world pixels so it fits the pixel art; still cheap.
- The weather already has a wind direction (WeatherSample.wind_direction, slowly turning over
  days) and the shadows already drift with the full wind vector; keep that.
- Before/after screenshots for the user (both arts, light and heavy cover); numbers stay in
  data/lighting.cfg.
