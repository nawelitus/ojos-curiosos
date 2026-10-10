extends SceneTree
## Base for headless tests. A test file extends this script and overrides run().
## tools/run_tests.ps1 looks for the "ALL TESTS PASSED" line and the exit code.

var _failures: int = 0


func _initialize() -> void:
	# The root window only joins the tree after _initialize returns, so nodes
	# added before the first frame never get _ready.
	await process_frame
	@warning_ignore("redundant_await")
	await run()
	if _failures == 0:
		print("ALL TESTS PASSED")
	else:
		print("TESTS FAILED: ", _failures)
	quit(1 if _failures > 0 else 0)


## Override in each test file. May await.
func run() -> void:
	pass


func check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: ", description)
	else:
		_failures += 1
		print("FAIL: ", description)


func check_near(actual: float, expected: float, description: String, tolerance: float = 0.001) -> void:
	check(absf(actual - expected) <= tolerance, "%s (got %s, expected %s)" % [description, actual, expected])


func check_vec(actual: Vector2, expected: Vector2, description: String, tolerance: float = 0.01) -> void:
	check(actual.distance_to(expected) <= tolerance, "%s (got %s, expected %s)" % [description, actual, expected])
