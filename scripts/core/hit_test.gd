extends RefCounted
## Decides which findable object a tap lands on. Pure logic.
##
## Small fingers on a small screen need a generous target: the hit radius never
## drops below a finger-sized circle on screen, whatever the zoom. It is also
## capped in world units, so tapping a zoomed-out scene cannot sweep up
## everything in a wide area.

## Minimum hit radius in screen pixels (logical 720-wide layout).
const MIN_SCREEN_RADIUS := 44.0
## The object's own radius is enlarged by this factor.
const OBJECT_RADIUS_SCALE := 1.5
## Upper bound for the hit radius, in object radii.
const MAX_RADIUS_IN_OBJECTS := 4.0


## Hit radius in world pixels for an object of `object_radius` at `zoom`.
static func hit_radius(object_radius: float, zoom: float) -> float:
	var finger := MIN_SCREEN_RADIUS / maxf(zoom, 0.001)
	var wanted := maxf(object_radius * OBJECT_RADIUS_SCALE, finger)
	return minf(wanted, object_radius * MAX_RADIUS_IN_OBJECTS)


## Returns the id of the closest candidate hit by `world_point`, or "" if none.
## `candidates` is an Array of Dictionaries with "id" (String),
## "position" (Vector2, world pixels) and "radius" (float, world pixels).
static func pick(world_point: Vector2, candidates: Array, zoom: float) -> String:
	var best_id := ""
	var best_distance := INF
	for candidate: Dictionary in candidates:
		var position: Vector2 = candidate["position"]
		var distance := world_point.distance_to(position)
		if distance <= hit_radius(candidate["radius"], zoom) and distance < best_distance:
			best_distance = distance
			best_id = candidate["id"]
	return best_id
