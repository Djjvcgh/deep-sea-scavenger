extends SceneTree
## 黑潮号关卡截图工具（窗口模式运行，非 headless）：
##   Godot_console.exe -s res://tests/screenshot_blacktide.gd
## V0.5 纠偏阶段输出：
##   tests/shots/01-09 常规视角（zoom 为 0 表示用玩家默认相机 1.5）
##   tests/shots/zoom_1.3/1.5/1.7 相机缩放对比 → docs/art_direction/screens/zoom/
##   10_ship_full 完整船体 / 11_explore 水下探索 / 12_loot_normal 普通搜刮 /
##   13_loot_rare 传说演出（含大图展示卡）

const OUT_DIR := "res://tests/shots"
const SHOTS := [
	{"name": "01_extract", "pos": Vector2(420, 300), "zoom": 0.62},
	{"name": "02_deck", "pos": Vector2(1950, 420), "zoom": 0.62},
	{"name": "03_hold", "pos": Vector2(3120, 850), "zoom": 0.85},
	{"name": "04_crawl_secret", "pos": Vector2(2600, 950), "zoom": 0.55},
	{"name": "05_hold_close", "pos": Vector2(3080, 950), "zoom": 1.15},
	{"name": "06_hold_secret", "pos": Vector2(3210, 950), "zoom": 1.3},
	{"name": "07_hud", "pos": Vector2(3090, 955), "zoom": 0.0},
]
const ZOOM_SET := [1.3, 1.5, 1.7]
const DEMO_NORMAL := [
	{"id": "pearl", "quality": "worn"},
	{"id": "old_coin", "quality": "standard"},
	{"mat": "leather"},
]
const DEMO_RARE := [
	{"id": "gold_sextant", "quality": "pristine"},
	{"id": "gold_cup", "quality": "fine"},
]


func _initialize() -> void:
	_run()


func _move(player: Node2D, cam: Camera2D, pos: Vector2, zoom: float) -> void:
	player.global_position = pos
	if zoom > 0.0:
		cam.zoom = Vector2.ONE * zoom
	cam.reset_smoothing()


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
		_move(player, cam, shot["pos"], float(shot["zoom"]))
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		_shot(shot["name"])

	# ---- 相机缩放对比（船长货舱同一位置） ----
	for z in ZOOM_SET:
		_move(player, cam, Vector2(3080, 950), z)
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		_shot("zoom_%.1f" % z)

	# ---- 完整船体（超远视角） ----
	_move(player, cam, Vector2(2100, 700), 0.34)
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	_shot("10_ship_full")

	# ---- 正常水下探索（默认相机 1.5，玩家可见） ----
	_move(player, cam, Vector2(1500, 900), 0.0)
	await create_timer(0.4).timeout
	await RenderingServer.frame_post_draw
	_shot("11_explore")

	# ---- 普通宝物搜刮 ----
	var crate_chest = null
	for n in get_nodes_in_group("interactables"):
		if "container_kind" in n and n.container_name == "货舱木箱":
			crate_chest = n
			break
	uw.loot_panel.open(DEMO_NORMAL, crate_chest)
	await create_timer(0.4).timeout
	await RenderingServer.frame_post_draw
	_shot("12_loot_normal")
	uw.loot_panel.close()

	# ---- 稀有宝物搜刮（传说演出卡） ----
	var vault = null
	for n in get_nodes_in_group("interactables"):
		if "container_kind" in n and n.container_name == "船长金库":
			vault = n
			break
	uw.loot_panel.open(DEMO_RARE, vault)
	await create_timer(0.3).timeout
	uw.loot_panel._try_take(0)   # 拾取完美六分仪 → 触发传说演出
	await create_timer(0.35).timeout
	await RenderingServer.frame_post_draw
	_shot("13_loot_rare")
	uw.loot_panel.close()

	print("截图完成：%s" % OUT_DIR)
	quit(0)


func _shot(name: String) -> void:
	var img := root.get_texture().get_image()
	img.save_png("%s/%s.png" % [OUT_DIR, name])
	print("已截图：%s.png" % name)
