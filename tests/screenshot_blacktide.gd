extends SceneTree
## 黑潮号关卡截图工具（窗口模式运行，非 headless）：
##   Godot_console.exe -s res://tests/screenshot_blacktide.gd
## 在关键位置捕获画面到 tests/shots/，供灰盒布局目视检查。

const OUT_DIR := "res://tests/shots"
const SHOTS := [
	{"name": "01_extract", "pos": Vector2(420, 300), "zoom": 0.62},
	{"name": "02_deck", "pos": Vector2(1950, 420), "zoom": 0.62},
	{"name": "03_hold", "pos": Vector2(3120, 850), "zoom": 0.85},
	{"name": "04_crawl_secret", "pos": Vector2(2600, 950), "zoom": 0.55},
]


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	change_scene_to_file("res://scenes/level_blacktide.tscn")
	await process_frame
	await process_frame
	var uw = current_scene
	var player = uw.get_node("Player")
	var cam: Camera2D = player.get_node("Camera2D")
	cam.position_smoothing_enabled = false
	for shot in SHOTS:
		player.global_position = shot["pos"]
		cam.zoom = Vector2.ONE * float(shot["zoom"])
		cam.reset_smoothing()
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		var img := root.get_texture().get_image()
		img.save_png("%s/%s.png" % [OUT_DIR, shot["name"]])
		print("已截图：%s.png" % shot["name"])
	print("截图完成：%s" % OUT_DIR)
	quit(0)
