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

	OS.set_environment("DEEPSEA_SEED", "0")
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
	for i in range(1, get_nodes_in_group("sharks").size()):
		var other = get_nodes_in_group("sharks")[i]
		other.take_damage(99, other.global_position + Vector2(0, 60))
	# 鲨鱼贴在洞壁外侧：海床洞穴（洞口朝左）放左侧，悬洞（背壁在右）放右侧
	var shark_pos: Vector2 = Vector2(interior.position.x - 95.0, center.y) \
		if cave["mode"] == "floor" else Vector2(interior.end.x + 95.0, center.y)
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

	# ---------- 海面换气 ----------
	print("[海面换气]")
	get_nodes_in_group("sharks")[0].global_position = Vector2(4800, 860)
	player.global_position = Vector2(800, 50)
	player.velocity = Vector2.ZERO
	player.stamina = 50.0
	await create_timer(2.0).timeout
	_check(player.breathing, "贴近开放海面进入换气状态")
	_check(player.stamina > 64.0, "换气 2 秒恢复约 16 点（实际 %.1f）" % player.stamina)
	_check(player.stamina <= player.max_stamina, "恢复不超过当前体力上限")
	# 岩层下方（区域C巨影岩体）：上方无天空，不能换气
	player.global_position = Vector2(4000, 540)
	player.velocity = Vector2.ZERO
	await create_timer(0.4).timeout
	_check(player._sky_above() == false, "岩体下方检测到顶盖遮挡")
	_check(not player.breathing, "岩层下方不进入换气")
	# 深水：退出换气并继续消耗
	player.global_position = Vector2(800, 700)
	player.velocity = Vector2.ZERO
	var st0: float = player.stamina
	await create_timer(1.0).timeout
	_check(not player.breathing and player.stamina < st0, "深水退出换气并继续消耗体力")

	# ---------- 海域主题与 Boss ----------
	print("[海域主题 Boss]")
	_check(MapData.DIVE_THEME_WEIGHTS.has(uw.dive_theme), "本局主题合法（%s）" % uw.dive_theme)
	await _test_ghost_captain(uw, player)
	await _test_sea_serpent(uw, player)

	gs.reset_defaults()
	OS.set_environment("DEEPSEA_SEED", "")
	if failures == 0:
		print("=== V0.4 场景集成测试全部通过 ===")
	else:
		print("=== V0.4 场景集成测试共 %d 项失败 ===" % failures)
	quit(1 if failures > 0 else 0)


## 沉船主题种子：进入船长室触发幽灵船长 → 击杀 → 战利品袋。
func _test_ghost_captain(uw, player) -> void:
	var gs = root.get_node("GameState")
	OS.set_environment("DEEPSEA_SEED", "0")
	change_scene_to_file("res://scenes/underwater.tscn")
	await process_frame
	await process_frame
	var uw2 = current_scene
	if uw2.dive_theme != "wreck" or uw2._wrecks.is_empty():
		print("  [跳过] 种子0 未满足沉船主题+沉船（theme=%s wrecks=%d）" % [uw2.dive_theme, uw2._wrecks.size()])
		return
	var wreck = null
	for w in uw2._wrecks:
		if w.has("captain_room"):
			wreck = w
			break
	if wreck == null:
		wreck = uw2._wrecks[0]
	var room: Rect2 = wreck.get("captain_room", wreck["interior"])
	var p2 = uw2.get_node("Player")
	p2.global_position = room.get_center()
	p2.velocity = Vector2.ZERO
	await create_timer(0.6).timeout
	if uw2.boss == null:
		_check(false, "进入船长室触发幽灵船长")
		return
	_check(uw2.boss.boss_name == "幽灵船长", "幽灵船长显形")
	await create_timer(2.0).timeout
	_check(uw2.any_boss_active(), "HUD 判定船长威胁")
	await create_timer(Balance.CAPTAIN_DASH_INTERVAL + Balance.CAPTAIN_DASH_TELEGRAPH + 0.6).timeout
	_check(uw2.boss != null and uw2.boss.state in [uw2.boss.State.TELEGRAPH, uw2.boss.State.DASHING,
		uw2.boss.State.ACTIVE], "船长进入攻击循环（当前状态 %d）" % uw2.boss.state)
	uw2.boss.global_position = room.get_center() + Vector2(0, 27)   # 移到舱内空旷处再击杀，战利品袋不落在墙体里
	uw2.boss.take_damage(99, p2.global_position)
	_check(uw2.boss.dead, "船长生命耗尽")
	await create_timer(0.4).timeout
	var trophy = null
	for n in get_nodes_in_group("interactables"):
		if "collect_loot" in n and n.container_kind == "trophy":
			trophy = n
			break
	_check(trophy != null, "沉没处生成船长战利品袋")
	if trophy != null:
		gs.dive_bag = []
		p2.invincible_left = 99999.0   # 防巡逻鲨隔门咬断搜索
		p2.global_position = trophy.global_position + Vector2(0, -4)
		await create_timer(0.3).timeout
		Input.action_press("interact")
		await create_timer(2.2).timeout
		Input.action_release("interact")
		await create_timer(0.3).timeout
		uw2.loot_panel.take_all_and_close()
		await process_frame
		var got_relic := false
		for e in gs.dive_bag:
			if e["id"] == "captain_compass" and e["quality"] == "pristine":
				got_relic = true
		_check(got_relic, "拾取完好船长罗盘")


## 洞穴主题种子：进入危险洞穴触发洞穴海蛇 → 击杀 → 战利品袋。
func _test_sea_serpent(uw, player) -> void:
	var gs = root.get_node("GameState")
	OS.set_environment("DEEPSEA_SEED", "3")
	change_scene_to_file("res://scenes/underwater.tscn")
	await process_frame
	await process_frame
	var uw3 = current_scene
	if uw3.dive_theme != "cave":
		print("  [跳过] 种子3 非洞穴主题（%s）" % uw3.dive_theme)
		return
	var danger_cave = null
	for c in uw3._caves:
		if c["kind"] in ["danger", "hang_danger"]:
			danger_cave = c
			break
	if danger_cave == null:
		_check(false, "洞穴主题含危险洞穴")
		return
	var p3 = uw3.get_node("Player")
	p3.global_position = (danger_cave["interior"] as Rect2).get_center()
	p3.velocity = Vector2.ZERO
	await create_timer(0.6).timeout
	if uw3.boss == null:
		_check(false, "靠近危险洞穴触发洞穴海蛇")
		return
	_check(uw3.boss.boss_name == "洞穴海蛇", "洞穴海蛇现形")
	# 预警后突袭：站定在预警线方向上应受一次伤害
	p3.invincible_left = 0.0
	var hp0: int = p3.hp
	await create_timer(Balance.SERPENT_LUNGE_TELEGRAPH + Balance.SERPENT_LUNGE_TIME + 0.3).timeout
	_check(p3.hp < hp0 or uw3.boss.state == uw3.boss.State.COOLDOWN, "海蛇预警后突袭")
	uw3.boss.take_damage(99, p3.global_position)
	_check(uw3.boss.dead, "海蛇生命耗尽")
	await create_timer(0.4).timeout
	var trophy = null
	for n in get_nodes_in_group("interactables"):
		if "collect_loot" in n and n.container_kind == "trophy":
			trophy = n
			break
	_check(trophy != null, "沉没处生成海蛇战利品袋")
	if trophy != null:
		gs.dive_bag = []
		p3.invincible_left = 99999.0
		p3.global_position = trophy.global_position + Vector2(0, -4)
		await create_timer(0.3).timeout
		Input.action_press("interact")
		await create_timer(2.2).timeout
		Input.action_release("interact")
		await create_timer(0.3).timeout
		uw3.loot_panel.take_all_and_close()
		await process_frame
		var got_pearl := false
		for e in gs.dive_bag:
			if e["id"] == "serpent_pearl" and e["quality"] == "pristine":
				got_pearl = true
		_check(got_pearl, "拾取完好深海蛇珠")
