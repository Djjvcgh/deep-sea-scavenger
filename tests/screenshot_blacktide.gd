extends SceneTree
## 黑潮号关卡截图工具（窗口模式运行，非 headless）：
##   Godot_console.exe -s res://tests/screenshot_blacktide.gd
## 在关键位置捕获画面到 tests/shots/，供灰盒布局目视检查。
## V0.5：新增样板房特写、HUD 特写与搜刮界面前后对比（旧 UI 从 tests/ui_before/ 加载）。

const OUT_DIR := "res://tests/shots"
const SHOTS := [
	{"name": "01_extract", "pos": Vector2(420, 300), "zoom": 0.62},
	{"name": "02_deck", "pos": Vector2(1950, 420), "zoom": 0.62},
	{"name": "03_hold", "pos": Vector2(3120, 850), "zoom": 0.85},
	{"name": "04_crawl_secret", "pos": Vector2(2600, 950), "zoom": 0.55},
	{"name": "05_hold_close", "pos": Vector2(3080, 950), "zoom": 1.15},
	{"name": "06_hold_secret", "pos": Vector2(3210, 950), "zoom": 1.3},
]
const DEMO_LOOT := [
	{"id": "gold_sextant", "quality": "pristine"},
	{"id": "gold_cup", "quality": "fine"},
	{"id": "pearl", "quality": "worn"},
	{"mat": "leather"},
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

	# ---- HUD 特写：靠近船长金库，带上下文交互提示 ----
	player.global_position = Vector2(3090, 955)
	cam.zoom = Vector2.ONE
	cam.reset_smoothing()
	await create_timer(0.5).timeout
	await RenderingServer.frame_post_draw
	_shot("07_hud")

	# ---- 搜刮界面：旧版（改造前） ----
	var vault = null
	for n in get_nodes_in_group("interactables"):
		if "container_kind" in n and n.container_name == "船长金库":
			vault = n
			break
	uw.hud.visible = false
	var old_hud = load("res://tests/ui_before/hud_old.gd").new()
	uw.add_child(old_hud)
	old_hud.setup(player, uw)
	var old_panel = load("res://tests/ui_before/loot_panel_old.gd").new()
	uw.add_child(old_panel)
	old_panel.open(DEMO_LOOT, vault)
	await create_timer(0.3).timeout
	await RenderingServer.frame_post_draw
	_shot("08_ui_before")
	old_panel.queue_free()
	old_hud.queue_free()

	# ---- 搜刮界面：新版（改造后） ----
	uw.hud.visible = true
	uw.loot_panel.open(DEMO_LOOT, vault)
	await create_timer(0.3).timeout
	await RenderingServer.frame_post_draw
	_shot("09_ui_after")

	print("截图完成：%s" % OUT_DIR)
	quit(0)


func _shot(name: String) -> void:
	var img := root.get_texture().get_image()
	img.save_png("%s/%s.png" % [OUT_DIR, name])
	print("已截图：%s.png" % name)
