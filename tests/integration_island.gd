extends SceneTree
## 荒岛集成测试：商人界面开关、出售、下潜入口、造船完成流程。
## godot --headless -s res://tests/integration_island.gd

var failures := 0


func _initialize() -> void:
	_run()


func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  [通过] " + msg)
	else:
		failures += 1
		print("  [失败] " + msg)


func _tap(action: String) -> void:
	Input.action_press(action)
	await create_timer(0.1).timeout
	Input.action_release(action)


func _run() -> void:
	await process_frame
	var gs = root.get_node("GameState")
	gs.reset_defaults()
	gs.credits = 50
	gs.island_stock = [{"id": "gold_cup", "quality": "fine"}]

	print("[荒岛：交互与交易]")
	change_scene_to_file("res://scenes/island.tscn")
	await process_frame
	await process_frame
	var island = current_scene
	_check(island.name == "Island", "荒岛场景加载")
	var player = island.player

	# 商人面板
	player.global_position = Vector2(560, 500)
	await create_timer(0.3).timeout
	await _tap("interact")
	await create_timer(0.2).timeout
	_check(island.merchant_panel.visible, "按 E 打开商人界面")
	_check(not island.upgrades_panel.visible, "其他面板未打开")

	# Esc 关闭面板（事件驱动，用 parse_input_event）
	var ev := InputEventAction.new()
	ev.action = "pause"
	ev.pressed = true
	Input.parse_input_event(ev)
	await create_timer(0.3).timeout
	_check(not island.merchant_panel.visible, "Esc 关闭商人界面")
	_check(not paused, "关闭面板不暂停")

	# 按钮路径关闭（界面上的「离开」按钮走同一 close()）：必须解除移动锁定
	player.global_position = Vector2(560, 500)
	await create_timer(0.3).timeout
	await _tap("interact")
	await create_timer(0.2).timeout
	_check(player.control_locked, "面板打开时玩家锁定移动")
	island.merchant_panel.close()
	await create_timer(0.2).timeout
	_check(not player.control_locked, "按钮关闭面板后解除移动锁定")
	var x_before: float = player.global_position.x
	Input.action_press("move_right")
	await create_timer(0.4).timeout
	Input.action_release("move_right")
	_check(player.global_position.x > x_before + 10.0, "关闭面板后玩家可以移动")

	# 世界边界：贴着左右边缘走不会坠出屏幕
	player.global_position = Vector2(60, 500)
	await create_timer(0.3).timeout
	Input.action_press("move_left")
	await create_timer(2.0).timeout
	Input.action_release("move_left")
	_check(player.global_position.x >= 0.0 and player.global_position.y < 560.0,
		"左边界：玩家留在画面内不坠落（x=%.0f, y=%.0f）"
			% [player.global_position.x, player.global_position.y])
	player.global_position = Vector2(1220, 500)
	await create_timer(0.3).timeout
	Input.action_press("move_right")
	await create_timer(2.0).timeout
	Input.action_release("move_right")
	_check(player.global_position.x <= 1280.0 and player.global_position.y < 560.0,
		"右边界：玩家留在画面内不坠落（x=%.0f, y=%.0f）"
			% [player.global_position.x, player.global_position.y])

	# 出售与存档
	var credits_before: int = gs.credits
	gs.sell_one(0)
	_check(gs.credits == credits_before + 196, "出售精良金杯获得正确额度")
	await create_timer(0.2).timeout
	_check(FileAccess.file_exists("user://deepsea_scavenger_save.json"), "交易后自动存档")

	# 材料回售（物物交换）
	gs.materials["wood"] = 1
	var credits_before_mat: int = gs.credits
	island.merchant_panel._sell_mat("wood")
	_check(gs.credits == credits_before_mat + 80, "材料回售 8 折（木材 +80）")

	# 背包打造（工作台，材料来自海底）
	gs.materials["leather"] = 2
	_check(gs.craft_bag() and gs.bag_capacity() == 10, "工作台打造皮革背包（10格）")
	island.upgrades_panel.open()
	await create_timer(0.2).timeout
	island.upgrades_panel.close()

	# 下潜点进入海底
	player.global_position = Vector2(150, 500)
	await create_timer(0.3).timeout
	await _tap("interact")
	await create_timer(0.5).timeout
	_check(current_scene.name == "Underwater", "下潜点按 E 进入海底场景")

	# 造船完成流程
	gs.reset_defaults()
	change_scene_to_file("res://scenes/island.tscn")
	await process_frame
	await process_frame
	var island2 = current_scene
	gs.materials = {"wood": 2, "iron": 1, "canvas": 1}
	island2.boat_panel.open()
	gs.invest_material("wood", 2)
	gs.invest_material("iron", 1)
	gs.invest_material("canvas", 1)
	await create_timer(0.3).timeout
	_check(gs.boat_completed, "材料齐全后造船完成")
	_check(island2.boat_panel.visible, "造船完成弹出船坞界面")
	_check(island2._boat_visual.get_child_count() > 0, "船坞视觉随进度更新")
	var has_save2 := FileAccess.file_exists("user://deepsea_scavenger_save.json")
	_check(has_save2, "造船进度已存档")

	# 造船面板的按钮关闭路径同样要解锁
	island2.boat_panel.close()
	await create_timer(0.2).timeout
	_check(not island2.player.control_locked, "关闭造船面板后解除移动锁定")

	# 清理
	gs.reset_defaults()
	if FileAccess.file_exists("user://deepsea_scavenger_save.json"):
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://deepsea_scavenger_save.json"))

	if failures == 0:
		print("=== 荒岛集成测试全部通过 ===")
	else:
		print("=== 荒岛集成测试共 %d 项失败 ===" % failures)
	quit(1 if failures > 0 else 0)
