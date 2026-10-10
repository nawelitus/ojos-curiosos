extends SceneTree
## Renders the real screens of the game in chosen states and saves them as PNGs
## for the Play Store listing. Dev-only: it needs a window, so run it with the
## Godot executable WITHOUT --headless:
##
##   godot --path . --quit-after 4000 -s tools/render_store_shots.gd -- <output folder>
##
## The pictures come out larger than 1080x1920 on a scaled display;
## tools/make_store_assets.py brings them to the exact store size.

const Ui := preload("res://scripts/ui.gd")
const Catalog := preload("res://scripts/core/catalog.gd")
const Progress := preload("res://scripts/core/progress.gd")
const Scenario := preload("res://scripts/core/scenario.gd")
const ScenarioLoader := preload("res://scripts/scenario_loader.gd")
const Storage := preload("res://scripts/storage.gd")
const HomeScreen := preload("res://scripts/home_screen.gd")
const SelectScreen := preload("res://scripts/select_screen.gd")
const FindScreen := preload("res://scripts/find_screen.gd")
const ResultPanel := preload("res://scripts/result_panel.gd")
const LanMenuScreen := preload("res://scripts/net/lan_menu_screen.gd")
const LanRoundScreen := preload("res://scripts/net/lan_round_screen.gd")

const SIZE := Vector2i(1080, 1920)

var _out: String


func _initialize() -> void:
	await process_frame
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		print("SHOTS usage: -- <output folder>")
		quit(2)
		return
	_out = args[0]
	DirAccess.make_dir_recursive_absolute(_out)
	root.size = SIZE
	await process_frame

	await _home("light", "1_inicio")
	await _select("light", "2_escenarios")
	await _round("kids", "farm_1", "farm",
			["tractor", "cow", "scarecrow", "pumpkin", "duck", "rowboat", "beehive", "pig"],
			["cow", "duck", "pumpkin"], false, "3_buscando")
	await _round("dark", "space_1", "space",
			["rocket", "saturn", "astronaut", "robot", "rover", "dog", "tank", "ufo"],
			["rocket", "dog"], true, "4_pista")
	await _result("kids", "5_resultado")
	await _lan_menu("dark", "6_sala")
	await _lan_round("light", "7_en_red")
	await _home("kids", "8_infantil")
	print("SHOTS done")
	quit()


## A full-screen holder with the theme of the active skin, so the screen under
## test looks exactly as it does in the game.
func _holder(skin_id: String) -> Control:
	Ui.use_skin(skin_id)
	var holder := Control.new()
	holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	holder.theme = Ui.build_theme()
	root.add_child(holder)
	return holder


func _save(holder: Control, file_name: String, wait: float) -> void:
	await create_timer(wait).timeout
	var image := root.get_texture().get_image()
	var path := "%s/%s.png" % [_out, file_name]
	image.save_png(path)
	print("SHOTS %s %dx%d" % [file_name, image.get_width(), image.get_height()])
	holder.queue_free()
	await process_frame


func _illustration(scenario_id: String) -> Texture2D:
	var errors: Array[String] = []
	var scenario: Scenario = ScenarioLoader.load_file(ScenarioLoader.path_for(scenario_id), errors)
	return null if scenario == null else ScenarioLoader.illustration(scenario)


func _home(skin_id: String, file_name: String) -> void:
	var holder := _holder(skin_id)
	var home := HomeScreen.new()
	home.hero_texture = _illustration("beach_1")
	holder.add_child(home)
	await _save(holder, file_name, 1.4)


func _select(skin_id: String, file_name: String) -> void:
	var holder := _holder(skin_id)
	var errors: Array[String] = []
	var select := SelectScreen.new()
	select.catalog = Storage.load_catalog(errors)
	var progress := Progress.new()
	progress.record("beach", 3, 47.0)
	progress.record("city", 2, 95.0)
	progress.record("farm", 1, 150.0)
	select.progress = progress
	holder.add_child(select)
	await _save(holder, file_name, 0.8)


func _round(skin_id: String, scenario_id: String, theme_id: String, targets: Array, found: Array,
		with_hint: bool, file_name: String) -> void:
	var holder := _holder(skin_id)
	var screen := FindScreen.new()
	screen.scenario_id = scenario_id
	screen.theme_id = theme_id
	var ids: Array[String] = []
	for target: String in targets:
		ids.append(target)
	screen.target_ids = ids
	screen.progress_path = "user://store_shots_progress.json"
	holder.add_child(screen)
	await process_frame
	await process_frame
	for object_id: String in found:
		var position: Vector2 = screen.scenario.find_object(object_id)["position"]
		screen._on_tapped(object_id, position)
	screen.game_round.tick(38.0)
	screen._update_clock()
	if with_hint:
		screen._on_hint_pressed()
	else:
		screen.scene_view.view.center_on(Vector2(512, 760))
		screen.scene_view._apply_view()
	await _save(holder, file_name, 0.6)


func _result(skin_id: String, file_name: String) -> void:
	var holder := _holder(skin_id)
	holder.add_child(Ui.background())
	var panel := ResultPanel.new()
	panel.stars = 3
	panel.seconds = 62.0
	panel.best_seconds = 62.0
	panel.new_best_time = true
	panel.wrong_taps = 1
	panel.hints_used = 0
	holder.add_child(panel)
	await _save(holder, file_name, 3.2)


## The menu where a player picks an animal and sees the rooms that showed up.
func _lan_menu(skin_id: String, file_name: String) -> void:
	var holder := _holder(skin_id)
	var menu := LanMenuScreen.new()
	menu.avatar = 3
	holder.add_child(menu)
	await process_frame
	menu.set_rooms([
		{"ip": "192.168.1.8", "port": 24842, "players": 3, "avatar": 0, "open": true},
		{"ip": "192.168.1.12", "port": 24842, "players": 2, "avatar": 5, "open": true},
	])
	await _save(holder, file_name, 0.8)


## Stands in for the network node: the round screen only needs its signals and tap().
func _fake_net() -> Node:
	var script := GDScript.new()
	script.source_code = """extends Node
signal object_found(object_id, player_id, players)
signal time_changed(left)
signal round_ended(reason, players)
signal lobby_changed(players)
signal missed
func tap(_object_id: String) -> void:
	pass
"""
	script.reload()
	var node := Node.new()
	node.set_script(script)
	return node


func _lan_round(skin_id: String, file_name: String) -> void:
	var holder := _holder(skin_id)
	var net := _fake_net()
	holder.add_child(net)
	var players: Array = [
		{"id": 1, "avatar": 0, "score": 0, "rank": 0},
		{"id": 2, "avatar": 1, "score": 0, "rank": 0},
		{"id": 3, "avatar": 2, "score": 0, "rank": 0},
	]
	var screen := LanRoundScreen.new()
	screen.net = net
	screen.my_id = 1
	screen.scenario_id = "park_1"
	var ids: Array[String] = []
	for target: String in ["carousel", "popcorn", "balloons", "fountain", "train", "bench", "drum", "swan"]:
		ids.append(target)
	screen.target_ids = ids
	screen.players = players
	holder.add_child(screen)
	await process_frame
	await process_frame
	var finds := [["carousel", 1], ["popcorn", 2], ["balloons", 1], ["train", 3], ["swan", 2]]
	for find: Array in finds:
		var scores := {1: 0, 2: 0, 3: 0}
		for earlier: Array in finds.slice(0, finds.find(find) + 1):
			scores[earlier[1]] += 1
		var now: Array = []
		for player: Dictionary in players:
			var copy := player.duplicate()
			copy["score"] = scores[player["id"]]
			now.append(copy)
		screen._on_object_found(find[0], find[1], now)
	screen._left = 98.0
	screen.scene_view.view.center_on(Vector2(512, 700))
	screen.scene_view._apply_view()
	await _save(holder, file_name, 0.6)
