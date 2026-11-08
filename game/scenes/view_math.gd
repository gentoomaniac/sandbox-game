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

## Zoom 1 shows 640×360 art pixels (20×11 tiles of the 32 px art, a whole ×3 at 1080p); the
## game starts at the widest zoom, which shows twice that each way, 40×22 tiles as it did
## before the art went to 32 px. Zoom 2 shows half as much each way as zoom 1.
const MIN_ZOOM := 0.5
const MAX_ZOOM := 2.0
const ZOOM_ONE_VISIBLE_HEIGHT := 360.0
## What the widest view (zoom `MIN_ZOOM` at 16:9) shows, in art pixels.
const WIDEST_VISIBLE_SIZE := Vector2i(1280, 720)
## The widest view plus a margin on every side for the sub-pixel offset.
const VIEWPORT_MARGIN := 4
const VIEWPORT_SIZE := WIDEST_VISIBLE_SIZE + Vector2i.ONE * 2 * VIEWPORT_MARGIN
## Zoom change of one mouse wheel notch.
const WHEEL_ZOOM_FACTOR := 1.1


static func clamp_zoom(zoom: float) -> float:
	return clampf(zoom, MIN_ZOOM, MAX_ZOOM)


static func zoom_after_wheel(zoom: float, notches: float) -> float:
	return clamp_zoom(zoom * pow(WHEEL_ZOOM_FACTOR, notches))


## Window pixels per art pixel. A window wider than 16:9 would need more width than the
## viewport has, so it shows a bit less than the zoom asks for instead.
static func screen_scale(window_size: Vector2, zoom: float) -> float:
	var for_height := window_size.y * zoom / ZOOM_ONE_VISIBLE_HEIGHT
	var for_width := window_size.x / WIDEST_VISIBLE_SIZE.x
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


## A position in UI units (what the mouse reports) as window pixels. `ui_size` is the UI's
## visible area, which shrinks as the UI scale grows: the world is drawn on the whole window
## whatever the UI scale is, so only this conversion knows about it.
static func ui_to_window(ui_position: Vector2, window_size: Vector2, ui_size: Vector2) -> Vector2:
	return ui_position * window_size / ui_size


static func window_to_world(
	window_position: Vector2, window_size: Vector2, target: Vector2, zoom: float
) -> Vector2:
	return target + (window_position - window_size / 2.0) / screen_scale(window_size, zoom)


static func world_to_window(
	world_position: Vector2, window_size: Vector2, target: Vector2, zoom: float
) -> Vector2:
	return window_size / 2.0 + (world_position - target) * screen_scale(window_size, zoom)
