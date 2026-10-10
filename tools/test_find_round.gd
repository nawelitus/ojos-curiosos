extends "res://tools/testing/harness.gd"

const FindRound := preload("res://scripts/core/find_round.gd")


func run() -> void:
	_test_draw()
	_test_taps_and_lockout()
	_test_hints()
	_test_stars()


func _test_draw() -> void:
	var pool: Array[String] = ["a", "b", "c", "d", "e", "f", "g", "h", "i", "j"]
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var first := FindRound.draw_targets(pool, 8, rng)
	var distinct := {}
	for id in first:
		distinct[id] = true
	check(first.size() == 8 and distinct.size() == 8, "draws the requested number of different targets")
	check(pool.size() == 10, "drawing does not change the pool")
	rng.seed = 42
	check(FindRound.draw_targets(pool, 8, rng) == first, "the same seed gives the same draw")
	rng.seed = 43
	check(FindRound.draw_targets(pool, 8, rng) != first, "another seed gives another draw")
	check(FindRound.draw_targets(pool, 50, rng).size() == 10, "a small pool gives everything it has")
	var none: Array[String] = []
	check(FindRound.draw_targets(none, 8, rng).is_empty(), "an empty pool gives nothing")


func _test_taps_and_lockout() -> void:
	var game := FindRound.new(_targets())
	check(not game.is_complete() and game.pending().size() == 3, "starts with everything pending")

	check(game.register_tap("crab") == FindRound.Tap.FOUND, "tapping a target finds it")
	check(game.found == ["crab"] and game.pending() == ["duck", "kite"], "found and pending are updated")
	check(game.register_tap("crab") == FindRound.Tap.IGNORED and game.wrong_taps == 0,
			"tapping a found object again is ignored, with no penalty")

	check(game.register_tap("") == FindRound.Tap.MISS, "tapping nothing is a miss")
	check(game.wrong_taps == 1 and game.is_locked(), "a miss counts and starts the pause")
	check(game.register_tap("duck") == FindRound.Tap.LOCKED and game.found.size() == 1,
			"taps during the pause do nothing")
	check(game.register_tap("") == FindRound.Tap.LOCKED and game.wrong_taps == 1,
			"misses during the pause are not counted again")
	game.tick(FindRound.LOCKOUT_SECONDS - 0.1)
	check(game.is_locked(), "the pause lasts its full length")
	game.tick(0.2)
	check(not game.is_locked(), "the pause ends")
	check(game.register_tap("duck") == FindRound.Tap.FOUND, "after the pause taps work again")

	check(game.register_tap("lifebuoy") == FindRound.Tap.MISS, "an object outside the round is a miss")
	game.tick(2.0)
	check(game.register_tap("kite") == FindRound.Tap.FOUND and game.is_complete(), "finding the last one completes the round")
	var time_at_end := game.elapsed
	game.tick(5.0)
	check(is_equal_approx(game.elapsed, time_at_end), "the clock stops when the round is complete")
	check(game.register_tap("") == FindRound.Tap.IGNORED and game.wrong_taps == 2,
			"taps after the end are ignored")
	game.tick(-3.0)
	check(is_equal_approx(game.elapsed, time_at_end), "a negative tick is ignored")


func _test_hints() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var game := FindRound.new(_targets())
	check(game.can_hint() and is_zero_approx(game.hint_wait()), "a hint is available from the start")
	game.register_tap("crab")
	var hinted := game.use_hint(rng)
	check(hinted == "duck" or hinted == "kite", "a hint points at a pending target")
	check(game.hints_used == 1 and not game.can_hint(), "using a hint counts and starts the cooldown")
	check(game.use_hint(rng) == "" and game.hints_used == 1, "no hint during the cooldown")
	check_near(game.hint_wait(), FindRound.HINT_COOLDOWN_SECONDS, "the wait is the full cooldown")
	game.tick(FindRound.HINT_COOLDOWN_SECONDS - 1.0)
	check(not game.can_hint(), "still cooling down one second before")
	game.tick(1.5)
	check(game.can_hint(), "the hint comes back after the cooldown")
	game.register_tap("duck")
	game.register_tap("kite")
	check(not game.can_hint() and game.use_hint(rng) == "", "no hints once the round is complete")


func _test_stars() -> void:
	var clean := FindRound.new(_targets())
	check(clean.stars() == 0, "no stars before finishing")
	_find_all(clean)
	check(clean.stars() == 3, "no mistakes and no hints: 3 stars")

	var two_mistakes := FindRound.new(_targets())
	_miss(two_mistakes, 2)
	_find_all(two_mistakes)
	check(two_mistakes.stars() == 3, "two mistakes still keep the star")

	var three_mistakes := FindRound.new(_targets())
	_miss(three_mistakes, 3)
	_find_all(three_mistakes)
	check(three_mistakes.stars() == 2, "three mistakes lose one star")

	var hinted := FindRound.new(_targets())
	hinted.use_hint(RandomNumberGenerator.new())
	_find_all(hinted)
	check(hinted.stars() == 2, "using a hint loses one star")

	var both := FindRound.new(_targets())
	_miss(both, 5)
	both.use_hint(RandomNumberGenerator.new())
	_find_all(both)
	check(both.stars() == 1, "finishing always earns one star")


func _targets() -> Array[String]:
	return ["crab", "duck", "kite"]


func _miss(game: FindRound, times: int) -> void:
	for i in times:
		game.register_tap("")
		game.tick(FindRound.LOCKOUT_SECONDS + 0.01)


func _find_all(game: FindRound) -> void:
	for target in game.pending():
		game.register_tap(target)
