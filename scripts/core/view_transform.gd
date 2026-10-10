extends RefCounted
## Pan and zoom maths for a large scene shown inside a smaller viewport.
## Pure logic: no nodes, no input. Screen coordinates are local to the view,
## world coordinates are scene pixels.

## Illustrations are about as wide as the screen in pixels, so zooming further
## than this only shows blur.
const MAX_ZOOM_FACTOR := 3.0

var world_size: Vector2
var view_size: Vector2
var zoom: float = 1.0
## World position shown at the top-left corner of the view.
var origin: Vector2 = Vector2.ZERO


func _init(p_world_size: Vector2, p_view_size: Vector2) -> void:
	world_size = p_world_size
	view_size = p_view_size
	zoom = min_zoom()
	_clamp_origin()


## Smallest zoom allowed: the scene always covers the whole view.
func min_zoom() -> float:
	if world_size.x <= 0.0 or world_size.y <= 0.0:
		return 1.0
	return maxf(view_size.x / world_size.x, view_size.y / world_size.y)


func max_zoom() -> float:
	return min_zoom() * MAX_ZOOM_FACTOR


func screen_to_world(screen_point: Vector2) -> Vector2:
	return origin + screen_point / zoom


func world_to_screen(world_point: Vector2) -> Vector2:
	return (world_point - origin) * zoom


func resize(new_view_size: Vector2) -> void:
	if zoom <= 0.0 or view_size.x <= 0.0 or view_size.y <= 0.0:
		# The view had no size yet: start over, fully zoomed out.
		view_size = new_view_size
		zoom = min_zoom()
		origin = Vector2.ZERO
		_clamp_origin()
		return
	var center := screen_to_world(view_size * 0.5)
	view_size = new_view_size
	zoom = clampf(zoom, min_zoom(), max_zoom())
	origin = center - view_size * 0.5 / zoom
	_clamp_origin()


func pan(screen_delta: Vector2) -> void:
	origin -= screen_delta / zoom
	_clamp_origin()


## Multiplies the zoom by `factor`, keeping the world point under `screen_point` in place.
func zoom_at(screen_point: Vector2, factor: float) -> void:
	var anchor := screen_to_world(screen_point)
	zoom = clampf(zoom * factor, min_zoom(), max_zoom())
	origin = anchor - screen_point / zoom
	_clamp_origin()


func center_on(world_point: Vector2) -> void:
	origin = world_point - view_size * 0.5 / zoom
	_clamp_origin()


func _clamp_origin() -> void:
	var visible := view_size / zoom
	origin.x = clampf(origin.x, 0.0, maxf(0.0, world_size.x - visible.x))
	origin.y = clampf(origin.y, 0.0, maxf(0.0, world_size.y - visible.y))
