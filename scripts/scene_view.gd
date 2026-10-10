extends Control
## Shows a scenario and lets the player move around it: one finger drags, two
## fingers pinch to zoom, a short tap tries to find an object. It reports taps;
## the rules (what counts, pauses, score) belong to the round.

## `object_id` is the target under the finger, or "" if there is none.
signal tapped(object_id: String, world_point: Vector2)

const Scenario := preload("res://scripts/core/scenario.gd")
const ScenarioLoader := preload("res://scripts/scenario_loader.gd")
const ViewTransform := preload("res://scripts/core/view_transform.gd")
const HitTest := preload("res://scripts/core/hit_test.gd")
const SceneMarker := preload("res://scripts/scene_marker.gd")

## A touch that moves further than this (screen pixels) is a drag, not a tap.
const TAP_SLOP := 18.0
const WHEEL_ZOOM_STEP := 1.15
## Gap between an object and the ring drawn around it once found (picture pixels).
const MARKER_MARGIN := 6.0
## Zoom used when a hint moves the camera, as a multiple of the minimum zoom.
const HINT_ZOOM := 1.6
const HINT_SECONDS := 4.0

var view: ViewTransform

var _scenario: Scenario
var _world: Node2D
var _targets := {}        # object id -> true, objects that can be found now
var _found := {}          # object id -> true
var _touches := {}        # touch index -> last position (local)
var _press_position := Vector2.ZERO
var _tap_candidate := false


func _init() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP


func setup(scenario: Scenario) -> void:
	_scenario = scenario
	if _world != null:
		_world.queue_free()
	_targets.clear()
	_found.clear()

	_world = Node2D.new()
	_world.name = "World"
	add_child(_world)

	var background := Sprite2D.new()
	background.name = "Background"
	background.centered = false
	background.texture = ScenarioLoader.illustration(scenario)
	_world.add_child(background)

	view = ViewTransform.new(scenario.world_size(), size)
	_apply_view()


## Only these objects react to taps; the rest of the pool is just part of the picture.
func set_targets(object_ids: Array) -> void:
	_targets.clear()
	for object_id: String in object_ids:
		_targets[object_id] = true


## `color` lets the multiplayer round ring each find in its finder's colour.
func mark_found(object_id: String, color: Variant = null) -> void:
	var object := _scenario.find_object(object_id)
	if _found.has(object_id) or object.is_empty():
		return
	_found[object_id] = true
	var marker := SceneMarker.new()
	marker.name = "Found_%s" % object_id
	marker.position = object["position"]
	marker.radius = object["radius"] + MARKER_MARGIN
	if color != null:
		marker.color = color
	_world.add_child(marker)


func is_found(object_id: String) -> bool:
	return _found.has(object_id)


## Small cross where a wrong tap landed; it fades while the pause lasts.
func show_miss(world_point: Vector2, seconds: float) -> void:
	var marker := SceneMarker.new()
	marker.name = "Miss"
	marker.shape = SceneMarker.Shape.CROSS
	marker.position = world_point
	marker.radius = 16.0 / view.zoom
	marker.line_width = 5.0 / view.zoom
	_world.add_child(marker)
	_fade_out(marker, seconds)


## Moves the camera near `world_point` and draws a wide circle around the area.
func show_hint(world_point: Vector2, radius: float) -> void:
	view.zoom_at(size * 0.5, view.min_zoom() * HINT_ZOOM / view.zoom)
	view.center_on(world_point)
	_apply_view()
	var marker := SceneMarker.new()
	marker.name = "Hint"
	marker.position = world_point
	marker.radius = radius
	marker.line_width = 6.0
	marker.color = Color("ffb703")
	_world.add_child(marker)
	_fade_out(marker, HINT_SECONDS)


func zoom_by(factor: float) -> void:
	if view == null:
		return
	view.zoom_at(size * 0.5, factor)
	_apply_view()


## Handles a tap at a local position. Public so tests can drive it directly.
func tap(local_point: Vector2) -> void:
	if view == null:
		return
	var world_point := view.screen_to_world(local_point)
	var candidates: Array = []
	for object in _scenario.objects:
		if _targets.has(object["id"]):
			candidates.append(object)
	tapped.emit(HitTest.pick(world_point, candidates, view.zoom), world_point)


func _fade_out(marker: Node2D, seconds: float) -> void:
	var tween := marker.create_tween()
	tween.tween_property(marker, "modulate:a", 0.0, seconds).set_ease(Tween.EASE_IN)
	tween.tween_callback(marker.queue_free)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and view != null:
		view.resize(size)
		_apply_view()


func _gui_input(event: InputEvent) -> void:
	if view == null:
		return
	if event is InputEventScreenTouch:
		_on_touch(event)
	elif event is InputEventScreenDrag:
		_on_drag(event)
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			view.zoom_at(event.position, WHEEL_ZOOM_STEP)
			_apply_view()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			view.zoom_at(event.position, 1.0 / WHEEL_ZOOM_STEP)
			_apply_view()


func _on_touch(event: InputEventScreenTouch) -> void:
	if event.pressed:
		_touches[event.index] = event.position
		_tap_candidate = _touches.size() == 1
		_press_position = event.position
		return
	var was_tap := _tap_candidate and _touches.size() == 1 and _touches.has(event.index)
	_touches.erase(event.index)
	_tap_candidate = false
	if was_tap:
		tap(event.position)
	accept_event()


func _on_drag(event: InputEventScreenDrag) -> void:
	if not _touches.has(event.index):
		return
	var previous: Vector2 = _touches[event.index]
	if _touches.size() == 1:
		_touches[event.index] = event.position
		if _tap_candidate and event.position.distance_to(_press_position) > TAP_SLOP:
			_tap_candidate = false
		if not _tap_candidate:
			view.pan(event.position - previous)
			_apply_view()
	elif _touches.size() == 2:
		var other := _other_touch(event.index)
		var old_distance := previous.distance_to(other)
		var new_distance := event.position.distance_to(other)
		var old_middle := (previous + other) * 0.5
		var new_middle := (event.position + other) * 0.5
		_touches[event.index] = event.position
		if old_distance > 1.0 and new_distance > 1.0:
			view.zoom_at(new_middle, new_distance / old_distance)
		view.pan(new_middle - old_middle)
		_apply_view()
	accept_event()


func _other_touch(index: int) -> Vector2:
	for other_index: int in _touches:
		if other_index != index:
			return _touches[other_index]
	return Vector2.ZERO


func _apply_view() -> void:
	_world.scale = Vector2(view.zoom, view.zoom)
	_world.position = -view.origin * view.zoom
