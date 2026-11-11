# Lighting and look

- **Rendering in two stages:**
  1. The world is rendered **on the art-pixel grid** (one art pixel = one render pixel) into
     an off-screen image of at most about 1280×720 plus a small margin. Lighting, tint and
     glow are computed there, so light lands exactly on the pixel grid.
  2. That image is scaled to the screen **steplessly** with a sharp-bilinear filter:
     pixels stay sharp, only one row of screen pixels blends at their edges. Zoom and
     camera movement stay smooth at any value, without uneven pixels.
- **UI** is rendered separately at native resolution.
- **Tiles: 32×32** (decided 2026-11-08, after the mockup in review/resolution-mockup-2026-11-08:
  the 16×16 art was "early PC, almost C64"; small animals and legs one pixel wide did not read).
  The widest view is 1280×720 art pixels (40×22 tiles, the area the 16 px art showed at its
  widest zoom 0.5; task 118), an art pixel 1.5 screen pixels at 1080p. Until all
  art is redrawn at 32 px, the generators' 16 px output is doubled pixel for pixel (tasks 106 and
  on); the people are drawn at 32 px since task 113, the farm animals since task 114, the wild
  animals, the flames, the hit particles and the weather (rain, splashes, snow, wind, fog) since
  task 116, the small animals a little larger than life, the ground (terrain, paths, soil,
  water, mud and their decorations) since task 107, calm so that what stands on it reads, the
  buildings since task 110, their doors about 60 px high so the people fit through, the
  plants (trees, the pollard willow, bushes, tall grass, fern, reeds, the meadow flowers, rocks,
  stumps and trunks) since task 108, the interiors and furniture since task 112, the beds as
  long as the people lying in them, and the walls, fences, the dyke, the camp and the placed
  objects since task 111, the dyke a bank that bends round its corners and the Ewer in scale
  with the people. The 16 px art of a redrawn group stays in the game as the
  classic art, a setting (see Settings in [Menus and settings](menus-and-hud.md)).
  (Was: 16×16, 320×180 at zoom 1.)
- **Stepless zoom** from the widest view (1280×720 art pixels, zoom 0.5) in to zoom 2
  (320×180; zoom 1 is 640×360); the game starts at the widest (the user zooms out fully
  anyway, 2026-11-08). The keys `=` and `-` (also the keypad's + and −; actions `zoom_in` and
  `zoom_out`, rebindable) and Ctrl and the mouse wheel zoom; the wheel alone steps through the
  hotbar. Zoom is a setting of the session, not saved. Between task 106 and task 118 the
  widest view was 640×360 (20×11 tiles), a quarter of what the 16 px art showed.
- **Smooth camera following:** the camera follows the player's exact position, so the
  world scrolls at sub-pixel precision; the player, drawn on the pixel grid, may wobble by up
  to half an art pixel. Chosen over a pixel-locked camera (2026-11-05).
- **Camera API** for scripted moves (cutscenes later): follow a target, move to a point,
  zoom to a value, chain moves in a sequence. The mouse wheel and the zoom keys use the same zoom.
- **Standard effects:**
  - **day and night tint:** the whole picture changes colour with the time of day (warm
    morning, neutral noon, orange dusk, a dark blue night: since task 177 little more than
    shapes away from a light, but not black). Its colours and when dusk and dawn come are in
    `data/lighting.cfg` (`LightingRules`). The lights are added on top of the tint (Godot's
    CanvasModulate with additive PointLight2Ds), so they shine as brightly in the darkest night;
  - **point lights:** campfire, torches, lit windows at night, the lantern the player carries
    (task 177), with a slight flicker.
    Dark nights make light sources valuable, which ties in with keeping creatures away;
  - **subtle glow/bloom** on bright light sources. Keep it subtle.
- **Later: normal maps** on sprites and tiles, so light gives the pixel art relief. This
  is mostly an art cost. Code should not rule it out.
- **See-through occluders:** when the character is behind something (tree, building,
  other tall object), that object becomes translucent in a soft-edged circle around the
  character, so the character stays visible. Only objects in front of the character fade;
  objects behind it stay as they are. Defaults (tunable): radius about 2 tiles around
  the character's centre, about 35 % opacity inside, soft edge.
- **Left out for now:** shadows cast by objects.
