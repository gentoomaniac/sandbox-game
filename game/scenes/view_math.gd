class_name ViewMath
extends RefCounted
## The numbers of the two-stage rendering, in one place so they can be tested.
##
## Stage one draws the world into a fixed-size viewport at one art pixel per render pixel,
## with the camera at a whole art pixel. Stage two shows part of that image on the window,
## scaled by `screen_scale`. The part is centred on the camera's real (fractional) target,
## which is how scrolling and zooming stay smooth although stage one never moves by less than
## a pixel: the world and the player stay on the art pixel grid, only the window's view of
## it moves by fractions.

const MIN_ZOOM := 0.5
const MAX_ZOOM := 2.0
## At zoom 1 the window shows this many art pixels from top to bottom (20×11 tiles at 16:9).
const DEFAULT_VISIBLE_HEIGHT := 180.0
## Widest view (zoom 0.5 at 16:9) plus a margin on every side for the sub-pixel offset.
const VIEWPORT_MARGIN := 4
const VIEWPORT_SIZE := Vector2i(640 + 2 * VIEWPORT_MARGIN, 360 + 2 * VIEWPORT_MARGIN)
## Zoom change of one mouse wheel notch.
const WHEEL_ZOOM_FACTOR := 1.1


static func clamp_zoom(zoom: float) -> float:
	return clampf(zoom, MIN_ZOOM, MAX_ZOOM)


static func zoom_after_wheel(zoom: float, notches: float) -> float:
	return clamp_zoom(zoom * pow(WHEEL_ZOOM_FACTOR, notches))


## Window pixels per art pixel. A window wider than 16:9 would need more width than the
## viewport has, so it shows a bit less than the zoom asks for instead.
static func screen_scale(window_size: Vector2, zoom: float) -> float:
	var for_height := window_size.y * zoom / DEFAULT_VISIBLE_HEIGHT
	var for_width := window_size.x / (VIEWPORT_SIZE.x - 2 * VIEWPORT_MARGIN)
	return maxf(for_height, for_width)


## The art pixels the window shows.
static func visible_size(window_size: Vector2, zoom: float) -> Vector2:
	return window_size / screen_scale(window_size, zoom)


## The camera position the viewport is drawn at: a whole art pixel.
static func snapped_camera(target: Vector2) -> Vector2:
	return target.round()


## Top left of the shown part, in pixels of the viewport image.
static func region_origin(target: Vector2, window_size: Vector2, zoom: float) -> Vector2:
	var remainder := target - snapped_camera(target)
	return Vector2(VIEWPORT_SIZE) / 2.0 + remainder - visible_size(window_size, zoom) / 2.0


static func window_to_world(
	window_position: Vector2, window_size: Vector2, target: Vector2, zoom: float
) -> Vector2:
	return target + (window_position - window_size / 2.0) / screen_scale(window_size, zoom)


static func world_to_window(
	world_position: Vector2, window_size: Vector2, target: Vector2, zoom: float
) -> Vector2:
	return window_size / 2.0 + (world_position - target) * screen_scale(window_size, zoom)
