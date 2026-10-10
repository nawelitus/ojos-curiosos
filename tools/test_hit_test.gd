extends "res://tools/testing/harness.gd"

const HitTest := preload("res://scripts/core/hit_test.gd")


func run() -> void:
	# Object radius 8 (a 16 px tile).
	check_near(HitTest.hit_radius(8.0, 4.0), 12.0, "zoomed in: 1.5x the object radius")
	check_near(HitTest.hit_radius(8.0, 2.0), 22.0, "mid zoom: a finger-sized circle on screen")
	check_near(HitTest.hit_radius(8.0, 1.0), 32.0, "zoomed out: capped at 4 object radii")
	check_near(HitTest.hit_radius(8.0, 0.0), 32.0, "zero zoom does not divide by zero")

	var key := {"id": "key", "position": Vector2(100, 100), "radius": 8.0}
	var egg := {"id": "egg", "position": Vector2(130, 100), "radius": 8.0}
	var both := [key, egg]

	check(HitTest.pick(Vector2(100, 100), both, 4.0) == "key", "direct tap hits the object")
	check(HitTest.pick(Vector2(111, 100), both, 4.0) == "key", "tap just outside the sprite still hits")
	check(HitTest.pick(Vector2(114, 100), both, 4.0) == "", "tap between two objects, beyond both radii, misses")
	check(HitTest.pick(Vector2(300, 300), both, 1.0) == "", "tap far away misses")
	check(HitTest.pick(Vector2(118, 100), both, 2.0) == "egg", "overlapping areas pick the closest object")
	check(HitTest.pick(Vector2(112, 100), both, 2.0) == "key", "overlapping areas pick the closest object (other side)")
	check(HitTest.pick(Vector2(100, 100), [], 2.0) == "", "no candidates means a miss")
	check(HitTest.pick(Vector2(100, 131), both, 1.0) == "key", "zoomed out tap within the cap hits")
	check(HitTest.pick(Vector2(100, 133), both, 1.0) == "", "zoomed out tap beyond the cap misses")
