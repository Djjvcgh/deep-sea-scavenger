extends SceneTree
## V0.4 场景级集成测试：随机沉船 / 随机洞穴 / 鲨鱼视线遮挡。
## godot --headless -s res://tests/integration_v04.gd
## 用 DEEPSEA_SEED 固定海况种子，逐段校验沉船容器可搜、洞穴可进出、
## 岩壁遮挡鲨鱼视线（不追逐不咬人）、离开遮挡后恢复发现。

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
	var save_path: String = root.get_node("SaveManager").save_path
	if FileAccess.file_exists(save_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))

	OS.set_environment("DEEPSEA_SEED", "1")
	change_scene_to_file("res://scenes/underwater.tscn")
	await process_frame
	await process_frame
	var uw = current_scene
	var player = uw.get_node("Player")

	# ---------- 沉船遗址 ----------
	print("[随机沉船：场景交互]")
	_check(uw._caves.size() >= 2, "本局生成 %d 处洞穴（≥2）" % uw._caves.size())
	var wreck_container = null
	for n in get_nodes_in_group("interactables"):
		if "collect_loot" in n and n.container_name in ["货舱宝箱", "海盗货舱宝箱", "船长室宝箱", "祭祀宝箱"]:
			wreck_container = n
			break
	if wreck_container != null:
		player.global_position = wreck_container.global_position + Vector2(0, -4)
		await create_timer(0.4).timeout
		var hp0: int = player.hp
		Input.action_press("interact")
		await create_timer(4.2).timeout
		Input.action_release("interact")
		await create_timer(0.3).timeout
		_check(wreck_container.looted, "沉船容器可搜索（%s）" % wreck_container.container_name)
		_check(uw.loot_panel.visible, "搜索沉船容器弹出拾取界面")
		uw.loot_panel.take_all_and_close()
		await process_frame
		_check(gs.dive_bag.size() >= 1, "沉船战利品进入背包（%d 件）" % gs.dive_bag.size())
		var id_ok := true
		for entry in gs.dive_bag:
			id_ok = id_ok and ItemDB.TREASURES.has(entry["id"])
		_check(id_ok, "战利品 id 全部合法")
		_check(player.hp == hp0, "搜索过程未受伤")
	else:
		print("  [跳过] 本局种子未生成沉船，仅校验数量")
	_check(uw._wrecks.size() <= 2, "沉船数量 ≤2（实际 %d）" % uw._wrecks.size())

	# ---------- 洞穴：进入、发现、遮挡、离开 ----------
	print("[随机洞穴：进出与遮挡]")
	var cave: Dictionary = uw._caves[0]
	var interior: Rect2 = cave["interior"]
	var center: Vector2 = interior.get_center()
	player.global_position = center
	player.velocity = Vector2.ZERO
	await create_timer(0.5).timeout
	_check(uw._cave_seen.size() >= 1, "进入洞穴触发发现提示")
	var shark = get_nodes_in_group("sharks")[0]
	# 鲨鱼贴在洞壁外侧：海床洞穴（洞口朝左）放左侧，悬洞（背壁在右）放右侧
	var shark_pos: Vector2 = Vector2(interior.position.x - 60.0, center.y) \
		if cave["mode"] == "floor" else Vector2(interior.end.x + 60.0, center.y)
	shark.setup(shark_pos.x - 30.0, shark_pos.x + 30.0, shark_pos.y, player)
	shark.global_position = shark_pos
	shark.velocity = Vector2.ZERO
	await create_timer(0.4).timeout
	_check(shark._see_player() == false, "岩壁遮挡：洞内玩家不被鲨鱼视线锁定")
	var hp_before: int = player.hp
	await create_timer(2.0).timeout
	_check(player.hp == hp_before, "洞内逗留 2 秒未被咬")
	_check(not shark.is_threatening(), "遮挡期间鲨鱼未进入警戒/追逐")
	# 离开洞穴到洞外开阔水：采样找一个与鲨鱼互相通视的位置
	var solids: Array = uw._all_solids()
	var found := false
	for ang in 12:
		var dir := Vector2.RIGHT.rotated(TAU * float(ang) / 12.0)
		var cand: Vector2 = center + dir * 260.0
		var shark2: Vector2 = cand + dir * 120.0
		if not MapData.circle_clear(cand, 40.0, solids):
			continue
		if not MapData.circle_clear(shark2, 50.0, solids):
			continue
		var clear := true
		for t in 13:
			if not MapData.circle_clear(cand.lerp(shark2, t / 12.0), 26.0, solids):
				clear = false
				break
		if not clear:
			continue
		player.global_position = cand
		player.velocity = Vector2.ZERO
		shark.global_position = shark2
		shark.setup(shark2.x - 200.0, shark2.x + 200.0, shark2.y, player)
		found = true
		break
	_check(found, "洞外找到开阔互视位置")
	if found:
		await create_timer(1.2).timeout
		_check(shark._see_player(), "离开遮挡后鲨鱼视线恢复")
		await create_timer(1.5).timeout
		_check(shark.is_threatening(), "开阔水域鲨鱼发现玩家进入警戒/追逐")

	gs.reset_defaults()
	OS.set_environment("DEEPSEA_SEED", "")
	if failures == 0:
		print("=== V0.4 场景集成测试全部通过 ===")
	else:
		print("=== V0.4 场景集成测试共 %d 项失败 ===" % failures)
	quit(1 if failures > 0 else 0)
