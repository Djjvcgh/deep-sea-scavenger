extends SceneTree
## 正式关卡截图工具（窗口模式）：
##   Godot_console.exe -s res://tests/screenshot_formal.gd
## 固定 DEEPSEA_SEED=1234 + 横列布局，保证前后对比同机位。
## 输出 tests/shots/formal_*.png。

const OUT_DIR := "res://tests/shots"
const ISLAND_SHOTS := [
	{"name": "f01_island_overview", "pos": Vector2(1300, 380), "zoom": 0.55},
	{"name": "f02_island_dive", "pos": Vector2(220, 420), "zoom": 0.9},
	{"name": "f03_island_merchant", "pos": Vector2(980, 440), "zoom": 0.9},
	{"name": "f04_island_workshop", "pos": Vector2(1630, 440), "zoom": 0.9},
	{"name": "f05_island_dock", "pos": Vector2(2300, 440), "zoom": 0.9},
]
const UW_SHOTS := [
	{"name": "f06_uw_shallow", "pos": Vector2(620, 760), "zoom": 0.62},
	{"name": "f07_uw_wreck", "pos": Vector2(2450, 760), "zoom": 0.62},
	{"name": "f08_uw_deep", "pos": Vector2(4300, 760), "zoom": 0.62},
	{"name": "f09_uw_extract", "pos": Vector2(330, 300), "zoom": 0.75},
	{"name": "f10_uw_explore", "pos": Vector2(1500, 700), "zoom": 0.0},
]


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	OS.set_environment("DEEPSEA_SEED", "1234")
	OS.set_environment("DEEPSEA_LAYOUT", "horizontal")

	# ---- 岛上基地 ----
	change_scene_to_file("res://scenes/island.tscn")
	await process_frame
	await process_frame
	var island = current_scene
	var p1 = island.get_node("Player")
	var cam1: Camera2D = p1.get_node("Camera2D")
	cam1.position_smoothing_enabled = false
	for shot in ISLAND_SHOTS:
		p1.global_position = shot["pos"]
		cam1.zoom = Vector2.ONE * float(shot["zoom"])
		cam1.reset_smoothing()
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		_shot(shot["name"])

	# ---- 正式潜水地图 ----
	change_scene_to_file("res://scenes/underwater.tscn")
	await process_frame
	await process_frame
	var uw = current_scene
	var p2 = uw.get_node("Player")
	var cam2: Camera2D = p2.get_node("Camera2D")
	cam2.position_smoothing_enabled = false
	for shot in UW_SHOTS:
		p2.global_position = shot["pos"]
		if float(shot["zoom"]) > 0.0:
			cam2.zoom = Vector2.ONE * float(shot["zoom"])
		cam2.reset_smoothing()
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		_shot(shot["name"])

	print("正式关卡截图完成：%s" % OUT_DIR)
	quit(0)


func _shot(name: String) -> void:
	var img := root.get_texture().get_image()
	img.save_png("%s/%s.png" % [OUT_DIR, name])
	print("已截图：%s.png" % name)
