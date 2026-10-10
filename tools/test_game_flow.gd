extends "res://tools/testing/harness.gd"
## Drives the real screens with synthetic touches: a whole solo round, then the
## way from the home screen to a round and back.

const SceneView := preload("res://scripts/scene_view.gd")
const FindScreen := preload("res://scripts/find_screen.gd")
const FindRound := preload("res://scripts/core/find_round.gd")
const Storage := preload("res://scripts/storage.gd")
const Ui := preload("res://scripts/ui.gd")

const SCRATCH := "user://test_flow_progress.json"
const TARGETS: Array[String] = ["crab", "starfish", "duck", "bucket", "cooler", "kite", "net", "buoy"]


func run() -> void:
	root.size = Vector2i(720, 1280)
	if FileAccess.file_exists(SCRATCH):
		DirAccess.remove_absolute(SCRATCH)
	await _test_round()
	await _test_navigation()
	DirAccess.remove_absolute(SCRATCH)


func _test_round() -> void:
	var screen := FindScreen.new()
	screen.name = "FindScreen"
	screen.scenario_id = "beach_1"
	screen.theme_id = "beach"
	screen.target_ids = TARGETS.duplicate()
	screen.progress_path = SCRATCH
	root.add_child(screen)
	await process_frame
	await process_frame

	var view: SceneView = screen.find_child("SceneView", true, false)
	check(view != null and view.size.x > 0.0 and view.size.y > 0.0, "the scene view has a size")
	if view == null:
		return
	check(view.find_child("Background", true, false).texture != null, "the illustration is shown")
	var chips: Control = screen.find_child("Chips", true, false)
	check(chips.get_child_count() == 8, "the list shows the 8 objects of the round")
	check(chips.size.x <= 720.0, "the list fits the screen width")
	check(screen.find_child("Chip_lifebuoy", true, false) == null, "objects outside the round are not listed")
	var status: Label = screen.find_child("StatusLabel", true, false)
	check(status.text == "Encuentra: 0 de 8", "status starts at 0 of 8")

	# Nothing of the interface may sit on top of the picture.
	var view_rect := view.get_global_rect()
	var covered := false
	for node_name: String in ["HintButton", "ZoomIn", "ZoomOut", "BackButton"]:
		if (screen.find_child(node_name, true, false) as Control).get_global_rect().intersects(view_rect):
			covered = true
	check(not covered, "no button covers the scene")

	# A wrong tap pauses the player: the next tap, even on a target, does nothing.
	_tap(view, view.view.world_to_screen(Vector2(700, 420)))
	check(screen.game_round.wrong_taps == 1 and view.find_child("Miss", true, false) != null,
			"a tap on scenery is a miss and leaves a mark")
	var crab_screen: Vector2 = view.view.world_to_screen(Vector2(312, 1249))
	_tap(view, crab_screen)
	check(screen.game_round.found.is_empty(), "a tap during the pause finds nothing")
	screen.game_round.tick(FindRound.LOCKOUT_SECONDS + 0.05)
	_tap(view, crab_screen + Vector2(10, -8))
	check(view.is_found("crab") and status.text == "Encuentra: 1 de 8", "after the pause an off-centre tap finds the crab")
	check(view.find_child("Found_crab", true, false) != null, "the found object gets a ring")
	check(is_equal_approx((screen.find_child("Chip_crab", true, false) as Control).modulate.a, 0.3),
			"its entry in the list is dimmed")
	_tap(view, crab_screen)
	check(screen.game_round.found.size() == 1 and screen.game_round.wrong_taps == 1,
			"tapping a found object again changes nothing")
	_tap(view, view.view.world_to_screen(Vector2(385, 177)))
	check(screen.game_round.wrong_taps == 2, "an object outside the round counts as a miss")
	screen.game_round.tick(FindRound.LOCKOUT_SECONDS + 0.05)

	# Drag, pinch and the zoom buttons move the view and are never taps.
	var taps_before: int = screen.game_round.wrong_taps
	view.zoom_by(2.0)
	view.view.center_on(Vector2(400, 400))
	var origin_before: Vector2 = view.view.origin
	_touch(view, 0, Vector2(400, 500), true)
	_drag(view, 0, Vector2(400, 500), Vector2(300, 420))
	_touch(view, 0, Vector2(300, 420), false)
	check(view.view.origin.x > origin_before.x and view.view.origin.y > origin_before.y, "dragging moves the scene")
	var zoom_before: float = view.view.zoom
	_touch(view, 0, Vector2(300, 500), true)
	_touch(view, 1, Vector2(400, 500), true)
	_drag(view, 1, Vector2(400, 500), Vector2(350, 500))
	check(view.view.zoom < zoom_before, "pinching in zooms out")
	_drag(view, 1, Vector2(350, 500), Vector2(500, 500))
	check(view.view.zoom > zoom_before, "spreading the fingers zooms in")
	_touch(view, 1, Vector2(500, 500), false)
	_touch(view, 0, Vector2(300, 500), false)
	zoom_before = view.view.zoom
	(screen.find_child("ZoomOut", true, false) as Button).pressed.emit()
	check(view.view.zoom < zoom_before, "the minus button zooms out")
	(screen.find_child("ZoomIn", true, false) as Button).pressed.emit()
	check_near(view.view.zoom, zoom_before, "the plus button zooms back in")
	check(screen.game_round.wrong_taps == taps_before and screen.game_round.found.size() == 1,
			"drags, pinches and zoom buttons are not taps")

	# Hint: moves the camera, draws a circle that contains a pending object, then cools down.
	var hint: Button = screen.find_child("HintButton", true, false)
	check(not hint.disabled and hint.text == "Pista", "the hint is ready")
	hint.pressed.emit()
	var marker: Node2D = view.find_child("Hint", true, false)
	check(marker != null and screen.game_round.hints_used == 1, "the hint draws a circle")
	if marker != null:
		var inside := false
		for object_id in screen.game_round.pending():
			var position: Vector2 = screen.scenario.find_object(object_id)["position"]
			if position.distance_to(marker.position) <= FindScreen.HINT_RADIUS:
				inside = true
		check(inside, "the circle contains a pending object")
		check(marker.position.distance_to(view.view.screen_to_world(view.size * 0.5)) < 400.0,
				"the camera moved towards the hint")
	check(hint.disabled and hint.text.begins_with("Pista en "), "the hint button shows its cooldown")
	hint.pressed.emit()
	check(screen.game_round.hints_used == 1, "pressing it during the cooldown does nothing")

	# Finish the round.
	var finished := {"stars": -1}
	screen.round_finished.connect(func(stars: int, _seconds: float) -> void: finished["stars"] = stars)
	for object_id: String in screen.game_round.pending():
		var position: Vector2 = screen.scenario.find_object(object_id)["position"]
		view.view.center_on(position)
		_tap(view, view.view.world_to_screen(position))
	check(screen.game_round.is_complete() and status.text == "Encuentra: 8 de 8", "all 8 objects can be found")
	check(finished["stars"] == 2, "2 mistakes and 1 hint give 2 stars (got %d)" % finished["stars"])
	await process_frame
	var panel: Control = screen.find_child("ResultPanel", true, false)
	check(panel != null, "the result panel appears")
	if panel != null:
		check((panel.find_child("Stars", true, false)).filled == 2, "it shows the stars")
		check((panel.find_child("BestLabel", true, false) as Label).text == "¡Nuevo récord!", "the first time is a record")
		check((panel.find_child("DetailLabel", true, false) as Label).text == "2 errores, 1 pista", "it explains the stars")
		var requests := {"replay": 0, "exit": 0}
		screen.replay_requested.connect(func() -> void: requests["replay"] += 1)
		screen.exit_requested.connect(func() -> void: requests["exit"] += 1)
		(panel.find_child("ReplayButton", true, false) as Button).pressed.emit()
		(panel.find_child("ScenariosButton", true, false) as Button).pressed.emit()
		check(requests["replay"] == 1 and requests["exit"] == 1, "its buttons ask to replay and to leave")
	var saved := Storage.load_progress(SCRATCH)
	check(saved.completed("beach") == 1 and saved.best_stars("beach") == 2, "the result was saved")
	screen.queue_free()
	await process_frame


func _test_navigation() -> void:
	var main: Control = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	check(main.find_child("HomeScreen", true, false) != null, "the game opens on the home screen")
	check((main.find_child("TitleLine0", true, false) as Label).text == "Ojos"
			and (main.find_child("TitleLine1", true, false) as Label).text == "Curiosos", "which shows the game's name")
	check(main.find_child("SoundToggle", true, false) != null and main.find_child("VibrationToggle", true, false) != null,
			"and the sound and vibration switches")
	check((main.find_child("HeroPicture", true, false) as TextureRect).texture != null, "and a picture from the game")
	# Nothing may fall off the bottom, also on a short 16:9 screen (the root is 720x1280 here).
	var lowest: Control = main.find_child("CreditsButton", true, false)
	check(lowest != null and lowest.get_global_rect().end.y <= 1280.0,
			"the lowest button is on screen (ends at %s of 1280)" % str(lowest.get_global_rect().end.y))
	check(main.theme != null and main.theme.default_font != null, "the game font is applied to every screen")

	# The skin button cycles through the three skins and rebuilds the screen.
	var start_skin: String = Ui.skin.id
	var seen := {}
	for i in Ui.SKIN_IDS.size():
		var before: Node = main.find_child("HomeScreen", true, false)
		(main.find_child("SkinButton", true, false) as Button).pressed.emit()
		await process_frame
		seen[Ui.skin.id] = true
		check(main.find_child("HomeScreen", true, false) != before, "changing the skin rebuilds the home screen")
	check(seen.size() == Ui.SKIN_IDS.size() and Ui.skin.id == start_skin, "the skin button goes through every skin and back")

	(main.find_child("PlayButton", true, false) as Button).pressed.emit()
	await process_frame
	check(main.find_child("HomeScreen", true, false) == null and main.find_child("SelectScreen", true, false) != null,
			"Jugar opens the scenario list")
	var card: Button = main.find_child("Card_beach", true, false)
	check(card != null and not card.disabled, "the beach is listed and open")

	card.pressed.emit()
	await process_frame
	await process_frame
	var find: Control = main.find_child("FindScreen", true, false)
	check(find != null and ["beach_1", "beach_2"].has(find.scenario_id) and find.theme_id == "beach",
			"choosing it starts a round on one of its variants")
	if find != null:
		var drawn: Array[String] = find.target_ids
		var distinct := {}
		for object_id in drawn:
			distinct[object_id] = true
		check(drawn.size() == 8 and distinct.size() == 8, "the round draws 8 different objects")

		find.replay_requested.emit()
		await process_frame
		var again: Control = main.find_child("FindScreen", true, false)
		check(again != null and again != find, "replay starts a fresh round")
		main.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
		await process_frame
		check(main.find_child("SelectScreen", true, false) != null, "the back button leaves the round")
		main.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
		await process_frame
		check(main.find_child("HomeScreen", true, false) != null, "and then returns home")
	main.queue_free()
	await process_frame


func _tap(view: SceneView, at: Vector2) -> void:
	_touch(view, 0, at, true)
	_touch(view, 0, at, false)


func _touch(view: SceneView, index: int, at: Vector2, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = at
	event.pressed = pressed
	view._gui_input(event)


func _drag(view: SceneView, index: int, from: Vector2, to: Vector2) -> void:
	var event := InputEventScreenDrag.new()
	event.index = index
	event.position = to
	event.relative = to - from
	view._gui_input(event)
