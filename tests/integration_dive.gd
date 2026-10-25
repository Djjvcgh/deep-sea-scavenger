extends SceneTree
## 端到端集成测试：真实加载海底场景，用 Input 模拟玩家操作。
## godot --headless -s res://tests/integration_dive.gd
## 覆盖：搜宝开箱（拾取面板）→ 背包满拒绝拾取 → 鲨鱼伤害与无敌帧 → 撤离成功
## → 体力耗尽失败（战利品掉落缓存）→ 遗落物找回 → 15分钟限时失败。

var failures := 0


func _initialize() -> void:
	_run()


func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  [通过] " + msg)
	else:
		failures += 1
		print("  [失败] " + msg)


func _load_underwater() -> void:
	change_scene_to_file("res://scenes/underwater.tscn")
	await process_frame
	await process_frame


func _find_container(filter_kind := "chest", max_x := 1500.0) -> Node:
	for n in get_nodes_in_group("interactables"):
		if "collect_loot" in n and n.container_kind == filter_kind and n.global_position.x < max_x:
			return n
	return null


func _run() -> void:
	await process_frame
	var gs = root.get_node("GameState")
	gs.reset_defaults()
	var save_path: String = root.get_node("SaveManager").save_path
	if FileAccess.file_exists(save_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))

	# ---------- 第一次下潜：搜宝开箱 + 成功撤离 ----------
	print("[下潜一：开箱与撤离]")
	await _load_underwater()
	var uw = current_scene
	_check(uw.name == "Underwater", "海底场景加载")
	var player = uw.get_node("Player")
	_check(player.stamina > 99.5, "下潜开始体力满 100")
	_check(uw.time_left > Balance.DIVE_TIME_LIMIT - 2.0, "下潜时限 15 分钟")

	var chest = _find_container()
	_check(chest != null, "场景中存在宝箱")

	player.global_position = chest.global_position + Vector2(0, -40)
	await create_timer(0.3).timeout
	Input.action_press("interact")
	await create_timer(4.0).timeout
	Input.action_release("interact")
	await create_timer(0.3).timeout
	_check(chest.looted, "宝箱标记为已搜取")
	_check(uw.loot_panel.visible, "搜索完成后弹出开箱界面")
	_check(player.control_locked, "开箱界面期间锁定移动")
	uw.loot_panel.take_all_and_close()
	await process_frame
	_check(not uw.loot_panel.visible and not player.control_locked, "拾取后关闭并解锁移动")
	_check(gs.dive_bag.size() >= 1, "宝物进入临时背包（%d 件）" % gs.dive_bag.size())
	_check(player.stamina < 100.0, "搜索期间体力被消耗")

	# 鲨鱼伤害与无敌帧
	var shark = get_nodes_in_group("sharks")[0]
	var hp_before: int = player.hp
	player.global_position = shark.global_position
	await create_timer(0.4).timeout
	_check(player.hp == hp_before - 1, "鲨鱼接触造成 1 点伤害")
	await create_timer(0.2).timeout
	_check(player.hp == hp_before - 1, "无敌时间内不会重复受伤")
	await create_timer(Balance.INVINCIBLE_TIME).timeout

	# 背包满时开箱：物品拿不走
	var fill: int = gs.bag_capacity() - gs.bag_used_slots()
	while fill >= 1:
		gs.add_dive_item("old_coin")
		fill -= 1
	player.global_position = chest.global_position + Vector2(0, -40)
	await create_timer(0.3).timeout
	var chest2 = _find_container()
	if chest2 != null:
		Input.action_press("interact")
		await create_timer(4.0).timeout
		Input.action_release("interact")
		await create_timer(0.3).timeout
		var bag_size: int = gs.dive_bag.size()
		uw.loot_panel.take_all_and_close()
		await process_frame
		_check(gs.dive_bag.size() == bag_size, "背包满时无法拾取更多")
	else:
		print("  [跳过] 未找到第二个宝箱")
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
	_check(gs.island_stock.size() >= 1, "宝物转入岛上库存")
	_check(FileAccess.file_exists(save_path), "存档已写入")

	uw.results_panel._go_island()
	await process_frame
	await process_frame
	_check(current_scene.name == "Island", "结算后返回荒岛场景")
	_check(not paused, "返回荒岛后解除暂停")

	# ---------- 第二次下潜：体力耗尽失败，掉落可找回 ----------
	print("[下潜二：失败掉落]")
	var stock_before: int = gs.island_stock.size()
	paused = false
	await _load_underwater()
	var uw2 = current_scene
	var player2 = uw2.get_node("Player")
	_check(player2.stamina > player2.max_stamina - 1.0, "再次下潜体力重置")
	_check(gs.dive_bag.is_empty(), "临时背包已清空")

	# 搜索中断：松开 E 后进度清零
	var chest3 = _find_container()
	player2.global_position = chest3.global_position + Vector2(0, -40)
	await create_timer(0.3).timeout
	Input.action_press("interact")
	await create_timer(1.0).timeout
	Input.action_release("interact")
	await create_timer(0.2).timeout
	_check(not chest3.looted and chest3.search_progress <= 0.01, "松开 E 取消搜索且进度清零")
	await create_timer(Balance.INVINCIBLE_TIME).timeout

	gs.add_dive_item("gold_cup", "fine")
	player2.stamina = 0.05
	await create_timer(1.8).timeout
	_check(uw2.ended, "体力耗尽触发失败")
	_check(gs.dive_bag.is_empty(), "失败后临时背包清空")
	_check(gs.lost_cache["items"].size() == 1, "战利品进入遗落物缓存（可找回）")
	_check(gs.island_stock.size() == stock_before, "已储存库存不受失败影响")
	_check(uw2.results_panel._subtitle.text.contains("体力耗尽"), "结算显示失败原因")

	# ---------- 第三次下潜：找回遗落物 + 限时失败 ----------
	print("[下潜三：找回与限时]")
	paused = false
	await _load_underwater()
	var uw3 = current_scene
	var player3 = uw3.get_node("Player")
	var cache = _find_container("cache", 10000.0)
	_check(cache != null, "场景中生成遗落物袋")
	player3.global_position = cache.global_position + Vector2(0, -40)
	await create_timer(0.3).timeout
	Input.action_press("interact")
	await create_timer(3.0).timeout
	Input.action_release("interact")
	await create_timer(0.3).timeout
	_check(uw3.loot_panel.visible, "遗落物袋搜索完成弹出界面")
	uw3.loot_panel.take_all_and_close()
	await process_frame
	_check(gs.dive_bag.size() == 1 and gs.dive_bag[0]["id"] == "gold_cup", "找回完好金杯")
	_check(gs.lost_cache.is_empty(), "全部找回后缓存清空")

	uw3.time_left = 0.3
	await create_timer(1.2).timeout
	_check(uw3.ended, "15分钟时限归零触发失败")
	_check(uw3.results_panel._subtitle.text.contains("撤离窗口"), "结算显示超时原因")
	_check(gs.lost_cache["items"].size() == 1, "找回的宝物随超时再次掉落")

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
