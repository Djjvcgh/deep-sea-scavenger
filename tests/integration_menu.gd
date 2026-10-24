extends SceneTree
## 主菜单流程集成测试：新游戏建立初始存档、继续游戏恢复进度。
## godot --headless -s res://tests/integration_menu.gd
## 输出走 stderr（printerr）避免管道缓冲掩盖卡点。

var failures := 0


func _initialize() -> void:
	var watchdog := create_timer(40.0)
	watchdog.timeout.connect(func() -> void:
		printerr("[看门狗] 测试超时，强制退出")
		quit(3))
	_run()


func _check(cond: bool, msg: String) -> void:
	if cond:
		printerr("  [通过] " + msg)
	else:
		failures += 1
		printerr("  [失败] " + msg)


func _run() -> void:
	await process_frame
	printerr("[步骤] 初始状态")
	var gs = root.get_node("GameState")
	var sm = root.get_node("SaveManager")
	gs.reset_defaults()
	if FileAccess.file_exists(sm.save_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(sm.save_path))

	printerr("[步骤] 加载主菜单")
	change_scene_to_file("res://scenes/main_menu.tscn")
	await process_frame
	await process_frame
	var menu = current_scene
	printerr("[步骤] 主菜单已加载: ", menu)
	_check(menu.name == "MainMenu", "主菜单加载")
	_check(not sm.has_save(), "无存档")

	printerr("[步骤] 开始新游戏")
	menu._start_new()
	await process_frame
	await process_frame
	printerr("[步骤] 新游戏场景: ", current_scene)
	_check(current_scene.name == "Island", "开始新游戏进入荒岛")
	_check(sm.has_save(), "新游戏写入初始存档")
	_check(gs.credits == 0 and gs.island_stock.is_empty(), "新游戏数据为初始值")

	printerr("[步骤] 模拟进度并重新继续")
	gs.credits = 123
	gs.materials["wood"] = 1
	sm.save_game(gs.serialize())
	change_scene_to_file("res://scenes/main_menu.tscn")
	await process_frame
	await process_frame
	menu = current_scene
	_check(menu.name == "MainMenu", "返回主菜单")
	menu._on_continue()
	await process_frame
	await process_frame
	_check(current_scene.name == "Island", "继续游戏进入荒岛")
	_check(gs.credits == 123 and gs.materials["wood"] == 1, "继续游戏正确恢复进度")

	printerr("[步骤] 清理")
	gs.reset_defaults()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(sm.save_path))

	if failures == 0:
		printerr("=== 主菜单集成测试全部通过 ===")
	else:
		printerr("=== 主菜单集成测试共 %d 项失败 ===" % failures)
	quit(1 if failures > 0 else 0)
