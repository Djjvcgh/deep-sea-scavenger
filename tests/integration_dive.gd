extends SceneTree
## 端到端集成测试：真实加载海底场景，用 Input 模拟玩家操作。
## godot --headless -s res://tests/integration_dive.gd
## 覆盖：搜宝 → 背包满拒绝拾取 → 鲨鱼伤害与无敌帧 → 撤离成功（宝物入库存）
## → 再次下潜 → 体力耗尽失败（丢失临时宝物）。

var failures := 0


func _initialize() -> void:
	_run()


func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  [通过] " + msg)
	else:
		failures += 1
		print("  [失败] " + msg)


func _run() -> void:
	await process_frame
	var gs = root.get_node("GameState")
	gs.reset_defaults()
	var save_path := "user://deepsea_scavenger_save.json"

	# ---------- 第一次下潜：搜宝 + 成功撤离 ----------
	print("[下潜一：搜宝与撤离]")
	change_scene_to_file("res://scenes/underwater.tscn")
	await process_frame
	await process_frame
	var uw = current_scene
	_check(uw != null and uw.name == "Underwater", "海底场景加载")
	var player = uw.get_node("Player")
	_check(player.stamina > 99.5, "下潜开始体力满 100")

	# 选 A 区宝箱（远离鲨鱼巡逻区，避免搜索被反复打断——打断机制本身由鲨鱼测试覆盖）
	var chest = null
	for n in get_nodes_in_group("interactables"):
		if "treasure_id" in n and n.global_position.x < 1500.0:
			chest = n
			break
	_check(chest != null, "场景中存在宝箱")

	# 传送到宝箱旁并长按 E 搜索
	player.global_position = chest.global_position + Vector2(0, -40)
	await create_timer(0.3).timeout
	var search_time: float = ItemDB.TREASURES[chest.treasure_id]["search_time"]
	Input.action_press("interact")
	await create_timer(search_time + 0.5).timeout
	Input.action_release("interact")
	await process_frame
	_check(gs.dive_bag.size() == 1, "搜索完成，宝物进入临时背包")
	_check(chest.looted, "宝箱标记为已搜取")
	_check(player.stamina < 100.0, "搜索期间体力被消耗")

	# 传送到鲨鱼身上，验证受伤与无敌帧
	var shark = get_nodes_in_group("sharks")[0]
	var hp_before: int = player.hp
	player.global_position = shark.global_position
	await create_timer(0.4).timeout
	_check(player.hp == hp_before - 1, "鲨鱼接触造成 1 点伤害")
	await create_timer(0.2).timeout
	_check(player.hp == hp_before - 1, "无敌时间内不会重复受伤")
	player.global_position = Vector2(200, 480)
	await create_timer(Balance.INVINCIBLE_TIME).timeout

	# 背包满时拒绝拾取
	var slots_to_fill: int = gs.bag_capacity() - gs.bag_used_slots()
	for i in slots_to_fill:
		gs.add_dive_item("bronze_coins")
	player.global_position = chest.global_position + Vector2(0, -40)
	await create_timer(0.2).timeout
	var bag_size: int = gs.dive_bag.size()
	Input.action_press("interact")
	await create_timer(0.6).timeout
	Input.action_release("interact")
	await process_frame
	_check(gs.dive_bag.size() == bag_size, "背包空间不足时禁止拾取")
	await create_timer(1.0).timeout

	# 撤离
	player.global_position = MapData.EXTRACT_RECT.get_center()
	await create_timer(0.3).timeout
	Input.action_press("interact")
	await create_timer(0.25).timeout
	Input.action_release("interact")
	await create_timer(0.3).timeout
	_check(uw.ended, "撤离触发结算")
	_check(paused, "结算时场景暂停")
	_check(not gs.dive_bag.is_empty() or not gs.island_stock.is_empty(), "结算数据存在")
	_check(gs.island_stock.size() >= 1, "宝物转入岛上库存")
	_check(FileAccess.file_exists(save_path), "存档已写入")

	# 返回荒岛
	uw.results_panel._go_island()
	await process_frame
	await process_frame
	_check(current_scene.name == "Island", "结算后返回荒岛场景")
	_check(not paused, "返回荒岛后解除暂停")

	# ---------- 第二次下潜：体力耗尽失败 ----------
	print("[下潜二：失败与丢失]")
	var stock_before: int = gs.island_stock.size()
	change_scene_to_file("res://scenes/underwater.tscn")
	await process_frame
	await process_frame
	var uw2 = current_scene
	var player2 = uw2.get_node("Player")
	_check(player2.stamina > player2.max_stamina - 1.0, "再次下潜体力重置")
	_check(gs.dive_bag.is_empty(), "临时背包已清空")

	# 搜索中断：松开 E 后进度清零
	var chest2 = null
	for n in get_nodes_in_group("interactables"):
		if "treasure_id" in n and n.global_position.x < 1500.0:
			chest2 = n
			break
	player2.global_position = chest2.global_position + Vector2(0, -40)
	await create_timer(0.3).timeout
	Input.action_press("interact")
	await create_timer(1.0).timeout
	Input.action_release("interact")
	await create_timer(0.2).timeout
	_check(not chest2.looted and chest2.search_progress <= 0.01, "松开 E 取消搜索且进度清零")
	await create_timer(Balance.INVINCIBLE_TIME).timeout
	gs.add_dive_item("gold_cup")
	player2.stamina = 0.05
	await create_timer(1.8).timeout
	_check(uw2.ended, "体力耗尽触发失败")
	_check(gs.dive_bag.is_empty(), "失败丢失临时宝物")
	_check(gs.island_stock.size() == stock_before, "已储存库存不受失败影响")

	# 清理测试污染
	paused = false
	gs.reset_defaults()
	if FileAccess.file_exists(save_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))

	if failures == 0:
		print("=== 集成测试全部通过 ===")
	else:
		print("=== 集成测试共 %d 项失败 ===" % failures)
	quit(1 if failures > 0 else 0)
