extends "res://tools/testing/harness.gd"

const ViewTransform := preload("res://scripts/core/view_transform.gd")


func run() -> void:
	# World 768x1024 in a 720x1000 view: width needs 0.9375, height 0.9766.
	var view := ViewTransform.new(Vector2(768, 1024), Vector2(720, 1000))
	check_near(view.min_zoom(), 1000.0 / 1024.0, "min zoom covers the view")
	check_near(view.zoom, view.min_zoom(), "starts fully zoomed out")
	check_vec(view.origin, Vector2.ZERO, "starts at the top-left corner")

	view.pan(Vector2(5000, 5000))
	check_vec(view.origin, Vector2.ZERO, "cannot pan past the top-left corner")
	view.pan(Vector2(-5000, -5000))
	var visible := view.view_size / view.zoom
	check_vec(view.origin, view.world_size - visible, "cannot pan past the bottom-right corner")

	view = ViewTransform.new(Vector2(768, 1024), Vector2(720, 1000))
	var anchor_screen := Vector2(360, 500)
	var anchor_world := view.screen_to_world(anchor_screen)
	view.zoom_at(anchor_screen, 2.0)
	check_near(view.zoom, view.min_zoom() * 2.0, "zoom_at multiplies the zoom")
	check_vec(view.world_to_screen(anchor_world), anchor_screen, "zoom keeps the anchor point in place")

	view.zoom_at(anchor_screen, 1000.0)
	check_near(view.zoom, view.max_zoom(), "zoom is capped at the maximum")
	view.zoom_at(anchor_screen, 0.0001)
	check_near(view.zoom, view.min_zoom(), "zoom is capped at the minimum")

	view.zoom_at(Vector2.ZERO, 3.0)
	var before := view.screen_to_world(Vector2(100, 100))
	view.pan(Vector2(-60, -30))
	check_vec(view.screen_to_world(Vector2(40, 70)), before, "pan moves the scene with the finger")

	view.center_on(Vector2(400, 600))
	check_vec(view.screen_to_world(view.view_size * 0.5), Vector2(400, 600), "center_on centres a world point")
	check_vec(view.world_to_screen(view.screen_to_world(Vector2(123, 456))), Vector2(123, 456),
			"screen/world conversions are inverse")

	var late := ViewTransform.new(Vector2(768, 1024), Vector2.ZERO)
	late.resize(Vector2(720, 1000))
	check_near(late.zoom, 1000.0 / 1024.0, "a view created with no size recovers on resize")
	check(is_finite(late.origin.x) and is_finite(late.origin.y), "origin stays finite after that resize")

	view.resize(Vector2(360, 500))
	check(view.zoom >= view.min_zoom() and view.zoom <= view.max_zoom(), "resize keeps zoom within limits")
